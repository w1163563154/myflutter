import 'package:flutter/material.dart';

import 'record.dart';
import 'record_repository.dart';
import 'record_calendar.dart';
import '../journal/journal_theme.dart';

class RecordForm extends StatefulWidget {
  const RecordForm({
    super.key,
    required this.date,
    required this.repository,
    this.record,
  });
  final DateTime date;
  final RecordRepository repository;
  final LocalRecord? record;

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.record?.name ?? '');
  late final _phone = TextEditingController(text: widget.record?.phone ?? '');
  late final _number = TextEditingController(text: widget.record?.number ?? '');
  late final _note = TextEditingController(text: widget.record?.note ?? '');
  late DateTime _date = widget.record?.date ?? widget.date;
  bool _saving = false;
  bool _failed = false;
  bool _allowPop = false;
  bool get _dirty =>
      _name.text != (widget.record?.name ?? '') ||
      _phone.text != (widget.record?.phone ?? '') ||
      _number.text != (widget.record?.number ?? '') ||
      _note.text != (widget.record?.note ?? '') ||
      dateKey(_date) != dateKey(widget.record?.date ?? widget.date);
  Future<void> _back() async {
    if (_saving) return;
    if (!_dirty || await confirmDiscard(context)) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _number, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showRecordCalendar(
      context,
      initialDate: _date,
      loadDates: widget.repository.datesInMonth,
      helpText: '选择取件日期',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failed = false;
    });
    final record = LocalRecord(
      id: widget.record?.id,
      createdAt: widget.record?.createdAt,
      date: _date,
      name: recordValue(_name.text),
      phone: recordValue(_phone.text),
      number: recordValue(_number.text),
      note: recordValue(_note.text),
    );
    try {
      final int id;
      if (widget.record == null) {
        id = await widget.repository.add(record);
      } else {
        await widget.repository.update(record);
        id = record.id!;
      }
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop(id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(widget.record == null ? '添加快递' : '修改快递'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('日期：${journalDate(_date)}'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('record-name'),
                    controller: _name,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '名字',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('record-phone'),
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '电话',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('record-number'),
                    controller: _number,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '编号',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('record-note'),
                    controller: _note,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 16),
                    Text(
                      '保存失败，请重试',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? '保存中…' : '保存'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _saving ? null : _back,
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
