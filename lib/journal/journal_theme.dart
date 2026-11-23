import 'package:flutter/material.dart';
import '../animation_gallery.dart';
import 'vault_service.dart';

const journalInk = Color(0xFF57422F);
const journalAccent = Color(0xFFAD6143);
const journalPaper = Color(0xFFFFFCF5);
const journalBackground = Color(0xFFF5EDDF);
String journalDate(DateTime d) =>
    '${d.month}月${d.day}日 · ${const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][d.weekday - 1]}';
String journalTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
ThemeData journalTheme() => ThemeData(
  useMaterial3: true,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: journalAccent,
        brightness: Brightness.light,
      ).copyWith(
        primary: journalAccent,
        surface: journalBackground,
        onSurface: journalInk,
      ),
  scaffoldBackgroundColor: journalBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: journalBackground,
    foregroundColor: journalInk,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: journalInk,
    ),
  ),
  cardTheme: CardThemeData(
    color: journalPaper,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE9DCC7)),
      borderRadius: BorderRadius.circular(14),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFECDFCA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.all(16),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFFF8F1E4),
    indicatorColor: Color(0xFFEADDC9),
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: journalPaper,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    headerBackgroundColor: const Color(0xFFF0E6D5),
    headerForegroundColor: journalInk,
    headerHeadlineStyle: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w600,
    ),
    headerHelpStyle: const TextStyle(fontSize: 13, letterSpacing: 1),
    weekdayStyle: const TextStyle(color: Color(0xFF9A866D), fontSize: 13),
    dayStyle: const TextStyle(fontSize: 15),
    dayForegroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? Colors.white : journalInk,
    ),
    dayBackgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? journalAccent
          : Colors.transparent,
    ),
    todayForegroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? Colors.white : journalAccent,
    ),
    todayBorder: const BorderSide(color: journalAccent),
    dividerColor: const Color(0xFFE9DCC7),
    cancelButtonStyle: TextButton.styleFrom(
      foregroundColor: const Color(0xFF917D67),
    ),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: journalAccent,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);

void openTools(BuildContext context) {
  VaultService.instance.lock();
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ToolsPage()));
}

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('小工具')),
    body: const AnimationGallery(),
  );
}

Widget toolAction(BuildContext context) => TextButton.icon(
  onPressed: () => openTools(context),
  icon: const Icon(Icons.grid_view_outlined, size: 18),
  label: const Text('小工具'),
);

class DayBanner extends StatelessWidget {
  const DayBanner({
    super.key,
    required this.date,
    this.caption = '把平常的日子，慢慢记下来。',
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 20),
    this.compact = false,
  });
  final DateTime date;
  final String caption;
  final EdgeInsetsGeometry padding;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 48,
            height: compact ? 1 : null,
            color: Color(0xFF976748),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.year}年${date.month}月 · ${journalDate(date).split(' · ').last}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A866D)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DateStamp extends StatelessWidget {
  const DateStamp({super.key, required this.date, this.trailing});
  final DateTime date;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(color: Color(0xFFE5D6BE), height: 26),
      Row(
        children: [
          Expanded(
            child: Text(
              journalDate(date),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8D5F40),
              ),
            ),
          ),
          Text(
            journalTime(date),
            style: const TextStyle(fontSize: 12, color: Color(0xFFAA9274)),
          ),
          ?trailing,
        ],
      ),
    ],
  );
}

Future<bool> confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('有未保存的修改'),
        content: const Text('放弃修改并返回？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    ) ??
    false;
