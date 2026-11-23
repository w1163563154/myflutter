import 'dart:async';
import 'package:flutter/material.dart';
import 'journal_store.dart';
import 'journal_theme.dart';
import 'note_editor.dart';
import 'vault_page.dart';
import 'vault_service.dart';
import '../data/data_entry.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.store, required this.vault});
  final JournalStore store;
  final VaultService vault;
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _search = TextEditingController();
  final _pinWrites = <int>{};
  List<JournalNote> _notes = [];
  bool _busy = true, _failed = false, _vault = false;
  int _generation = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _load();
    dataRevision.addListener(_restored);
  }

  void _restored() {
    if (mounted) {
      setState(() => _vault = false);
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    dataRevision.removeListener(_restored);
    super.dispose();
  }

  Future<void> _load({bool showProgress = true}) async {
    final generation = ++_generation;
    if (showProgress) {
      setState(() {
        _busy = true;
        _failed = false;
      });
    }
    try {
      final notes = await widget.store.notes(_search.text);
      if (mounted && generation == _generation) {
        setState(() {
          _notes = notes;
          _busy = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  Future<void> _togglePin(JournalNote note) async {
    if (!_pinWrites.add(note.id)) return;
    setState(() {});
    try {
      await widget.store.setPinned(note.id, !note.pinned);
      if (mounted) await _load(showProgress: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(note.pinned ? '取消置顶失败，请重试' : '置顶失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _pinWrites.remove(note.id));
    }
  }

  Future<void> _edit([JournalNote? note]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditor(store: widget.store, note: note),
      ),
    );
    if (saved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('随手记'),
      actions: [
        dataAction(context, journal: widget.store, vault: widget.vault),
        toolAction(context),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('笔记'),
                      icon: Icon(Icons.edit_note),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('密码库'),
                      icon: Icon(Icons.lock_outline),
                    ),
                  ],
                  selected: {_vault},
                  onSelectionChanged: (v) => setState(() => _vault = v.first),
                ),
              ),
            ),
            Expanded(
              child: _vault
                  ? VaultPage(service: widget.vault)
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: TextField(
                            key: const Key('note-search'),
                            controller: _search,
                            onChanged: (_) {
                              _generation++;
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 250),
                                _load,
                              );
                            },
                            decoration: InputDecoration(
                              hintText: '搜索标题或正文',
                              prefixIcon: const Icon(Icons.search),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '最近记录 · 随时拾起',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9A866D),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _edit(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('写一笔'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _content()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _content() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败，请重试'),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _search.text.trim().isEmpty ? '还没有笔记，记下第一件小事吧' : '未找到匹配笔记',
            style: const TextStyle(color: Color(0xFF9A866D)),
          ),
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('notes'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _notes.length,
      itemBuilder: (context, i) {
        final n = _notes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _edit(n),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DateStamp(
                    date: n.updated,
                    trailing: IconButton(
                      tooltip: n.pinned ? '取消置顶' : '置顶',
                      isSelected: n.pinned,
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.standard,
                      ),
                      icon: const Icon(
                        Icons.push_pin_outlined,
                        color: Color(0xFF917D67),
                      ),
                      selectedIcon: const Icon(
                        Icons.push_pin,
                        color: journalAccent,
                      ),
                      onPressed: _pinWrites.contains(n.id)
                          ? null
                          : () => _togglePin(n),
                    ),
                  ),
                  Text(
                    n.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF917D67)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
