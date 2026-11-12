import 'package:flutter/material.dart';

/// A bounded, tap-position ripple demo with no host-app dependencies.
class TapRippleDemo extends StatefulWidget {
  const TapRippleDemo({super.key});
  @override
  State<TapRippleDemo> createState() => _TapRippleDemoState();
}

class _TapRippleDemoState extends State<TapRippleDemo> {
  final List<({int id, Offset point})> _rings = [];
  int _nextId = 0;
  void _tap(TapDownDetails details) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() {
      if (_rings.length == 8) _rings.removeAt(0);
      _rings.add((id: _nextId++, point: details.localPosition));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('点击水波动画')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('让灵感泛起涟漪', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('轻触下方任意位置，看看水波向外扩散。'),
            const SizedBox(height: 24),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: GestureDetector(
                  key: const ValueKey('ripple-area'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _tap,
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Center(
                          child: IgnorePointer(child: Text('轻触 · 泛起涟漪')),
                        ),
                        for (final ring in _rings)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _Ripple(
                                key: ValueKey(ring.id),
                                point: ring.point,
                                color: Theme.of(context).colorScheme.primary,
                                onEnd: () {
                                  if (mounted) {
                                    setState(
                                      () => _rings.removeWhere(
                                        (r) => r.id == ring.id,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Ripple extends StatelessWidget {
  const _Ripple({
    super.key,
    required this.point,
    required this.color,
    required this.onEnd,
  });
  final Offset point;
  final Color color;
  final VoidCallback onEnd;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 850),
    onEnd: onEnd,
    builder: (context, progress, child) => CustomPaint(
      key: const ValueKey('ripple-ring'),
      painter: _RipplePainter(point, color, progress),
    ),
  );
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.point, this.color, this.progress);
  final Offset point;
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = Curves.easeOut.transform(progress) * 180;
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = color.withValues(alpha: (1 - progress) * .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - progress) + 1,
    );
    canvas.drawCircle(
      point,
      radius * .65,
      Paint()..color = color.withValues(alpha: (1 - progress) * .12),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.point != point ||
      oldDelegate.color != color;
}
