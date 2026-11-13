import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db.dart';

class DebtsPage extends StatefulWidget {
  final bool swahili;
  const DebtsPage({super.key, required this.swahili});
  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  List<Map<String, Object?>> rows = [];
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.customerDebts(); if (mounted) setState(() => rows = x); }

  Future<void> pay(Map<String, Object?> row) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final balance = (row['amount'] as num) - (row['paid'] as num);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Pokea malipo ya deni','Record debt payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Deni lililobaki: TSh ${money.format(balance)}'),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: t('Kiasi kilicholipwa','Amount paid'))),
        TextField(controller: note, decoration: InputDecoration(labelText: t('Maelezo','Notes'))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Hifadhi','Save')))],
    ));
    if (ok == true) {
      try {
        await AppDb.instance.recordCustomerDebtPayment(row['id'] as int, double.tryParse(amount.text) ?? 0, note.text);
        await load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> statement(String name) async {
    final entries = await AppDb.instance.customerStatement(name);
    if (!mounted) return;
    await showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(
      child: Padding(padding:const EdgeInsets.all(16),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('${t('Taarifa ya deni','Customer statement')}: $name',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:8),
        if(entries.isEmpty) Text(t('Hakuna miamala ya deni.','No debt transactions.')),
        ...entries.map((e)=>ListTile(dense:true,title:Text('${e['medicine_name']} • ${e['created_at']}'),subtitle:Text('${t('Deni','Debt')}: TSh ${money.format(e['amount'])}  |  ${t('Limelipwa','Paid')}: TSh ${money.format(e['paid'])}'),trailing:Text(money.format(e['balance'])))),
        const SizedBox(height:12),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = rows.fold<num>(0, (s, r) => s + (r['amount'] as num) - (r['paid'] as num));
    return Scaffold(
      appBar: AppBar(title: Text(t('Madeni ya wateja','Customer debts'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(title: Text(t('Jumla ya madeni yaliyobaki','Total outstanding')),
          subtitle: Text('TSh ${money.format(outstanding)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
        ...rows.map((r) {
          final balance = (r['amount'] as num) - (r['paid'] as num);
          return Card(child: ListTile(
            title: Text('${r['customer_name']}'),
            subtitle: Text('Deni: TSh ${money.format(r['amount'])} • Limelipwa: TSh ${money.format(r['paid'])}'),
            trailing: Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:t('Taarifa ya deni','Statement'),icon:const Icon(Icons.receipt_long),onPressed:()=>statement(r['customer_name'] as String)),balance > 0 ? IconButton(icon: const Icon(Icons.payments), onPressed: () => pay(r)) : const Icon(Icons.check_circle, color: Colors.green)]),
          ));
        }),
      ]),
    );
  }
}
