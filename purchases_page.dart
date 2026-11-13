import 'package:flutter/material.dart';
import 'db.dart';

class PurchasesPage extends StatefulWidget {
  final bool swahili;
  const PurchasesPage({super.key, required this.swahili});
  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  List<Map<String, Object?>> medicines = [], suppliers = [], history = [];
  int? medicineId;
  final supplier = TextEditingController(), batch = TextEditingController(), expiry = TextEditingController();
  final qty = TextEditingController(text: '1'), cost = TextEditingController(text: '0'), paid = TextEditingController(text: '0');
  String t(String sw, String en) => widget.swahili ? sw : en;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final a = await AppDb.instance.medicines(), b = await AppDb.instance.suppliers(), c = await AppDb.instance.purchases();
    if (mounted) setState(() { medicines = a; suppliers = b; history = c; });
  }

  @override
  Widget build(BuildContext context) {
    final m = medicines.where((x) => x['id'] == medicineId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(t('Manunuzi ya dawa','Medicine purchases'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('Pokea mzigo mpya','Receive stock'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          value: medicineId, isExpanded: true,
          decoration: InputDecoration(labelText: t('Chagua dawa iliyosajiliwa','Select existing medicine'), border: const OutlineInputBorder()),
          items: medicines.map((x) => DropdownMenuItem(value: x['id'] as int, child: Text('${x['name']}'))).toList(),
          onChanged: (v) => setState(() => medicineId = v),
        ),
        const SizedBox(height: 10),
        _field(supplier, t('Jina la supplier','Supplier name')),
        _field(batch, 'Batch number'),
        _field(expiry, t('Expiry YYYY-MM-DD','Expiry YYYY-MM-DD')),
        _field(qty, t('Idadi iliyonunuliwa','Quantity purchased'), num: true),
        _field(cost, t('Bei ya kununulia kwa kipande','Unit cost price'), num: true),
        _field(paid, t('Kiasi kilicholipwa','Amount paid'), num: true),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: m == null ? null : () async {
          try {
            await AppDb.instance.receivePurchase(
              supplierName: supplier.text.trim().isEmpty ? 'Supplier' : supplier.text.trim(),
              medicineId: m['id'] as int, medicineName: m['name'] as String,
              batchNo: batch.text.trim(), expiryDate: expiry.text.trim(),
              quantity: int.tryParse(qty.text) ?? 0,
              unitCost: double.tryParse(cost.text) ?? 0,
              paid: double.tryParse(paid.text) ?? 0,
            );
            await load();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Mzigo umeongezwa kwenye stock','Stock received successfully'))));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }, icon: const Icon(Icons.inventory), label: Text(t('Hifadhi manunuzi na ongeza stock','Save purchase & add stock'))),
        const Divider(height: 30),
        Text(t('Historia ya manunuzi','Purchase history'), style: Theme.of(context).textTheme.titleLarge),
        ...history.map((x) => Card(child: ListTile(
          title: Text('${x['medicine_name']} × ${x['quantity']}'),
          subtitle: Text('${x['supplier_name']} • ${x['created_at']}'),
          trailing: Text('TSh ${x['total']}'),
        ))),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {bool num = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: TextField(controller: c, keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
}
