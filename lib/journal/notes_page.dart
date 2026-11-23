import 'dart:async';
import 'package:flutter/material.dart';
import 'journal_store.dart';
import 'journal_theme.dart';
import 'note_editor.dart';
import 'vault_page.dart';
import 'vault_service.dart';
import '../data/data_entry.dart';
import '../records/record_motion.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    required this.store,
    required this.vault,
    this.active = true,
  });
  final JournalStore store;
  final VaultService vault;
  final bool active;
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with TickerProviderStateMixin {
  final _search = TextEditingController();
  final _pinWrites = <int>{};
  final _viewport = RecordMotionViewport();
  late final AnimationController _reorder;
  late final AnimationController _highlight;
  Map<int, double> _moves = {};
  int? _highlightedId;
  int _filterRevision = 0;
  List<JournalNote> _notes = [];
  bool _busy = true, _failed = false, _vault = false;
  int _generation = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _reorder = AnimationController(
      vsync: this,
      duration: recordReorderDuration,
    );
    _highlight = AnimationController(
      vsync: this,
      duration: recordHighlightDuration,
    );
    _load();
    dataRevision.addListener(_restored);
  }

  bool get _canAnimate =>
      widget.active &&
      !_vault &&
      ModalRoute.isCurrentOf(context) != false &&
      !RecordMotionPreference.reduceMotionOf(context);

  @override
  void didUpdateWidget(covariant NotesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) _invalidateMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_canAnimate) _resetMotion();
  }

  void _invalidateMotion() {
    _filterRevision++;
    _resetMotion();
  }

  void _resetMotion() {
    _reorder.stop();
    _highlight.stop();
    _moves = {};
    _highlightedId = null;
  }

  void _restored() {
    if (mounted) {
      _invalidateMotion();
      setState(() => _vault = false);
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _reorder.dispose();
    _highlight.dispose();
    dataRevision.removeListener(_restored);
    super.dispose();
  }

  Future<void> _load({
    bool showProgress = true,
    int? pinId,
    int? savedId,
    int? filterRevision,
  }) async {
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
        final animate =
            filterRevision != null &&
            filterRevision == _filterRevision &&
            _canAnimate;
        final moves = animate && pinId != null
            ? _pinMoves(notes, pinId)
            : <int, double>{};
        _resetMotion();
        _viewport.retainRows(notes.map((n) => n.id).toSet());
        setState(() {
          _notes = notes;
          _moves = moves;
          _busy = false;
          _failed = false;
        });
        if (moves.isNotEmpty) _reorder.forward(from: 0);
        if (animate && savedId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                generation != _generation ||
                filterRevision != _filterRevision ||
                !_canAnimate ||
                !_viewport.isVisible(savedId)) {
              return;
            }
            setState(() => _highlightedId = savedId);
            _highlight.forward(from: 0);
          });
        }
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

  Map<int, double> _pinMoves(List<JournalNote> next, int targetId) {
    final bounds = _viewport.bounds;
    final target = _viewport.rowBounds(targetId);
    if (bounds == null || target == null || !bounds.overlaps(target)) return {};
    final before = _notes.map((n) => n.id).toList();
    final after = next.map((n) => n.id).toList();
    if (before.length != after.length || !before.toSet().containsAll(after)) {
      return {};
    }
    final positions = {for (var i = 0; i < after.length; i++) after[i]: i};
    final moves = <int, double>{};
    for (var i = 0; i < before.length; i++) {
      final id = before[i];
      final row = _viewport.rowBounds(id);
      if (row == null || !bounds.overlaps(row) || positions[id] == i) continue;
      var shift = 0.0;
      var measured = true;
      for (var j = 0; j < before.length; j++) {
        final other = before[j];
        if (i == j || (j < i) == (positions[other]! < positions[id]!)) continue;
        final height = _viewport.rowBounds(other)?.height;
        if (height == null) {
          measured = false;
          break;
        }
        shift += j < i ? height : -height;
      }
      if (measured &&
          shift != 0 &&
          bounds.overlaps(row.shift(Offset(0, -shift)))) {
        moves[id] = shift;
      }
    }
    return moves.containsKey(targetId) ? moves : {};
  }

  Future<void> _togglePin(JournalNote note) async {
    if (!_pinWrites.add(note.id)) return;
    final filter = _filterRevision;
    setState(() {});
    try {
      await widget.store.setPinned(note.id, !note.pinned);
      if (mounted) {
        await _load(
          showProgress: false,
          pinId: note.id,
          filterRevision: filter,
        );
      }
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
    setState(_invalidateMotion);
    final filter = _filterRevision;
    final route = MaterialPageRoute<int>(
      builder: (_) => NoteEditor(store: widget.store, note: note),
    );
    final id = await Navigator.push(context, route);
    await route.completed;
    if (id != null && mounted) {
      await _load(showProgress: false, savedId: id, filterRevision: filter);
    }
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
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: journalSelection,
                    selectedForegroundColor: journalInk,
                  ),
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
                  onSelectionChanged: (v) => setState(() {
                    if (_vault != v.first) _invalidateMotion();
                    _vault = v.first;
                  }),
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
                              setState(_invalidateMotion);
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
                                        _invalidateMotion();
                                        _debounce?.cancel();
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
    final indices = {for (var i = 0; i < _notes.length; i++) _notes[i].id: i};
    final animate = _canAnimate;
    final list = ListView.builder(
      key: const PageStorageKey('notes'),
      findChildIndexCallback: (key) => _viewport.indexFor(key, indices),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _notes.length,
      itemBuilder: (context, i) {
        final n = _notes[i];
        Widget card(Color? color) => Card(
          color: color,
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
        final Widget content = animate && _highlightedId == n.id
            ? AnimatedBuilder(
                animation: _highlight,
                builder: (_, _) => card(
                  Color.lerp(
                    journalSelection,
                    journalPaper,
                    Curves.easeOutCubic.transform(_highlight.value),
                  ),
                ),
              )
            : card(null);
        final shift = animate ? _moves[n.id] : null;
        return KeyedSubtree(
          key: _viewport.rowKey(n.id),
          child: shift == null
              ? content
              : AnimatedBuilder(
                  animation: _reorder,
                  child: content,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      shift *
                          (1 - Curves.easeOutCubic.transform(_reorder.value)),
                    ),
                    child: child,
                  ),
                ),
        );
      },
    );
    return KeyedSubtree(key: _viewport.key, child: list);
  }
}
