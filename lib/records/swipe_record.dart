import 'package:flutter/material.dart';

/// Reveals an action over one quarter of the row, never dismisses by swiping.
class SwipeRecord extends StatefulWidget {
  const SwipeRecord({
    super.key,
    required this.child,
    required this.onDelete,
    required this.recordId,
  });
  final Widget child;
  final Future<void> Function() onDelete;
  final int recordId;
  @override
  State<SwipeRecord> createState() => _SwipeRecordState();
}

class _SwipeRecordState extends State<SwipeRecord> {
  double _reveal = 0;
  bool _dragging = false, _busy = false;
  Future<void> _performDelete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (_reveal > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: .25,
                      heightFactor: 1,
                      child: Semantics(
                        container: true,
                        button: true,
                        label: '删除',
                        onTap: _busy ? null : _performDelete,
                        child: ExcludeSemantics(
                          child: Material(
                            color: const Color(0xFFCF4440),
                            child: InkWell(
                              key: ValueKey(
                                'delete-courier-${widget.recordId}',
                              ),
                              onTap: _busy ? null : _performDelete,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white,
                                    size: 25,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '删除',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                excludeFromSemantics: true,
                onHorizontalDragUpdate: _busy
                    ? null
                    : (details) => setState(() {
                        _dragging = true;
                        _reveal = (_reveal - details.delta.dx / width).clamp(
                          0,
                          .25,
                        );
                      }),
                onHorizontalDragEnd: _busy
                    ? null
                    : (_) => setState(() {
                        _dragging = false;
                        _reveal = _reveal > .08 ? .25 : 0;
                      }),
                onHorizontalDragCancel: () => setState(() {
                  _dragging = false;
                  _reveal = 0;
                }),
                child: AnimatedSlide(
                  offset: Offset(-_reveal, 0),
                  duration: Duration(milliseconds: _dragging ? 0 : 180),
                  curve: Curves.easeOutCubic,
                  child: _reveal == 0
                      ? widget.child
                      : GestureDetector(
                          excludeFromSemantics: true,
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _reveal = 0),
                          child: AbsorbPointer(child: widget.child),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
