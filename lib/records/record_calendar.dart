import 'package:flutter/material.dart';
import '../journal/journal_theme.dart';
import 'record.dart';

Future<DateTime?> showRecordCalendar(
  BuildContext context, {
  required DateTime initialDate,
  required Future<Set<String>> Function(DateTime month) loadDates,
  String helpText = '查看哪一天的记录',
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => RecordCalendar(
    initialDate: initialDate,
    loadDates: loadDates,
    helpText: helpText,
  ),
);

class RecordCalendar extends StatefulWidget {
  const RecordCalendar({
    super.key,
    required this.initialDate,
    required this.loadDates,
    this.helpText = '查看哪一天的记录',
  });
  final DateTime initialDate;
  final Future<Set<String>> Function(DateTime month) loadDates;
  final String helpText;
  @override
  State<RecordCalendar> createState() => _RecordCalendarState();
}

class _RecordCalendarState extends State<RecordCalendar> {
  late DateTime _selected = DateUtils.dateOnly(widget.initialDate);
  late DateTime _month = DateTime(_selected.year, _selected.month);
  late final _input = TextEditingController(text: dateKey(_selected));
  Set<String> _dates = {};
  bool _loading = false, _failed = false, _typing = false;
  String? _inputError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _dates = {};
    });
    try {
      final dates = await widget.loadDates(_month);
      if (!mounted || request != _generation) return;
      setState(() {
        _dates = dates;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _changeMonth(int offset) {
    final month = DateTime(_month.year, _month.month + offset);
    if (month.year < 1900 || month.year > 2100) return;
    setState(() => _month = month);
    _load();
  }

  DateTime? _typedDate() {
    final match = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$',
    ).firstMatch(_input.text.trim());
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    if (year < 1900 ||
        year > 2100 ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      return null;
    }
    return date;
  }

  void _confirm() {
    final date = _typing ? _typedDate() : _selected;
    if (date == null) {
      setState(() => _inputError = '请输入1900–2100年的有效日期');
      return;
    }
    Navigator.pop(context, date);
  }

  Widget _day(int day) {
    final date = DateTime(_month.year, _month.month, day);
    final key = dateKey(date);
    final selected = DateUtils.isSameDay(date, _selected);
    final today = DateUtils.isSameDay(date, DateTime.now());
    final recorded = _dates.contains(key);
    return Semantics(
      label: '${date.year}年${journalDate(date)}${recorded ? '，有记录' : ''}',
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('calendar-day-$key'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selected = date;
            _input.text = key;
          }),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? journalAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: today && !selected
                      ? Border.all(color: journalAccent)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? Colors.white : journalInk,
                    fontWeight: selected || today
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                width: 5,
                child: recorded
                    ? DecoratedBox(
                        key: ValueKey('record-dot-$key'),
                        decoration: const BoxDecoration(
                          color: journalAccent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final start = _month.weekday % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final slots = ((start + days + 6) ~/ 7) * 7;
    return Column(
      children: [
        Row(
          children: [
            for (final weekday in ['日', '一', '二', '三', '四', '五', '六'])
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      weekday,
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A866D)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < slots ~/ 7; week++)
          SizedBox(
            height: 48,
            child: Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child:
                        week * 7 + weekday < start ||
                            week * 7 + weekday >= start + days
                        ? const SizedBox.shrink()
                        : _day(week * 7 + weekday - start + 1),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: journalPaper,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: const Color(0xFFF0E6D5),
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.helpText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF917D67),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          journalDate(_selected),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: journalInk,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _typing ? '选择日历' : '输入日期',
                        onPressed: () => setState(() {
                          _typing = !_typing;
                          _inputError = null;
                        }),
                        icon: Icon(
                          _typing
                              ? Icons.calendar_month_outlined
                              : Icons.edit_calendar_outlined,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  if (_typing)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 16,
                      ),
                      child: TextField(
                        key: const Key('calendar-input'),
                        controller: _input,
                        keyboardType: TextInputType.datetime,
                        onSubmitted: (_) => _confirm(),
                        decoration: InputDecoration(
                          labelText: '日期',
                          hintText: 'YYYY-MM-DD',
                          errorText: _inputError,
                        ),
                      ),
                    ),
                  if (!_typing) ...[
                    Row(
                      children: [
                        IconButton(
                          tooltip: '上个月',
                          onPressed: _month.year == 1900 && _month.month == 1
                              ? null
                              : () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_month.year}年${_month.month}月',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '下个月',
                          onPressed: _month.year == 2100 && _month.month == 12
                              ? null
                              : () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    _grid(),
                    SizedBox(
                      height: 36,
                      child: _loading
                          ? const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              ),
                            )
                          : _failed
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '标记加载失败',
                                  style: TextStyle(fontSize: 12),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('重试'),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: journalAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 5, height: 5),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '当天有记录',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF917D67),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          final today = DateUtils.dateOnly(DateTime.now());
                          setState(() {
                            _selected = today;
                            _month = DateTime(today.year, today.month);
                            _input.text = dateKey(today);
                            _typing = false;
                          });
                          _load();
                        },
                        child: const Text('今天'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: _confirm,
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
