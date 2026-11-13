import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db.dart';

class SalePage extends StatefulWidget {
  final bool swahili;
  const SalePage({super.key, required this.swahili});
  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  List<Map<String, Object?>> medicines = [];
  final List<Map<String, Object?>> cart = [];
  int? selected;
  final qty = TextEditingController(text: '1');
  final customer = TextEditingController();
  String payment = 'Cash';
  bool saving = false;
  String t(String sw, String en) => widget.swahili ? sw : en;
  final money = NumberFormat('#,##0.00');
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { final x = await AppDb.instance.medicines(); if (mounted) setState(() => medicines = x); }

  void addToCart() {
    final m = medicines.where((x) => x['id'] == selected).firstOrNull;
    final count = int.tryParse(qty.text) ?? 0;
    if (m == null || count <= 0) return;
    final existing = cart.indexWhere((x) => x['medicine_id'] == m['id']);
    final already = existing < 0 ? 0 : cart[existing]['quantity'] as int;
    if (already + count > (m['quantity'] as int)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Stock haitoshi.','Insufficient stock.'))));
      return;
    }
    setState(() {
      if (existing >= 0) cart[existing]['quantity'] = already + count;
      else cart.add({'medicine_id':m['id'],'name':m['name'],'quantity':count,
        'unit_price':(m['selling_price'] as num).toDouble(),
        'unit_cost':(m['cost_price'] as num).toDouble()});
      qty.text = '1';
    });
  }

  Future<void> completeSale() async {
    if (cart.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final receipt = await AppDb.instance.recordSaleCart(
        items: cart.map((e) => Map<String,Object?>.from(e)).toList(),
        paymentMethod: payment, customerName: customer.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t('Mauzo yamehifadhiwa. Risiti','Sale saved. Receipt')}: $receipt')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final total = cart.fold<double>(0,(sum,item)=>sum+(item['quantity'] as int)*(item['unit_price'] as double));
    return Scaffold(
      appBar: AppBar(title: Text(t('Mauzo mapya','New sale'))),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(t('Ongeza bidhaa kwenye kikapu','Add items to cart'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(value:selected,isExpanded:true,
            decoration: InputDecoration(labelText:t('Chagua dawa','Select medicine')),
            items:medicines.map((x)=>DropdownMenuItem<int>(value:x['id'] as int,child:Text('${x['name']} • ${x['quantity']} ${t('zilizopo','available')}'))).toList(),
            onChanged:(v)=>setState(()=>selected=v)),
          const SizedBox(height:10),
          Row(children:[Expanded(child:TextField(controller:qty,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Idadi','Quantity')))),const SizedBox(width:10),FilledButton.icon(onPressed:addToCart,icon:const Icon(Icons.add_shopping_cart),label:Text(t('Ongeza','Add')))]),
          const SizedBox(height:20),
          Row(children:[Expanded(child:Text(t('Kikapu cha mauzo','Sales cart'),style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800))),Text('${cart.length} ${t('bidhaa','items')}')]),
          const SizedBox(height:8),
          if(cart.isEmpty) Card(child:Padding(padding:const EdgeInsets.all(24),child:Center(child:Text(t('Bado hujaongeza dawa.','No medicines added yet.'))))),
          ...cart.asMap().entries.map((entry){final i=entry.key;final item=entry.value;return Card(child:ListTile(
            title:Text('${item['name']} × ${item['quantity']}'),
            subtitle:Text('TSh ${money.format(item['unit_price'])} ${t('kwa moja','each')}'),
            trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('TSh ${money.format((item['quantity'] as int)*(item['unit_price'] as double))}',style:const TextStyle(fontWeight:FontWeight.w700)),IconButton(onPressed:()=>setState(()=>cart.removeAt(i)),icon:const Icon(Icons.delete_outline,color:Colors.red))]),
          ));}),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:payment,decoration:InputDecoration(labelText:t('Njia ya malipo','Payment method')),
            items:const ['Cash','Mobile Money','Card','Credit'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>payment=v??'Cash')),
          if(payment=='Credit')...[
            const SizedBox(height:10),TextField(controller:customer,decoration:InputDecoration(labelText:t('Jina la mteja wa mkopo','Credit customer name'))),
          ],
        ])),
        Container(padding:const EdgeInsets.fromLTRB(16,12,16,20),decoration:const BoxDecoration(color:Colors.white,boxShadow:[BoxShadow(color:Color(0x14000000),blurRadius:12)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(t('JUMLA YA RISITI','RECEIPT TOTAL'),style:const TextStyle(fontWeight:FontWeight.w800)),Text('TSh ${money.format(total)}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:Color(0xFF087E78)))]),
            const SizedBox(height:10),FilledButton.icon(onPressed:cart.isEmpty||saving?null:completeSale,icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.check_circle_outline),label:Text(t('Thibitisha mauzo yote','Complete full sale'))),
          ])),
      ]),
    );
  }
}
