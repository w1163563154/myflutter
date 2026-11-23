import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Corner-first deformation in unit coordinates. Axis-dependent easing bends
/// straight edges; distance delay keeps the far corner trailing the inlet.
Offset suctionPoint(
  Offset point,
  double progress, {
  Offset target = const Offset(1, 1),
}) {
  if (progress <= 0) return point;
  if (progress >= 1) return target;
  final maxDistance = [
    Offset.zero,
    const Offset(1, 0),
    const Offset(0, 1),
    const Offset(1, 1),
  ].map((corner) => (target - corner).distance).reduce(math.max);
  final distance = (target - point).distance / maxDistance;
  final delay = distance * .35;
  final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
  final pull = Curves.easeInOutCubic.transform(t);
  final xPull = 1 - math.pow(1 - pull, 1.7);
  final yPull = 1 - math.pow(1 - pull, .8);
  return Offset(
    point.dx + (target.dx - point.dx) * xPull,
    point.dy + (target.dy - point.dy) * yPull,
  );
}

/// Source and destination in the same full-page canvas coordinates.
class SuctionGeometry {
  const SuctionGeometry(this.source, this.target, {this.viewport});
  final Rect source;
  final Offset target;
  final Rect? viewport;
}

class SuctionPainter extends CustomPainter {
  SuctionPainter({
    required this.image,
    required this.animation,
    required this.geometry,
  }) : super(repaint: Listenable.merge([animation, geometry])) {
    _paint.shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
    for (var y = 0; y <= divisions; y++) {
      for (var x = 0; x <= divisions; x++) {
        _texture.add(
          Offset(x / divisions * image.width, y / divisions * image.height),
        );
      }
    }
    for (var y = 0; y < divisions; y++) {
      for (var x = 0; x < divisions; x++) {
        final a = y * (divisions + 1) + x;
        final b = a + divisions + 1;
        _indices.addAll([a, a + 1, b, a + 1, b + 1, b]);
      }
    }
  }
  static const divisions = 32;
  final ui.Image image;
  final Animation<double> animation;
  final ValueListenable<SuctionGeometry?> geometry;
  final _texture = <Offset>[];
  final _indices = <int>[];
  final _paint = Paint()..filterQuality = FilterQuality.medium;

  void dispose() => _paint.shader?.dispose();

  @override
  void paint(Canvas canvas, Size size) {
    final scene = geometry.value;
    if (animation.value >= 1 || scene == null || scene.source.isEmpty) return;
    canvas.save();
    if (animation.value == 0 && scene.viewport != null) {
      canvas.clipRect(scene.viewport!);
    }
    final rect = scene.source;
    final target = Offset(
      (scene.target.dx - rect.left) / rect.width,
      (scene.target.dy - rect.top) / rect.height,
    );
    final positions = <Offset>[];
    for (var y = 0; y <= divisions; y++) {
      for (var x = 0; x <= divisions; x++) {
        final p = suctionPoint(
          Offset(x / divisions, y / divisions),
          animation.value,
          target: target,
        );
        positions.add(
          Offset(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height),
        );
      }
    }
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: _texture,
      indices: _indices,
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, _paint);
    vertices.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(SuctionPainter oldDelegate) =>
      image != oldDelegate.image ||
      animation != oldDelegate.animation ||
      geometry != oldDelegate.geometry;
}
