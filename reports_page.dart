import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db.dart';

class ReportsPage extends StatefulWidget {
  final bool swahili;
  const ReportsPage({super.key, required this.swahili});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, Object?>> rows = [];
  late DateTime from;
  late DateTime to;
  Map<String, num> totals = {};
  bool loading = true;
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');
  final dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = DateTime(now.year, now.month, 1);
    to = DateTime(now.year, now.month, now.day);
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final result = await Future.wait([
      AppDb.instance.salesBetween(from, to),
      AppDb.instance.reportTotals(from, to),
    ]);
    if (!mounted) return;
    setState(() {
      rows = result[0] as List<Map<String, Object?>>;
      totals = result[1] as Map<String, num>;
      loading = false;
    });
  }

  Future<void> chooseDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        from = selected;
        if (from.isAfter(to)) to = from;
      } else {
        to = selected;
        if (to.isBefore(from)) from = to;
      }
    });
    await load();
  }

  String csvCell(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';

  Future<void> exportCsv() async {
    final header = ['Date', 'Medicine', 'Quantity', 'Unit price', 'Total', 'Profit', 'Payment', 'Customer'];
    final lines = <String>[header.map(csvCell).join(',')];
    for (final r in rows) {
      lines.add([r['created_at'], r['medicine_name'], r['quantity'], r['unit_price'],
        ((r['total'] as num) - (r['unit_price'] as num) * ((r['returned_quantity'] as int?) ?? 0)), ((r['profit'] as num) - (((r['unit_price'] as num) - (r['unit_cost'] as num)) * ((r['returned_quantity'] as int?) ?? 0))), r['payment_method'], r['customer_name']].map(csvCell).join(','));
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ADDO_sales_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
    await file.writeAsString('\uFEFF${lines.join('\r\n')}', flush: true);
    await Share.shareXFiles([XFile(file.path)], text: t('Ripoti ya mauzo ya ADDO Manager', 'ADDO Manager sales report'));
  }

  Future<void> returnItem(Map<String, Object?> row) async {
    final quantity = TextEditingController(text: '1');
    final reason = TextEditingController();
    final maxReturn = (row['quantity'] as int) - ((row['returned_quantity'] as int?) ?? 0);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Rejesha bidhaa','Return item')),
      content: Column(mainAxisSize:MainAxisSize.min,children:[
        Text('${row['medicine_name']} • ${t('Zinazoweza kurejeshwa','Available to return')}: $maxReturn'),
        TextField(controller:quantity,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Idadi ya kurejesha','Return quantity'))),
        TextField(controller:reason,decoration:InputDecoration(labelText:t('Sababu','Reason'))),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('Ghairi','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('Thibitisha','Confirm')))],
    ));
    if(ok!=true)return;
    try {
      await AppDb.instance.returnSale(saleId:row['id'] as int,quantity:int.tryParse(quantity.text)??0,reason:reason.text);
      await load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Marejesho yamehifadhiwa','Return recorded'))));
    } catch(e) { if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); }
  }

  Widget metric(String label, num value, IconData icon, {bool emphasis = false}) => Card(
    child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
      CircleAvatar(backgroundColor: emphasis ? const Color(0xFFE8F3F1) : const Color(0xFFF0F3F7),
        child: Icon(icon, color: const Color(0xFF087E78))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text('TSh ${money.format(value)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ])),
    ])),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Ripoti za biashara', 'Business reports'))),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('Chagua kipindi cha ripoti', 'Choose report period'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => chooseDate(true), icon: const Icon(Icons.calendar_month), label: Text('${t('Kuanzia','From')}\n${dateFormat.format(from)}'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => chooseDate(false), icon: const Icon(Icons.event), label: Text('${t('Mpaka','To')}\n${dateFormat.format(to)}'))),
        ]),
        const SizedBox(height: 12),
        metric(t('Jumla ya mauzo','Total sales'), totals['sales'] ?? 0, Icons.point_of_sale),
        metric(t('Faida ghafi','Gross profit'), totals['grossProfit'] ?? 0, Icons.trending_up),
        metric(t('Matumizi','Expenses'), totals['expenses'] ?? 0, Icons.receipt_long),
        metric(t('Faida baada ya matumizi','Net profit after expenses'), totals['netProfit'] ?? 0, Icons.account_balance_wallet, emphasis: true),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: rows.isEmpty ? null : exportCsv,
          icon: const Icon(Icons.file_download_outlined), label: Text(t('Hamisha ripoti ya CSV/Excel', 'Export CSV/Excel report'))),
        const SizedBox(height: 18),
        Text(t('Miamala katika kipindi hiki','Transactions in this period'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...rows.map((r) => Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
          title: Text('${r['medicine_name']} × ${r['quantity']}'),
          subtitle: Text('${r['payment_method']} • ${r['created_at']}'),
          trailing: Row(mainAxisSize:MainAxisSize.min,children:[
            Text('TSh ${money.format((r['total'] as num) - (r['unit_price'] as num) * ((r['returned_quantity'] as int?) ?? 0))}', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(tooltip:t('Rejesha','Return'),onPressed:((r['quantity'] as int)-((r['returned_quantity'] as int?)??0))<=0?null:()=>returnItem(r),icon:const Icon(Icons.assignment_return_outlined)),
          ]),
        ))),
        if (rows.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(t('Hakuna mauzo katika kipindi hiki.','No sales in this period.')))),
      ]),
    ),
  );
}
