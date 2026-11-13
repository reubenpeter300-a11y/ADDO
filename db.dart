import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'addo_manager.db');
    _db = await openDatabase(path, version: 5, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) { await _createBusinessTables(db); }
      if (oldVersion < 3) {
        await _createAdvancedTables(db);
        await db.execute("ALTER TABLE sales ADD COLUMN customer_name TEXT");
      }
      if (oldVersion < 5) { await _upgradeV5(db); }
    }, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE medicines(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          generic_name TEXT,
          category TEXT,
          batch_no TEXT,
          expiry_date TEXT,
          cost_price REAL NOT NULL DEFAULT 0,
          selling_price REAL NOT NULL DEFAULT 0,
          quantity INTEGER NOT NULL DEFAULT 0,
          min_stock INTEGER NOT NULL DEFAULT 5,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicine_id INTEGER NOT NULL,
          medicine_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          unit_cost REAL NOT NULL,
          total REAL NOT NULL,
          profit REAL NOT NULL,
          payment_method TEXT NOT NULL,
          customer_name TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE expenses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE app_users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          pin_hash TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      final saltText = base64Encode(salt);
      final defaultHash = sha256.convert(utf8.encode('admin123:$saltText')).toString();
      final defaultPinHash = sha256.convert(utf8.encode('1234:$saltText')).toString();
      await db.insert('app_users', {
        'username': 'admin',
        'password_hash': '$saltText:$defaultHash',
        'pin_hash': '$saltText:$defaultPinHash',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.execute('''
        CREATE TABLE audit_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          details TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await _createBusinessTables(db);
      await _createAdvancedTables(db);
      await _upgradeV5(db);
    });
    return _db!;
  }

  Future<void> _upgradeV5(DatabaseExecutor db) async {
    Future<void> addColumn(String table, String column, String sql) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      if (!info.any((r) => r['name'] == column)) await db.execute(sql);
    }
    await addColumn('sales', 'receipt_id', 'ALTER TABLE sales ADD COLUMN receipt_id TEXT');
    await addColumn('sales', 'status', "ALTER TABLE sales ADD COLUMN status TEXT NOT NULL DEFAULT 'completed'");
    await addColumn('sales', 'returned_quantity', 'ALTER TABLE sales ADD COLUMN returned_quantity INTEGER NOT NULL DEFAULT 0');
    await db.execute('''CREATE TABLE IF NOT EXISTS stock_movements(
      id INTEGER PRIMARY KEY AUTOINCREMENT, medicine_id INTEGER NOT NULL,
      movement_type TEXT NOT NULL, quantity INTEGER NOT NULL, reason TEXT NOT NULL,
      reference TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sale_returns(
      id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL, refund_amount REAL NOT NULL,
      reason TEXT NOT NULL, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS auth_attempts(
      username TEXT PRIMARY KEY, failed_attempts INTEGER NOT NULL DEFAULT 0, locked_until TEXT)''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created ON sales(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batches_medicine_expiry ON medicine_batches(medicine_id, expiry_date)');
  }

  Future<void> _logStock(DatabaseExecutor txn, int medicineId, String type,
      int quantity, String reason, {String? reference}) async {
    await txn.insert('stock_movements', {
      'medicine_id': medicineId, 'movement_type': type, 'quantity': quantity,
      'reason': reason, 'reference': reference,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> adjustStock({required int medicineId, required int change,
      required String reason}) async {
    if (change == 0 || reason.trim().isEmpty) throw Exception('Weka idadi na sababu ya marekebisho');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('medicines', where: 'id=?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw Exception('Dawa haijapatikana');
      final current = rows.first['quantity'] as int;
      if (current + change < 0) throw Exception('Stock haiwezi kuwa chini ya sifuri');

      // Keep aggregate medicine quantity and batch quantities in sync.
      // Positive adjustments are recorded as legacy/unbatched stock. For a
      // write-off, remove unbatched stock first, then reduce batches in FEFO order.
      if (change < 0) {
        var toRemove = -change;
        final batches = await txn.query(
          'medicine_batches',
          where: 'medicine_id=? AND quantity>0',
          whereArgs: [medicineId],
          orderBy: "CASE WHEN expiry_date IS NULL OR expiry_date='' THEN 1 ELSE 0 END, expiry_date ASC, id ASC",
        );
        final batchTotal = batches.fold<int>(0, (sum, b) => sum + (b['quantity'] as int));
        final legacy = (current - batchTotal).clamp(0, current).toInt();
        final fromLegacy = legacy < toRemove ? legacy : toRemove;
        toRemove -= fromLegacy;
        for (final batch in batches) {
          if (toRemove == 0) break;
          final have = batch['quantity'] as int;
          final take = have < toRemove ? have : toRemove;
          await txn.update('medicine_batches', {'quantity': have - take},
              where: 'id=?', whereArgs: [batch['id']]);
          toRemove -= take;
        }
        if (toRemove > 0) throw Exception('Haiwezekani kupunguza stock: batch hazilingani na stock ya jumla');
      }
      await txn.update('medicines', {'quantity': current + change}, where: 'id=?', whereArgs: [medicineId]);
      await _logStock(txn, medicineId, change > 0 ? 'IN' : 'OUT', change.abs(), reason.trim());
      await txn.insert('audit_log', {'action':'STOCK_ADJUSTMENT','details':'Medicine $medicineId change $change: $reason','created_at':DateTime.now().toIso8601String()});
    });
  }

  Future<List<Map<String, Object?>>> stockMovements({int? medicineId}) async {
    final db = await database;
    if (medicineId == null) return db.rawQuery('''SELECT sm.*, m.name medicine_name FROM stock_movements sm JOIN medicines m ON m.id=sm.medicine_id ORDER BY sm.created_at DESC''');
    return db.rawQuery('''SELECT sm.*, m.name medicine_name FROM stock_movements sm JOIN medicines m ON m.id=sm.medicine_id WHERE sm.medicine_id=? ORDER BY sm.created_at DESC''',[medicineId]);
  }

  Future<List<Map<String, Object?>>> customerStatement(String customerName) async {
    final db = await database;
    return db.rawQuery('''SELECT d.id debt_id, d.sale_id, d.amount, d.paid, d.created_at,
      (d.amount-d.paid) balance, COALESCE(s.medicine_name,'') medicine_name
      FROM customer_debts d LEFT JOIN sales s ON s.id=d.sale_id
      WHERE lower(trim(d.customer_name))=lower(trim(?)) ORDER BY d.created_at''',[customerName]);
  }

  Future<Map<String, num>> reportTotals(DateTime from, DateTime to) async {
    final db = await database;
    final a = DateTime(from.year,from.month,from.day).toIso8601String();
    final b = DateTime(to.year,to.month,to.day,23,59,59,999).toIso8601String();
    final salesRows = await db.rawQuery("SELECT COALESCE(SUM(total - unit_price * returned_quantity),0) total, COALESCE(SUM(profit - (unit_price - unit_cost) * returned_quantity),0) profit FROM sales WHERE created_at BETWEEN ? AND ?",[a,b]);
    final expenseRows = await db.rawQuery('SELECT COALESCE(SUM(amount),0) amount FROM expenses WHERE created_at BETWEEN ? AND ?',[a,b]);
    final gross = (salesRows.first['profit'] as num);
    final expenses = (expenseRows.first['amount'] as num);
    return {'sales':salesRows.first['total'] as num,'grossProfit':gross,'expenses':expenses,'netProfit':gross-expenses};
  }

  Future<void> returnSale({required int saleId, required int quantity,
      required String reason}) async {
    if (quantity <= 0 || reason.trim().isEmpty) throw Exception('Taarifa za marejesho si sahihi');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('sales', where:'id=?', whereArgs:[saleId]);
      if (rows.isEmpty) throw Exception('Muamala haujapatikana');
      final sale = rows.first;
      final sold = sale['quantity'] as int;
      final returned = sale['returned_quantity'] as int? ?? 0;
      if (quantity > sold-returned) throw Exception('Idadi ya kurejesha inazidi iliyobaki');
      final unitPrice = (sale['unit_price'] as num).toDouble();
      final refund = unitPrice * quantity;
      await txn.insert('sale_returns', {'sale_id':saleId,'quantity':quantity,'refund_amount':refund,'reason':reason.trim(),'created_at':DateTime.now().toIso8601String()});
      final newReturned = returned + quantity;
      await txn.update('sales', {
        'returned_quantity': newReturned,
        'status': newReturned == sold ? 'returned' : 'partially_returned',
      }, where:'id=?', whereArgs:[saleId]);
      await txn.rawUpdate('UPDATE medicines SET quantity=quantity+? WHERE id=?',[quantity,sale['medicine_id']]);
      await _logStock(txn, sale['medicine_id'] as int, 'RETURN', quantity, reason.trim(), reference:'SALE-$saleId');
      await txn.insert('audit_log', {'action':'SALE_RETURN','details':'Sale $saleId qty $quantity refund $refund','created_at':DateTime.now().toIso8601String()});
    });
  }

  Future<void> checkpointForBackup() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    if (result.isNotEmpty && (result.first['busy'] as num? ?? 0) != 0) {
      throw Exception('Database bado inatumika; backup haijaandaliwa salama');
    }
  }

  Future<void> closeForRestore() async {
    await _db?.close();
    _db = null;
  }

  Future<int> addMedicine(Map<String, Object?> data) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('medicines', data);
      await txn.insert('audit_log', {
        'action': 'ADD_MEDICINE', 'details': data['name'],
        'created_at': DateTime.now().toIso8601String(),
      });
      final opening = (data['quantity'] as int?) ?? 0;
      if (opening > 0) await _logStock(txn, id, 'OPENING', opening, 'Opening stock');
      return id;
    });
  }

  Future<List<Map<String, Object?>>> medicines() async =>
      (await database).query('medicines', orderBy: 'name COLLATE NOCASE');

  Future<List<Map<String, Object?>>> sales() async =>
      (await database).query('sales', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> salesBetween(DateTime from, DateTime to) async {
    final a=DateTime(from.year,from.month,from.day).toIso8601String();
    final b=DateTime(to.year,to.month,to.day,23,59,59,999).toIso8601String();
    return (await database).query('sales', where:"created_at BETWEEN ? AND ?", whereArgs:[a,b], orderBy:'created_at DESC');
  }


  Future<void> recordSale({
    required int medicineId,
    required String medicineName,
    required int quantity,
    required double unitPrice,
    required double unitCost,
    required String paymentMethod,
    String customerName = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('medicines', where: 'id=?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw Exception('Medicine not found');
      final available = rows.first['quantity'] as int;
      if (quantity <= 0 || quantity > available) throw Exception('Stock haitoshi. Iliyopo: $available');

      var remaining = quantity;
      double totalCost = 0;
      final batches = await txn.query('medicine_batches',
        where: 'medicine_id=? AND quantity>0', whereArgs: [medicineId],
        orderBy: "CASE WHEN expiry_date IS NULL OR expiry_date='' THEN 1 ELSE 0 END, expiry_date ASC, id ASC");
      final batchTotal = batches.fold<int>(0, (sum, b) => sum + (b['quantity'] as int));
      final legacyStock = (available - batchTotal).clamp(0, available).toInt();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      for (final batch in batches) {
        if (remaining == 0) break;
        final batchExpiry = (batch['expiry_date'] ?? '').toString();
        if (batchExpiry.length >= 10 && batchExpiry.substring(0, 10).compareTo(today) < 0) continue;
        final batchQty = batch['quantity'] as int;
        final take = batchQty < remaining ? batchQty : remaining;
        await txn.update('medicine_batches', {'quantity': batchQty - take},
          where: 'id=?', whereArgs: [batch['id']]);
        totalCost += take * (batch['unit_cost'] as num).toDouble();
        remaining -= take;
      }
      if (remaining > 0 && legacyStock > 0) {
        final take = legacyStock < remaining ? legacyStock : remaining;
        totalCost += take * (rows.first['cost_price'] as num).toDouble();
        remaining -= take;
      }
      if (remaining > 0) throw Exception('Stock inayoweza kuuzwa haitoshi (baadhi ya batch zime-expire)');
      final effectiveUnitCost = totalCost / quantity;
      final total = quantity * unitPrice;
      final saleId = await txn.insert('sales', {
        'medicine_id': medicineId, 'medicine_name': medicineName,
        'quantity': quantity, 'unit_price': unitPrice, 'unit_cost': effectiveUnitCost,
        'total': total, 'profit': total - totalCost, 'payment_method': paymentMethod,
        'customer_name': customerName, 'created_at': DateTime.now().toIso8601String(),
      });
      await txn.update('medicines', {'quantity': available - quantity}, where: 'id=?', whereArgs: [medicineId]);
      await _logStock(txn, medicineId, 'SALE', quantity, 'Sale completed', reference:'SALE-$saleId');
      if (paymentMethod == 'Credit') {
        if (customerName.trim().isEmpty) throw Exception('Jina la mteja linahitajika kwa mauzo ya mkopo');
        await txn.insert('customer_debts', {
          'customer_name': customerName.trim(), 'sale_id': saleId,
          'amount': total, 'paid': 0, 'created_at': DateTime.now().toIso8601String(),
        });
      }
      await txn.insert('audit_log', {
        'action': 'SALE', 'details': '$medicineName x$quantity',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<String> recordSaleCart({required List<Map<String, Object?>> items,
      required String paymentMethod, String customerName = ''}) async {
    if (items.isEmpty) throw Exception('Ongeza angalau dawa moja kwenye kikapu');
    if (paymentMethod == 'Credit' && customerName.trim().isEmpty) throw Exception('Jina la mteja linahitajika kwa mkopo');
    final db = await database;
    final receiptId = 'AD-${DateTime.now().millisecondsSinceEpoch}';
    await db.transaction((txn) async {
      for (final item in items) {
        final medicineId = item['medicine_id'] as int;
        final quantity = item['quantity'] as int;
        final unitPrice = (item['unit_price'] as num).toDouble();
        if (quantity <= 0 || unitPrice < 0) throw Exception('Idadi au bei si sahihi');
        final rows = await txn.query('medicines', where:'id=?', whereArgs:[medicineId]);
        if (rows.isEmpty) throw Exception('Dawa haijapatikana');
        final medicine = rows.first;
        final available = medicine['quantity'] as int;
        if (quantity > available) throw Exception('Stock haitoshi kwa ${medicine['name']}');
        var remaining = quantity;
        double totalCost = 0;
        final batches = await txn.query('medicine_batches', where:'medicine_id=? AND quantity>0', whereArgs:[medicineId],
          orderBy:"CASE WHEN expiry_date IS NULL OR expiry_date='' THEN 1 ELSE 0 END, expiry_date ASC, id ASC");
        final batchTotal = batches.fold<int>(0,(sum,b)=>(sum+(b['quantity'] as int)));
        final legacyStock = (available-batchTotal).clamp(0,available).toInt();
        final today = DateTime.now().toIso8601String().substring(0,10);
        for (final batch in batches) {
          if (remaining==0) break;
          final expiry=(batch['expiry_date']??'').toString();
          if (expiry.length>=10 && expiry.substring(0,10).compareTo(today)<0) continue;
          final have=batch['quantity'] as int;
          final take=have<remaining?have:remaining;
          await txn.update('medicine_batches',{'quantity':have-take},where:'id=?',whereArgs:[batch['id']]);
          totalCost += take*(batch['unit_cost'] as num).toDouble();
          remaining-=take;
        }
        if (remaining>0 && legacyStock>0) {
          final take=legacyStock<remaining?legacyStock:remaining;
          totalCost += take*(medicine['cost_price'] as num).toDouble();
          remaining-=take;
        }
        if (remaining>0) throw Exception('Stock isiyo-expire haitoshi kwa ${medicine['name']}');
        final total=quantity*unitPrice;
        final saleId=await txn.insert('sales',{
          'medicine_id':medicineId,'medicine_name':medicine['name'],'quantity':quantity,
          'unit_price':unitPrice,'unit_cost':totalCost/quantity,'total':total,
          'profit':total-totalCost,'payment_method':paymentMethod,
          'customer_name':customerName.trim(),'receipt_id':receiptId,
          'status':'completed','returned_quantity':0,'created_at':DateTime.now().toIso8601String(),
        });
        await txn.update('medicines',{'quantity':available-quantity},where:'id=?',whereArgs:[medicineId]);
        await _logStock(txn,medicineId,'SALE',quantity,'Sale completed',reference:receiptId);
        if (paymentMethod=='Credit') await txn.insert('customer_debts',{
          'customer_name':customerName.trim(),'sale_id':saleId,'amount':total,'paid':0,
          'created_at':DateTime.now().toIso8601String(),
        });
      }
      await txn.insert('audit_log',{'action':'SALE_RECEIPT','details':'$receiptId • ${items.length} lines','created_at':DateTime.now().toIso8601String()});
    });
    return receiptId;
  }

  Future<void> addExpense(String title, double amount, String note) async {
    if (title.trim().isEmpty || amount <= 0) throw Exception('Jina na kiasi cha matumizi si sahihi');
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('expenses', {
        'title': title.trim(), 'amount': amount, 'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('audit_log', {
        'action': 'ADD_EXPENSE', 'details': '$title: $amount',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<Map<String, num>> summary() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final s = await db.rawQuery(
      'SELECT COALESCE(SUM(total - unit_price * returned_quantity),0) sales, '
      'COALESCE(SUM(profit - (unit_price - unit_cost) * returned_quantity),0) profit '
      'FROM sales WHERE created_at >= ?',
      [start],
    );
    final e = await db.rawQuery('SELECT COALESCE(SUM(amount),0) amount FROM expenses WHERE created_at >= ?', [start]);
    final netProfit = (s.first['profit'] as num) - (e.first['amount'] as num);
    final stock = await db.rawQuery('SELECT COALESCE(SUM(quantity),0) count FROM medicines');
    final low = await db.rawQuery('SELECT COUNT(*) count FROM medicines WHERE quantity <= min_stock');
    return {
      'sales': (s.first['sales'] as num),
      'profit': netProfit,
      'grossProfit': (s.first['profit'] as num),
      'expenses': (e.first['amount'] as num),
      'stock': (stock.first['count'] as num),
      'low': (low.first['count'] as num),
    };
  }


  Future<void> _createBusinessTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER,
        supplier_name TEXT NOT NULL,
        medicine_id INTEGER,
        medicine_name TEXT NOT NULL,
        batch_no TEXT,
        expiry_date TEXT,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        total REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_name TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }


  Future<void> _createAdvancedTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicine_batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        batch_no TEXT,
        expiry_date TEXT,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_debts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        sale_id INTEGER,
        amount REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> addCustomer(String name, String phone) async {
    await (await database).insert('customers', {
      'name': name, 'phone': phone, 'created_at': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, Object?>>> customers() async =>
      (await database).query('customers', orderBy: 'name COLLATE NOCASE');

  Future<List<Map<String, Object?>>> customerDebts() async =>
      (await database).query('customer_debts', orderBy: 'created_at DESC');

  Future<void> recordCustomerDebtPayment(int debtId, double amount, String note) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('customer_debts', where: 'id=?', whereArgs: [debtId]);
      if (rows.isEmpty) throw Exception('Deni halijapatikana');
      final row = rows.first;
      final balance = (row['amount'] as num) - (row['paid'] as num);
      if (amount <= 0 || amount > balance) throw Exception('Kiasi si sahihi. Deni lililobaki: $balance');
      await txn.insert('customer_debt_payments', {
        'debt_id': debtId, 'amount': amount, 'note': note,
        'created_at': DateTime.now().toIso8601String()
      });
      await txn.update('customer_debts', {'paid': (row['paid'] as num) + amount},
        where: 'id=?', whereArgs: [debtId]);
      await txn.insert('audit_log', {
        'action': 'CUSTOMER_DEBT_PAYMENT', 'details': 'Debt $debtId payment $amount',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> supplierBalances() async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.supplier_name AS name,
        COALESCE(SUM(p.total), 0) AS purchased,
        COALESCE(SUM(p.paid), 0) + COALESCE((
          SELECT SUM(sp.amount) FROM supplier_payments sp
          WHERE sp.supplier_name = p.supplier_name
        ), 0) AS paid,
        COALESCE(SUM(p.total - p.paid), 0) - COALESCE((
          SELECT SUM(sp.amount) FROM supplier_payments sp
          WHERE sp.supplier_name = p.supplier_name
        ), 0) AS balance
      FROM purchases p
      GROUP BY p.supplier_name
      ORDER BY p.supplier_name COLLATE NOCASE
    ''');
  }

  Future<void> addSupplierPayment(String supplierName, double amount, String note) async {
    final db = await database;
    if (amount <= 0) throw Exception('Kiasi si sahihi');
    await db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT COALESCE(SUM(total - paid), 0) AS outstanding
        FROM purchases WHERE supplier_name = ?
      ''', [supplierName]);
      final previousPayments = await txn.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM supplier_payments WHERE supplier_name = ?
      ''', [supplierName]);
      final outstanding = (rows.first['outstanding'] as num).toDouble() -
          (previousPayments.first['total'] as num).toDouble();
      if (outstanding <= 0 || amount > outstanding) {
        throw Exception('Malipo yanazidi deni lililobaki: $outstanding');
      }
      await txn.insert('supplier_payments', {
        'supplier_name': supplierName, 'amount': amount, 'note': note,
        'created_at': DateTime.now().toIso8601String()
      });
      await txn.insert('audit_log', {
        'action': 'SUPPLIER_PAYMENT', 'details': '$supplierName: $amount',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> supplierPayments() async =>
      (await database).query('supplier_payments', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> batchList() async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.*, m.name AS medicine_name FROM medicine_batches b
      JOIN medicines m ON m.id=b.medicine_id
      WHERE b.quantity > 0 ORDER BY
      CASE WHEN b.expiry_date IS NULL OR b.expiry_date='' THEN 1 ELSE 0 END,
      b.expiry_date ASC
    ''');
  }

  Future<List<Map<String, Object?>>> suppliers() async =>
      (await database).query('suppliers', orderBy: 'name COLLATE NOCASE');

  Future<void> addSupplier(String name, String phone, String address) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('suppliers', {
        'name': name.trim(), 'phone': phone.trim(), 'address': address.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('audit_log', {
        'action': 'ADD_SUPPLIER', 'details': name.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> receivePurchase({
    required String supplierName,
    required int medicineId,
    required String medicineName,
    required String batchNo,
    required String expiryDate,
    required int quantity,
    required double unitCost,
    required double paid,
  }) async {
    if (quantity <= 0 || unitCost < 0 || paid < 0) throw Exception('Taarifa za manunuzi si sahihi');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('medicines', where: 'id=?', whereArgs: [medicineId]);
      if (rows.isEmpty) throw Exception('Dawa haijapatikana');
      final oldQty = rows.first['quantity'] as int;
      final total = quantity * unitCost;
      await txn.insert('purchases', {
        'supplier_name': supplierName, 'medicine_id': medicineId,
        'medicine_name': medicineName, 'batch_no': batchNo,
        'expiry_date': expiryDate, 'quantity': quantity,
        'unit_cost': unitCost, 'total': total, 'paid': paid,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('medicine_batches', {
        'medicine_id': medicineId, 'batch_no': batchNo, 'expiry_date': expiryDate,
        'quantity': quantity, 'unit_cost': unitCost,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.update('medicines', {
        'quantity': oldQty + quantity,
        'cost_price': unitCost,
        'batch_no': batchNo,
        'expiry_date': expiryDate,
      }, where: 'id=?', whereArgs: [medicineId]);
      await _logStock(txn, medicineId, 'PURCHASE', quantity, 'Purchase received', reference:'PURCHASE-${DateTime.now().millisecondsSinceEpoch}');
      await txn.insert('audit_log', {
        'action': 'PURCHASE_RECEIVED',
        'details': '$medicineName +$quantity from $supplierName',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, Object?>>> purchases() async =>
      (await database).query('purchases', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> expenses() async =>
      (await database).query('expenses', orderBy: 'created_at DESC');

  Future<List<Map<String, Object?>>> expiringMedicines({int days = 90}) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final cutoff = DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);
    final batchRows = await db.rawQuery("""
      SELECT b.id AS batch_id, b.medicine_id, m.name, b.batch_no, b.expiry_date,
             b.quantity, b.unit_cost,
             CASE WHEN substr(b.expiry_date,1,10) < ? THEN 'expired' ELSE 'soon' END AS expiry_status
      FROM medicine_batches b JOIN medicines m ON m.id=b.medicine_id
      WHERE b.quantity > 0 AND b.expiry_date IS NOT NULL AND b.expiry_date != ''
        AND substr(b.expiry_date,1,10) <= ? ORDER BY b.expiry_date ASC
    """, [today, cutoff]);
    final legacyRows = await db.rawQuery("""
      SELECT m.id AS medicine_id, m.name, m.batch_no, m.expiry_date,
             MAX(0, m.quantity - COALESCE((
               SELECT SUM(b.quantity) FROM medicine_batches b
               WHERE b.medicine_id=m.id AND b.quantity>0
             ), 0)) AS quantity,
             m.cost_price AS unit_cost,
             CASE WHEN substr(m.expiry_date,1,10) < ? THEN 'expired' ELSE 'soon' END AS expiry_status
      FROM medicines m
      WHERE m.expiry_date IS NOT NULL AND m.expiry_date != ''
        AND substr(m.expiry_date,1,10) <= ?
        AND m.quantity > COALESCE((
          SELECT SUM(b.quantity) FROM medicine_batches b
          WHERE b.medicine_id=m.id AND b.quantity>0
        ), 0)
      ORDER BY m.expiry_date ASC
    """, [today, cutoff]);
    return [...batchRows, ...legacyRows];
  }

  String _pbkdf2(String value, String saltText, {int iterations = 120000}) {
    final salt = base64Decode(saltText);
    final key = utf8.encode(value);
    final hmac = Hmac(sha256, key);
    final block = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final out = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) { out[j] ^= u[j]; }
    }
    return base64Encode(out);
  }

  String _newCredentialHash(String value) {
    final salt = base64Encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    return 'pbkdf2:120000:$salt:${_pbkdf2(value,salt)}';
  }

  bool _verifyStored(String value, String stored) {
    final parts = stored.split(':');
    if (parts.length == 4 && parts[0] == 'pbkdf2') {
      final actual = _pbkdf2(value, parts[2], iterations:int.tryParse(parts[1]) ?? 120000);
      return actual == parts[3];
    }
    if (parts.length == 2) return sha256.convert(utf8.encode('$value:${parts[0]}')).toString() == parts[1];
    return false;
  }

  Future<bool> _authLocked(Database db, String username) async {
    final rows = await db.query('auth_attempts', where:'username=?', whereArgs:[username]);
    if (rows.isEmpty || rows.first['locked_until'] == null) return false;
    final until = DateTime.tryParse(rows.first['locked_until'] as String);
    if (until == null || !DateTime.now().isBefore(until)) {
      await db.delete('auth_attempts', where:'username=?', whereArgs:[username]);
      return false;
    }
    return true;
  }

  Future<void> _authFailure(Database db, String username) async {
    final rows = await db.query('auth_attempts', where:'username=?', whereArgs:[username]);
    final count = (rows.isEmpty ? 0 : rows.first['failed_attempts'] as int) + 1;
    final lock = count >= 5 ? DateTime.now().add(const Duration(minutes:5)).toIso8601String() : null;
    await db.insert('auth_attempts', {'username':username,'failed_attempts':count,'locked_until':lock},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> _authSuccess(Database db, String username) async {
    await db.delete('auth_attempts', where:'username=?', whereArgs:[username]);
  }

  Future<bool> verifyPassword(String username, String password) async {
    final db = await database;
    if (await _authLocked(db, username)) return false;
    final rows = await db.query('app_users', where: 'username=?', whereArgs: [username]);
    if (rows.isEmpty) { await _authFailure(db, username); return false; }
    final stored = rows.first['password_hash'] as String;
    final ok = _verifyStored(password, stored);
    if (ok) { await _authSuccess(db, username); } else { await _authFailure(db, username); }
    if (ok && !stored.startsWith('pbkdf2:')) await db.update('app_users', {'password_hash':_newCredentialHash(password)}, where:'username=?', whereArgs:[username]);
    return ok;
  }

  Future<bool> verifyPin(String username, String pin) async {
    final db = await database;
    if (await _authLocked(db, username)) return false;
    final rows = await db.query('app_users', where: 'username=?', whereArgs: [username]);
    if (rows.isEmpty) { await _authFailure(db, username); return false; }
    final stored = rows.first['pin_hash'] as String;
    final ok = _verifyStored(pin, stored);
    if (ok) { await _authSuccess(db, username); } else { await _authFailure(db, username); }
    if (ok && !stored.startsWith('pbkdf2:')) await db.update('app_users', {'pin_hash':_newCredentialHash(pin)}, where:'username=?', whereArgs:[username]);
    return ok;
  }

  Future<bool> verifyAdminPassword(String password) async {
    final db = await database;
    final rows = await db.query('app_users', orderBy: 'id ASC', limit: 1);
    if (rows.isEmpty) return false;
    final username = rows.first['username'] as String;
    if (await _authLocked(db, username)) return false;
    final stored = rows.first['password_hash'] as String;
    final ok = _verifyStored(password, stored);
    if (ok) { await _authSuccess(db, username); } else { await _authFailure(db, username); }
    if (ok && !stored.startsWith('pbkdf2:')) await db.update('app_users', {'password_hash':_newCredentialHash(password)}, where:'id=?', whereArgs:[rows.first['id']]);
    return ok;
  }

  Future<void> changeCredentials({
    required String username,
    String? newPassword,
    String? newPin,
  }) async {
    final db = await database;
    final rows = await db.query('app_users', orderBy: 'id ASC', limit: 1);
    if (rows.isEmpty) throw Exception('Admin account not found');
    final old = rows.first;
    final currentPassword = old['password_hash'] as String;
    final currentPin = old['pin_hash'] as String;
    String make(String value) => _newCredentialHash(value);
    await db.update('app_users', {
      'username': username,
      'password_hash': newPassword == null || newPassword.isEmpty ? currentPassword : make(newPassword),
      'pin_hash': newPin == null || newPin.isEmpty ? currentPin : make(newPin),
    }, where: 'id=?', whereArgs: [old['id']]);
    await db.insert('audit_log', {
      'action': 'ADMIN_CREDENTIALS_CHANGED',
      'details': 'Admin login credentials updated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

}
