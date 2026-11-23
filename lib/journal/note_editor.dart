import 'package:flutter/material.dart';
import 'journal_store.dart';
import 'journal_theme.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.store, this.note});
  final JournalStore store;
  final JournalNote? note;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  static const _fieldRadius = BorderRadius.all(Radius.circular(14));
  static const _fieldBorder = OutlineInputBorder(
    borderRadius: _fieldRadius,
    borderSide: BorderSide(color: Color(0xFFDDCBB0)),
  );
  static const _focusedBorder = OutlineInputBorder(
    borderRadius: _fieldRadius,
    borderSide: BorderSide(color: journalAccent, width: 1.5),
  );

  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  bool _saving = false, _allowPop = false;
  String? _error;
  bool get _dirty =>
      _title.text != (widget.note?.title ?? '') ||
      _body.text != (widget.note?.body ?? '');
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (!_dirty || await confirmDiscard(context)) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      setState(() => _error = '请填写标题或正文');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.store.saveNote(
        id: widget.note?.id,
        title: _title.text,
        body: _body.text,
      );
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，内容已保留，请重试';
        });
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
  }) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    floatingLabelStyle: const TextStyle(
      color: journalInk,
      fontWeight: FontWeight.w600,
    ),
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFF876F58),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    filled: true,
    fillColor: journalPaper,
    border: _fieldBorder,
    enabledBorder: _fieldBorder,
    disabledBorder: _fieldBorder,
    focusedBorder: _focusedBorder,
  );

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
        title: Text(widget.note == null ? '写一笔' : '编辑笔记'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: Color(0xFF8D5F40),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        journalDate(widget.note?.updated ?? DateTime.now()),
                        style: const TextStyle(
                          color: Color(0xFF8D5F40),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('note-title'),
                  controller: _title,
                  enabled: !_saving,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration(label: '标题', hint: '写个标题'),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('note-body'),
                  controller: _body,
                  enabled: !_saving,
                  minLines: 8,
                  maxLines: null,
                  style: const TextStyle(fontSize: 16, height: 1.9),
                  decoration: _fieldDecoration(label: '正文', hint: '记下日常的小事'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
