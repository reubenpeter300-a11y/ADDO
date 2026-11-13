import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'db.dart';
import 'medicines_page.dart';
import 'sale_page.dart';
import 'reports_page.dart';
import 'purchases_page.dart';
import 'suppliers_page.dart';
import 'expenses_page.dart';
import 'expiry_page.dart';
import 'debts_page.dart';
import 'supplier_debts_page.dart';

class HomePage extends StatefulWidget {
  final bool swahili;
  final ValueChanged<bool> onLanguageChanged;
  const HomePage({super.key, required this.swahili, required this.onLanguageChanged});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, num> stats = {};
  bool loading = true;
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0');

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    try {
      final result = await AppDb.instance.summary();
      if (!mounted) return;
      setState(() { stats = result; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('d MMMM yyyy').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_pharmacy_rounded, size: 21, color: brandGold)),
          const SizedBox(width: 10),
          const Text('ADDO Manager'),
        ]),
        actions: [
          IconButton(tooltip: t('Onyesha upya','Refresh'), onPressed: refresh, icon: const Icon(Icons.refresh_rounded)),
          TextButton(onPressed: () => widget.onLanguageChanged(!widget.swahili), child: Text(widget.swahili ? 'EN' : 'SW', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 6),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandNavy, Color(0xFF174B59), brandTeal]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: brandNavy.withOpacity(.16), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t('DASHBOARD YA BIASHARA','BUSINESS DASHBOARD'), style: const TextStyle(color: Color(0xFFB9D9D7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4))),
                  const Icon(Icons.verified_user_outlined, color: brandGold, size: 19),
                ]),
                const SizedBox(height: 12),
                Text(t('Karibu tena','Welcome back'), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(now, style: const TextStyle(color: Color(0xFFD4E3E8), fontSize: 12)),
                const SizedBox(height: 18),
                Row(children: [
                  const Icon(Icons.wifi_off_rounded, size: 15, color: Color(0xFFB9D9D7)),
                  const SizedBox(width: 7),
                  Text(t('Inafanya kazi bila internet','Working offline'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            const SizedBox(height: 22),
            _sectionTitle(t('Muhtasari wa leo','Today at a glance'), t('Taarifa za biashara','Business metrics')),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 11, mainAxisSpacing: 11, childAspectRatio: 1.42,
              children: [
                _stat(t('Mauzo ya leo','Today sales'), 'TSh ${money.format(stats['sales'] ?? 0)}', Icons.point_of_sale_rounded, const Color(0xFF087E78)),
                _stat(t('Faida baada ya matumizi','Profit after expenses'), 'TSh ${money.format(stats['profit'] ?? 0)}', Icons.trending_up_rounded, const Color(0xFFB1842E)),
                _stat(t('Vipande vya stock','Stock units'), money.format(stats['stock'] ?? 0), Icons.inventory_2_rounded, const Color(0xFF496A9B)),
                _stat(t('Dawa stock ndogo','Low stock items'), money.format(stats['low'] ?? 0), Icons.warning_amber_rounded, const Color(0xFFB65B43)),
              ],
            ),
            const SizedBox(height: 22),
            _sectionTitle(t('Vitendo vya haraka','Quick actions'), t('Chagua kazi unayotaka kufanya','Choose what you want to do')),
            const SizedBox(height: 10),
            _action(context, t('Fanya mauzo','Make a sale'), t('Rekodi mauzo ya mteja','Record a customer sale'), Icons.shopping_bag_rounded, brandTeal, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => SalePage(swahili: widget.swahili))); refresh();
            }, prominent: true),
            _action(context, t('Dawa na stock','Medicines & stock'), t('Ona dawa na idadi iliyopo','View medicines and quantities'), Icons.medication_rounded, const Color(0xFF496A9B), () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicinesPage(swahili: widget.swahili))); refresh();
            }),
            _action(context, t('Manunuzi na kupokea mzigo','Purchases & receiving'), t('Ongeza mzigo mpya wa dawa','Add incoming medicine stock'), Icons.local_shipping_rounded, const Color(0xFF8A6AAB), () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => PurchasesPage(swahili: widget.swahili))); refresh();
            }),
            _action(context, t('Ripoti za biashara','Business reports'), t('Angalia historia na takwimu','Review history and figures'), Icons.insert_chart_rounded, const Color(0xFFB1842E), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(swahili: widget.swahili)));
            }),
            const SizedBox(height: 6),
            _sectionTitle(t('Usimamizi','Management'), t('Madeni, matumizi na taarifa nyingine','Debts, expenses and more')),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.18,
              children: [
                _tile(t('Wasambazaji','Suppliers'), Icons.storefront_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuppliersPage(swahili: widget.swahili)))),
                _tile(t('Matumizi','Expenses'), Icons.account_balance_wallet_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesPage(swahili: widget.swahili)))),
                _tile(t('Expiry alerts','Expiry alerts'), Icons.event_busy_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpiryPage(swahili: widget.swahili)))),
                _tile(t('Madeni ya wateja','Customer debts'), Icons.people_alt_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtsPage(swahili: widget.swahili)))),
                _tile(t('Madeni ya suppliers','Supplier balances'), Icons.request_quote_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDebtsPage(swahili: widget.swahili)))),
              ],
            ),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFE7F2F0), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [const Icon(Icons.shield_outlined, color: brandTeal), const SizedBox(width: 10), Expanded(child: Text(t('Taarifa zako zinahifadhiwa kwenye simu hii. Tengeneza backup mara kwa mara.','Your data is stored on this device. Create backups regularly.'), style: const TextStyle(fontSize: 12, color: brandNavy, height: 1.4)))])),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandNavy)),
    const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF758397))),
  ]);

  Widget _stat(String title, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9EEF3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 19)),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: brandNavy))),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF758397), fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _action(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {bool prominent = false}) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: brandNavy, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF7B8794))),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: prominent ? brandTeal : const Color(0xFF9AA6B2)),
    ),
  );

  Widget _tile(String title, IconData icon, VoidCallback onTap) => Card(
    child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: brandTeal.withOpacity(.09), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: brandTeal, size: 20)),
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: brandNavy))), const Icon(Icons.chevron_right, size: 18, color: brandGold)]),
    ]))),
  );
}
