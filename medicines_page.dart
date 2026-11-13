import 'package:flutter/material.dart';
import 'db.dart';

class MedicinesPage extends StatefulWidget {
  final bool swahili;
  const MedicinesPage({super.key, required this.swahili});
  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  List<Map<String, Object?>> items = [];
  String search = '';
  String t(String sw, String en) => widget.swahili ? sw : en;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.medicines(); if (mounted) setState(() => items = x); }

  Future<void> add() async {
    final name = TextEditingController(), generic = TextEditingController(), batch = TextEditingController();
    final cost = TextEditingController(text: '0'), price = TextEditingController(text: '0');
    final qty = TextEditingController(text: '0'), min = TextEditingController(text: '5');
    final expiry = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Ongeza dawa','Add medicine')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(name, t('Jina la dawa *','Medicine name *')),
        _field(generic, t('Generic name','Generic name')),
        _field(batch, t('Batch number','Batch number')),
        _field(expiry, t('Expiry (YYYY-MM-DD)','Expiry (YYYY-MM-DD)')),
        _field(cost, t('Bei ya kununulia','Cost price'), number: true),
        _field(price, t('Bei ya kuuzia','Selling price'), number: true),
        _field(qty, t('Idadi iliyopo','Quantity'), number: true),
        _field(min, t('Tahadhari stock chini ya','Low stock threshold'), number: true),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Hifadhi','Save')))],
    ));
    if (ok == true && name.text.trim().isNotEmpty) {
      await AppDb.instance.addMedicine({
        'name': name.text.trim(), 'generic_name': generic.text.trim(), 'category': '',
        'batch_no': batch.text.trim(), 'expiry_date': expiry.text.trim(),
        'cost_price': double.tryParse(cost.text) ?? 0, 'selling_price': double.tryParse(price.text) ?? 0,
        'quantity': int.tryParse(qty.text) ?? 0, 'min_stock': int.tryParse(min.text) ?? 5,
        'created_at': DateTime.now().toIso8601String(),
      });
      await load();
    }
  }

  Future<void> adjustStock(Map<String, Object?> medicine) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Rekebisha stock','Adjust stock')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${medicine['name']} • Stock: ${medicine['quantity']}'),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(labelText: t('Idadi (+ kuongeza, - kupunguza)','Quantity (+ add, - remove)'))),
        const SizedBox(height: 8),
        TextField(controller: reason, decoration: InputDecoration(labelText: t('Sababu ya marekebisho','Reason for adjustment'))),
      ]),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false), child:Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true), child:Text(t('Hifadhi','Save')))],
    ));
    if (ok != true) return;
    try {
      await AppDb.instance.adjustStock(medicineId: medicine['id'] as int,
        change: int.tryParse(amount.text) ?? 0, reason: reason.text);
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Stock imerekebishwa','Stock adjusted'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where((m) => (m['name'] as String).toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t('Dawa na stock','Medicines & stock'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: Text(t('Ongeza dawa','Add medicine'))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: t('Tafuta dawa...','Search medicine...'), border: const OutlineInputBorder()),
          onChanged: (v) => setState(() => search = v),
        )),
        Expanded(child: shown.isEmpty ? Center(child: Text(t('Hakuna dawa bado. Ongeza dawa ya kwanza.','No medicines yet. Add the first medicine.'))) :
          ListView.builder(itemCount: shown.length, itemBuilder: (_, i) {
            final m = shown[i]; final low = (m['quantity'] as int) <= (m['min_stock'] as int);
            return Card(child: ListTile(
              leading: CircleAvatar(child: const Icon(Icons.medication)),
              title: Text('${m['name']}'),
              subtitle: Text('Batch: ${m['batch_no']}  •  Exp: ${m['expiry_date']}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${m['quantity']} pcs', style: TextStyle(fontWeight: FontWeight.bold, color: low ? Colors.red : Colors.green)),
                  Text('TSh ${m['selling_price']}', style: const TextStyle(fontSize: 11)),
                ]),
                IconButton(tooltip: t('Rekebisha stock','Adjust stock'), icon: const Icon(Icons.tune), onPressed: () => adjustStock(m)),
              ]),
            ));
          })),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
  );
}
