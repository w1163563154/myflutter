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
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  journalDate(widget.note?.updated ?? DateTime.now()),
                  style: const TextStyle(
                    color: Color(0xFF8D5F40),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('note-title'),
                  controller: _title,
                  enabled: !_saving,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '写个标题',
                    fillColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('note-body'),
                  controller: _body,
                  enabled: !_saving,
                  minLines: 12,
                  maxLines: null,
                  style: const TextStyle(fontSize: 16, height: 1.9),
                  decoration: const InputDecoration(
                    hintText: '记下日常的小事',
                    fillColor: Colors.transparent,
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
