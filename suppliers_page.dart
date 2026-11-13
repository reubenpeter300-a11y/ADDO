import 'package:flutter/material.dart';
import 'db.dart';

class SuppliersPage extends StatefulWidget {
  final bool swahili;
  const SuppliersPage({super.key, required this.swahili});
  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  List<Map<String, Object?>> rows = [];
  String t(String sw, String en) => widget.swahili ? sw : en;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.suppliers(); if (mounted) setState(() => rows = x); }

  Future<void> add() async {
    final name = TextEditingController(), phone = TextEditingController(), address = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Msambazaji mpya','New supplier')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(name, t('Jina','Name')), _field(phone, t('Simu','Phone')), _field(address, t('Anuani','Address')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Hifadhi','Save')))],
    ));
    if (ok == true && name.text.trim().isNotEmpty) {
      await AppDb.instance.addSupplier(name.text.trim(), phone.text.trim(), address.text.trim());
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Wasambazaji','Suppliers'))),
    floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: Text(t('Ongeza supplier','Add supplier'))),
    body: rows.isEmpty ? Center(child: Text(t('Hakuna wasambazaji bado.','No suppliers yet.'))) :
      ListView(children: rows.map((x) => Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
        title: Text('${x['name']}'), subtitle: Text('${x['phone'] ?? ''} • ${x['address'] ?? ''}'),
      ))).toList()),
  );

  Widget _field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
}
