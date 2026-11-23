import 'dart:async';

import 'package:flutter/material.dart';

import 'record.dart';
import 'record_form.dart';
import 'record_calendar.dart';
import 'swipe_record.dart';
import 'record_repository.dart';
import '../journal/journal_theme.dart';
import '../data/data_entry.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, this.repository});
  final RecordRepository? repository;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late final RecordRepository _repository =
      widget.repository ?? SqliteRecordRepository.instance;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<LocalRecord> _records = [];
  bool _loading = true;
  bool _failed = false;
  Timer? _debounce;
  int _generation = 0;
  int _total = 0;
  bool _moreBusy = false, _moreFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
    dataRevision.addListener(_restored);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200) _loadMore();
    });
  }

  void _restored() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    dataRevision.removeListener(_restored);
    super.dispose();
  }

  Future<void> _load() async {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _moreBusy = false;
      _moreFailed = false;
    });
    try {
      final keyword = _search.text;
      final records = await _repository.query(
        _date,
        keyword: keyword,
        limit: 15,
      );
      final total = await _repository.count(_date, keyword: keyword);
      if (!mounted || generation != _generation) return;
      setState(() {
        _records = records;
        _total = total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _moreBusy || _moreFailed || _records.length >= _total) {
      return;
    }
    final generation = _generation;
    setState(() {
      _moreBusy = true;
    });
    try {
      final next = await _repository.query(
        _date,
        keyword: _search.text,
        limit: 15,
        offset: _records.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _records.addAll(next);
        _moreBusy = false;
        if (next.isEmpty) _total = _records.length;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _moreBusy = false;
        _moreFailed = true;
      });
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    // Invalidate in-flight results immediately, including the debounce window.
    _generation++;
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _chooseDate() async {
    final date = await showRecordCalendar(
      context,
      initialDate: _date,
      loadDates: _repository.datesInMonth,
    );
    if (date != null && mounted) {
      setState(() => _date = date);
      _load();
    }
  }

  Future<void> _add([LocalRecord? existing]) async {
    final record = await Navigator.of(context).push<LocalRecord>(
      MaterialPageRoute(
        builder: (_) =>
            RecordForm(date: _date, repository: _repository, record: existing),
      ),
    );
    if (record == null || !mounted) return;
    setState(() {
      _date = record.date;
      _search.clear();
    });
    _load();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _delete(LocalRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条快递记录？'),
        content: Text(
          '${journalDate(record.date)}\n姓名：${record.name}\n编号：${record.number}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCF4440),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    try {
      await _repository.delete(record.id!);
      if (mounted) _deleted(record);
      return false;
    } catch (_) {
      _message('删除失败，请重试');
      return false;
    }
  }

  void _deleted(LocalRecord record) {
    setState(() => _records.removeWhere((r) => r.id == record.id));
    _load();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('记录已删除'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => _restore(record),
          ),
        ),
      );
  }

  Future<void> _restore(LocalRecord record) async {
    try {
      await _repository.add(record);
      if (mounted) _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('恢复失败'),
          action: SnackBarAction(
            label: '重试恢复',
            onPressed: () => _restore(record),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 48,
      title: const Text('快递记录'),
      actions: [dataAction(context), toolAction(context)],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _add(),
      icon: const Icon(Icons.add),
      label: const Text('添加'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: '选择日期',
                      child: OutlinedButton.icon(
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          '${dateKey(_date)} · ${journalDate(_date).split(' · ').last}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(
                        () => _date = DateUtils.dateOnly(DateTime.now()),
                      );
                      _load();
                    },
                    child: const Text('今天'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                key: const Key('record-search'),
                controller: _search,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: '搜索所有记录：姓名、电话、编号、备注',
                  helperText: _search.text.trim().isEmpty
                      ? '显示所选日期，输入关键词搜索所有记录'
                      : '正在搜索所有日期的记录',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(child: _content()),
          ],
        ),
      ),
    ),
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败，请重试'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(_search.text.trim().isEmpty ? '当天暂无记录' : '未找到匹配记录'),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('records-list'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _records.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('共 $_total 条记录 · 已加载 ${_records.length} 条'),
          );
        }
        if (index == _records.length + 1) {
          if (_moreBusy) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_moreFailed) {
            return TextButton(
              onPressed: () {
                setState(() => _moreFailed = false);
                _loadMore();
              },
              child: const Text('加载失败，点击重试'),
            );
          }
          if (_records.length < _total) {
            return TextButton(
              onPressed: _loadMore,
              child: const Text('加载更多（15条）'),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('已加载全部记录')),
          );
        }
        final record = _records[index - 1];
        String shown(String text) => text.isEmpty ? '未填写' : text;
        final card = Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _add(record),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '日期：${journalDate(record.date)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8D5F40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text('姓名：${shown(record.name)}')),
                      const SizedBox(width: 12),
                      Expanded(child: Text('电话：${shown(record.phone)}')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('编号：${shown(record.number)}'),
                  const SizedBox(height: 4),
                  Text('备注：${shown(record.note)}'),
                ],
              ),
            ),
          ),
        );
        if (record.id == null) return card;
        return SwipeRecord(
          key: ValueKey('courier-${record.id}'),
          recordId: record.id!,
          onDelete: () async {
            await _delete(record);
          },
          child: card,
        );
      },
    );
  }
}
