import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SparkShape {
  circle('圆形', Color(0xFF8261DF)),
  triangle('三角形', Color(0xFFEC9B45)),
  square('正方形', Color(0xFF3BA6B4));

  const SparkShape(this.label, this.color);
  final String label;
  final Color color;
}

/// A reusable, independently animated geometric particle burst.
class ParticleShape extends StatefulWidget {
  const ParticleShape({super.key, required this.shape});
  final SparkShape shape;
  @override
  State<ParticleShape> createState() => _ParticleShapeState();
}

class _ParticleShapeState extends State<ParticleShape>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  void _burst() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final active = _controller.isAnimating;
      return Semantics(
        label: active ? '${widget.shape.label}，正在碎裂' : widget.shape.label,
        button: true,
        onTap: _burst,
        child: ExcludeSemantics(
          child: Tooltip(
            message: '点击${widget.shape.label}播放',
            child: InkWell(
              onTap: _burst,
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 240,
                height: 210,
                child: CustomPaint(
                  painter: _ShapePainter(
                    widget.shape,
                    active ? _controller.value : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.progress);
  final SparkShape shape;
  final double? progress;
  bool _inside(Offset point) => switch (shape) {
    SparkShape.circle => point.distance <= 43,
    SparkShape.square => point.dx.abs() <= 40 && point.dy.abs() <= 40,
    SparkShape.triangle =>
      point.dy >= -46 &&
          point.dy <= 37 &&
          point.dx.abs() <= (point.dy + 46) * .56,
  };
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = shape.color;
    if (progress == null) {
      switch (shape) {
        case SparkShape.circle:
          canvas.drawCircle(center, 43, paint);
        case SparkShape.square:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: center, width: 80, height: 80),
              const Radius.circular(8),
            ),
            paint,
          );
        case SparkShape.triangle:
          canvas.drawPath(
            Path()
              ..moveTo(center.dx, center.dy - 46)
              ..lineTo(center.dx + 46, center.dy + 37)
              ..lineTo(center.dx - 46, center.dy + 37)
              ..close(),
            paint,
          );
      }
      return;
    }
    final t = progress!;
    // Fixed seed keeps each fragment on one continuous, irregular trajectory.
    final random = math.Random(shape.index + 71);
    for (var x = -42; x <= 42; x += 6) {
      for (var y = -42; y <= 42; y += 6) {
        final origin = Offset(
          x + random.nextDouble() * 5 - 2.5,
          y + random.nextDouble() * 5 - 2.5,
        );
        final angle = random.nextDouble() * math.pi * 2;
        final speed = 35 + random.nextDouble() * 105;
        final gravity = 20 + random.nextDouble() * 55;
        final spin = (random.nextDouble() - .5) * 12;
        final side = 2 + random.nextDouble() * 3;
        final fade = (1 - t * (1 + random.nextDouble() * .6)).clamp(0.0, 1.0);
        if (!_inside(origin)) continue;
        final displacement = Offset(
          math.cos(angle) * speed * t,
          math.sin(angle) * speed * t + gravity * t * t,
        );
        paint.color = shape.color.withValues(alpha: fade);
        canvas.save();
        canvas.translate(
          center.dx + origin.dx + displacement.dx,
          center.dy + origin.dy + displacement.dy,
        );
        canvas.rotate(spin * t);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: side * (1 - t * .5),
            height: side * (1 - t * .5),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.progress != progress;
}
