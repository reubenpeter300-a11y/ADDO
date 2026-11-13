import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db.dart';

class ExpensesPage extends StatefulWidget {
  final bool swahili;
  const ExpensesPage({super.key, required this.swahili});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, Object?>> rows = [];
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.expenses(); if (mounted) setState(() => rows = x); }

  Future<void> add() async {
    final title = TextEditingController(), amount = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Ongeza matumizi','Add expense')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(title, t('Aina ya matumizi','Expense title')),
        _field(amount, t('Kiasi (TSh)','Amount (TSh)'), num: true),
        _field(note, t('Maelezo','Notes')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Hifadhi','Save')))],
    ));
    final value = double.tryParse(amount.text) ?? 0;
    if (ok == true && title.text.trim().isNotEmpty && value > 0) {
      await AppDb.instance.addExpense(title.text.trim(), value, note.text.trim());
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<num>(0, (s, x) => s + (x['amount'] as num));
    return Scaffold(
      appBar: AppBar(title: Text(t('Matumizi ya duka','Shop expenses'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: Text(t('Ongeza matumizi','Add expense'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(title: Text(t('Jumla ya matumizi yaliyorekodiwa','Total recorded expenses')),
          subtitle: Text('TSh ${money.format(total)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
        ...rows.map((x) => Card(child: ListTile(
          title: Text('${x['title']}'), subtitle: Text('${x['note'] ?? ''} • ${x['created_at']}'),
          trailing: Text('TSh ${money.format(x['amount'])}'),
        ))),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {bool num = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
}
