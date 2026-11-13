import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';

class SettingsPage extends StatefulWidget {
  final bool swahili;
  const SettingsPage({super.key, required this.swahili});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final current = TextEditingController();
  final newUser = TextEditingController(text: 'admin');
  final newPassword = TextEditingController();
  final newPin = TextEditingController();
  bool obscure = true;
  String? message;
  String t(String sw, String en) => widget.swahili ? sw : en;

  Future<void> backupDatabase() async {
    try {
      await AppDb.instance.checkpointForBackup();
      final dbPath = p.join(await getDatabasesPath(), 'addo_manager.db');
      final source = File(dbPath);
      if (!await source.exists()) throw Exception('Database haijapatikana');
      final temp = Directory.systemTemp;
      final copy = await source.copy(p.join(temp.path, 'ADDO_Manager_backup_${DateTime.now().millisecondsSinceEpoch}.db'));
      await Share.shareXFiles([XFile(copy.path)], text: t('Hifadhi nakala ya ADDO Manager. Iweke sehemu salama.', 'ADDO Manager database backup. Store it securely.'));
    } catch (e) {
      if (mounted) setState(() => message = '${t('Imeshindikana','Failed')}: $e');
    }
  }

  Future<void> restoreDatabase() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(t('Rejesha nakala?','Restore backup?')),
      content: Text(t('Hii itabadilisha data yote ya sasa kwa nakala uliyochagua. Hakikisha una backup ya sasa kwanza.', 'This replaces all current data with the selected backup. Make a backup of current data first.')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Ghairi','Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Endelea','Continue')))],
    ));
    if (confirm != true) return;
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['db'], withData: false);
      if (picked == null || picked.files.single.path == null) return;
      final selected = File(picked.files.single.path!);
      if (await selected.length() < 100) throw Exception('Faili ya backup si sahihi');
      // Validate SQLite integrity and required application tables before replacing live data.
      final probe = await openDatabase(selected.path, readOnly: true);
      try {
        final integrity = await probe.rawQuery('PRAGMA integrity_check');
        if (integrity.isEmpty || integrity.first.values.first.toString().toLowerCase() != 'ok') {
          throw Exception('Database integrity check imeshindwa');
        }
        final required = await probe.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final names = required.map((r) => r['name'].toString()).toSet();
        if (!names.containsAll({'medicines','sales','app_users'})) throw Exception('Hii si backup ya ADDO Manager');
      } finally { await probe.close(); }
      final dbPath = p.join(await getDatabasesPath(), 'addo_manager.db');
      final live = File(dbPath);
      final rollback = File('$dbPath.restore_previous');
      if (await live.exists()) await live.copy(rollback.path);
      await AppDb.instance.closeForRestore();
      try {
        await selected.copy(dbPath);
        if (await rollback.exists()) await rollback.delete();
      } catch (_) {
        if (await rollback.exists()) await rollback.copy(dbPath);
        rethrow;
      }
      if (!mounted) return;
      setState(() => message = t('Nakala imerejeshwa. Funga na fungua app upya.', 'Backup restored. Close and reopen the app.'));
    } catch (e) {
      if (mounted) setState(() => message = '${t('Imeshindikana','Failed')}: $e');
    }
  }

  Future<void> save() async {
    final valid = await AppDb.instance.verifyAdminPassword(current.text);
    if (!valid) { setState(() => message = t('Password ya sasa si sahihi.','Current password is incorrect.')); return; }
    if (newPassword.text.isNotEmpty && newPassword.text.length < 8) {
      setState(() => message = t('Password iwe na angalau herufi 8.','Password must be at least 8 characters.')); return;
    }
    if (newPin.text.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(newPin.text)) {
      setState(() => message = t('PIN lazima iwe tarakimu 4.','PIN must be exactly 4 digits.')); return;
    }
    await AppDb.instance.changeCredentials(
      username: newUser.text.trim().isEmpty ? 'admin' : newUser.text.trim(),
      newPassword: newPassword.text.isEmpty ? null : newPassword.text,
      newPin: newPin.text.isEmpty ? null : newPin.text,
    );
    if (!mounted) return;
    setState(() => message = t('Mabadiliko yamehifadhiwa. Tumia taarifa mpya kuingia.','Changes saved. Use the new credentials to log in.'));
    current.clear(); newPassword.clear(); newPin.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Usalama wa Admin','Admin security'))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(t('Badilisha taarifa za kuingia','Change login credentials'),
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      TextField(controller: current, obscureText: true,
        decoration: InputDecoration(labelText: t('Password ya sasa','Current password'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: newUser,
        decoration: InputDecoration(labelText: t('Username mpya','New username'), border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: newPassword, obscureText: obscure,
        decoration: InputDecoration(labelText: t('Password mpya (hiari)','New password (optional)'), border: const OutlineInputBorder(),
          helperText: t('Angalau herufi 8','At least 8 characters'))),
      const SizedBox(height: 12),
      TextField(controller: newPin, obscureText: true, maxLength: 4, keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: t('PIN mpya ya tarakimu 4 (hiari)','New 4-digit PIN (optional)'), border: const OutlineInputBorder())),
      if (message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(message!, style: const TextStyle(color: Colors.green))),
      FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: Text(t('Hifadhi mabadiliko','Save changes'))),
      const Divider(height: 32),
      Text(t('Backup na urejeshaji wa data','Data backup and restore'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: backupDatabase, icon: const Icon(Icons.backup), label: Text(t('Tengeneza backup','Create backup'))),
      OutlinedButton.icon(onPressed: restoreDatabase, icon: const Icon(Icons.restore), label: Text(t('Rejesha backup (.db)','Restore backup (.db)'))),
      const SizedBox(height: 8),
      Text(t('Hifadhi backup nje ya simu (mfano flash/cloud salama). Urejeshaji hubadilisha database yote; funga na fungua app upya baada ya kurejesha.', 'Store backups outside the phone (for example, secure cloud/USB). Restore replaces the whole database; restart the app after restoring.'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 12),
      const Text('Usalama: Password na PIN huhifadhiwa kama hash kwenye database ya ndani. Huu ni mwanzo wa usalama; bado ongeza device encryption na backup salama kabla ya matumizi ya biashara.',
        style: TextStyle(fontSize: 12, color: Colors.black54)),
    ]),
  );
}
