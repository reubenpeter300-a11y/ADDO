import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'db.dart';
import 'home_page.dart';
import 'settings_page.dart';

class LoginPage extends StatefulWidget {
  final bool swahili;
  final ValueChanged<bool> onLanguageChanged;
  const LoginPage({super.key, required this.swahili, required this.onLanguageChanged});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(text: 'admin');
  final password = TextEditingController();
  final pin = TextEditingController();
  bool usePin = false, busy = false, obscure = true;
  String? error;
  String t(String sw, String en) => widget.swahili ? sw : en;

  @override
  void dispose() {
    username.dispose(); password.dispose(); pin.dispose(); super.dispose();
  }

  Future<void> login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final ok = usePin
          ? await AppDb.instance.verifyPin(username.text.trim(), pin.text.trim())
          : await AppDb.instance.verifyPassword(username.text.trim(), password.text);
      if (!mounted) return;
      setState(() => busy = false);
      if (!ok) {
        setState(() => error = t('Taarifa za kuingia si sahihi.','Incorrect login details.'));
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(
        swahili: widget.swahili, onLanguageChanged: widget.onLanguageChanged,
      )));
    } catch (_) {
      if (mounted) setState(() { busy = false; error = t('Imeshindikana kuingia. Jaribu tena.','Unable to sign in. Please try again.'); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [brandNavy, Color(0xFF173F52), Color(0xFFF4F7FA)], stops: [0, .48, .48])),
      child: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Container(width: 82, height: 82, alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(.2))),
              child: const Icon(Icons.local_pharmacy_rounded, color: brandGold, size: 45)),
            const SizedBox(height: 17),
            const Text('ADDO MANAGER', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 25, letterSpacing: 1.5)),
            const SizedBox(height: 5),
            Text(t('MFUMO WA USIMAMIZI WA DUKA LA DAWA','PHARMACY MANAGEMENT SYSTEM'), textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD2E2E8), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            const SizedBox(height: 42),
            Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: brandNavy.withOpacity(.15), blurRadius: 24, offset: const Offset(0, 10))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t('Karibu tena','Welcome back'), style: const TextStyle(color: brandNavy, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(t('Ingia ili kuendelea na biashara yako','Sign in to continue to your business'), style: const TextStyle(color: Color(0xFF7B8794), fontSize: 12)),
                const SizedBox(height: 22),
                TextField(controller: username, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: t('Jina la mtumiaji','Username'), prefixIcon: const Icon(Icons.person_outline_rounded))),
                const SizedBox(height: 13),
                if (!usePin) TextField(controller: password, obscureText: obscure, onSubmitted: (_) => login(), decoration: InputDecoration(
                  labelText: t('Password','Password'), prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => obscure = !obscure))))
                else TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, onSubmitted: (_) => login(), decoration: InputDecoration(labelText: t('PIN ya tarakimu 4','4-digit PIN'), prefixIcon: const Icon(Icons.pin_outlined))),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() { usePin = !usePin; error = null; }), child: Text(usePin ? t('Tumia password','Use password') : t('Tumia PIN','Use PIN')))),
                if (error != null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(10)), child: Text(error!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12))),
                FilledButton(onPressed: busy ? null : login, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(t('INGIA KWENYE MFUMO','SIGN IN'))),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(swahili: widget.swahili))), icon: const Icon(Icons.settings_outlined), label: Text(t('Mipangilio ya akaunti','Account settings'))),
                const SizedBox(height: 5),
                TextButton(onPressed: () => widget.onLanguageChanged(!widget.swahili), child: Text(widget.swahili ? 'Switch to English' : 'Badili lugha: Kiswahili')),
              ]),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.shield_outlined, size: 15, color: brandTeal), const SizedBox(width: 6), Text(t('OFFLINE • Taarifa zinabaki kwenye simu hii','OFFLINE • Your data stays on this device'), style: const TextStyle(fontSize: 10, color: brandNavy, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 9),
            Text(t('Usalama: badilisha taarifa za mwanzo za kuingia kabla ya kutumia mfumo kwenye biashara.','Security: change the initial login credentials before using this system for business.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        )),
      ))),
    ),
  );
}
