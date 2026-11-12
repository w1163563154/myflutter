import 'package:flutter/material.dart';
import 'home_shell.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '灵感动画集',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7155D9)),
      scaffoldBackgroundColor: const Color(0xFFF8F7FC),
      useMaterial3: true,
    ),
    home: const HomeShell(),
  );
}
