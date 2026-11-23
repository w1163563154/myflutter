import 'package:flutter/material.dart';

const recordReorderDuration = Duration(milliseconds: 200);
const recordVisibilityDuration = Duration(milliseconds: 180);
const recordHighlightDuration = Duration(milliseconds: 300);

/// Tracks laid-out rows in a lazy list so changes never have to scroll to a row.
class RecordMotionViewport {
  final key = GlobalKey();
  final _rows = <int, GlobalKey>{};

  GlobalKey rowKey(int id) => _rows.putIfAbsent(id, GlobalKey.new);

  void retainRows(Set<int> ids) {
    _rows.removeWhere((id, _) => !ids.contains(id));
  }

  int? indexFor(Key key, Map<int, int> indices) {
    for (final entry in _rows.entries) {
      if (entry.value == key) return indices[entry.key];
    }
    return null;
  }

  Rect? get bounds {
    final box = _box(key);
    return box == null ? null : Offset.zero & box.size;
  }

  Rect? rowBounds(int id) {
    final viewport = _box(key);
    final row = _box(_rows[id]);
    if (viewport == null || row == null) return null;
    return row.localToGlobal(Offset.zero, ancestor: viewport) & row.size;
  }

  bool isVisible(int id, {bool allowCollapsed = false}) {
    final view = bounds;
    final row = rowBounds(id);
    if (view == null || row == null) return false;
    if (allowCollapsed && row.height == 0) {
      return row.top >= view.top && row.top < view.bottom;
    }
    return view.overlaps(row);
  }

  RenderBox? _box(GlobalKey? key) {
    final render = key?.currentContext?.findRenderObject();
    if (render is RenderBox && render.attached && render.hasSize) return render;
    return null;
  }
}
