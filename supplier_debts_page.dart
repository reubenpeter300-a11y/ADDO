import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db.dart';

class SupplierDebtsPage extends StatefulWidget {
  final bool swahili;
  const SupplierDebtsPage({super.key, required this.swahili});
  @override
  State<SupplierDebtsPage> createState() => _SupplierDebtsPageState();
}

class _SupplierDebtsPageState extends State<SupplierDebtsPage> {
  List<Map<String, Object?>> rows = [];
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.supplierBalances(); if (mounted) setState(() => rows = x); }

  Future<void> pay(Map<String, Object?> row) async {
    final amount = TextEditingController(), note = TextEditingController();
    final balance = (row['balance'] as num).toDouble();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Rekodi malipo kwa supplier','Record supplier payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Deni la manunuzi: TSh ${money.format(balance)}'),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: t('Kiasi','Amount'))),
        TextField(controller: note, decoration: InputDecoration(labelText: t('Maelezo','Notes'))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Hifadhi','Save')))],
    ));
    if (ok == true) {
      final v = double.tryParse(amount.text) ?? 0;
      if (v <= 0 || v > balance) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Kiasi kinazidi deni au si sahihi','Amount exceeds balance or is invalid'))));
        return;
      }
      await AppDb.instance.addSupplierPayment(row['name'].toString(), v, note.text);
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Madeni ya suppliers','Supplier balances'))),
    body: ListView(padding: const EdgeInsets.all(12), children: rows.map((r) {
      final balance = (r['balance'] as num) - (AppDb.instance /* payment ledger is separately tracked */ == null ? 0 : 0);
      return Card(child: ListTile(
        title: Text('${r['name']}'),
        subtitle: Text('Manunuzi: TSh ${money.format(r['purchased'])} • Paid at purchase: TSh ${money.format(r['paid'])}'),
        trailing: Text('TSh ${money.format(balance)}'),
        onTap: () => pay(r),
      ));
    }).toList()),
  );
}
