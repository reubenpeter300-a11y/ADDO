import 'package:flutter/material.dart';
import 'db.dart';
import 'login_page.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.database;
  runApp(const AddoManagerApp());
}

class AddoManagerApp extends StatefulWidget {
  const AddoManagerApp({super.key});
  @override
  State<AddoManagerApp> createState() => _AddoManagerAppState();
}

class _AddoManagerAppState extends State<AddoManagerApp> {
  bool swahili = true;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ADDO Manager',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandTeal,
        primary: brandTeal,
        secondary: brandGold,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE1E8EF))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE1E8EF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandTeal, width: 1.7)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: brandTeal, foregroundColor: Colors.white,
          minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: brandTeal, minimumSize: const Size(0, 48),
          side: const BorderSide(color: Color(0xFFB9D8D5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
      listTileTheme: const ListTileThemeData(iconColor: brandTeal, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3)),
      dividerTheme: const DividerThemeData(color: Color(0xFFEDF1F5), thickness: 1),
    ),
    home: LoginPage(
      swahili: swahili,
      onLanguageChanged: (v) => setState(() => swahili = v),
    ),
  );
}
