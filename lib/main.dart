import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_shell.dart';
import 'solar_system_page.dart';
import 'records/records_page.dart';
import 'journal/journal_theme.dart';
import 'journal/vault_guard.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '日常手账',
    debugShowCheckedModeBanner: false,
    theme: journalTheme(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => VaultGuard(child: child!),
    home: const bool.fromEnvironment('SOLAR_SYSTEM')
        ? const SolarSystemPage()
        : const bool.fromEnvironment('RECORDS')
        ? const RecordsPage()
        : const HomeShell(),
  );
}
