import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

/// Local image picker and reusable pixel-preserving fragmentation demo.
class ImageParticles extends StatefulWidget {
  const ImageParticles({super.key, this.loadImage});
  final Future<Uint8List?> Function()? loadImage;
  @override
  State<ImageParticles> createState() => _ImageParticlesState();
}

class _ImageParticlesState extends State<ImageParticles>
    with SingleTickerProviderStateMixin {
  static const _limit = 20 * 1024 * 1024;
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  ui.Image? _image;
  bool _loading = false;
  String? _error;
  Future<Uint8List?> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '图片',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
          mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
          uniformTypeIdentifiers: [
            'public.png',
            'public.jpeg',
            'org.webmproject.webp',
          ],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > _limit) throw const FormatException('size');
    return file.readAsBytes();
  }

  Future<void> _select() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    ui.Image? decoded;
    try {
      final bytes = await (widget.loadImage?.call() ?? _pick());
      if (bytes == null || !mounted) return;
      if (bytes.length > _limit) throw const FormatException('size');
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        decoded = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      final scale = math.min(
        1.0,
        1024 / math.max(decoded.width, decoded.height),
      );
      if (scale < 1) {
        final original = decoded;
        final recorder = ui.PictureRecorder();
        final width = math.max(1, (original.width * scale).round());
        final height = math.max(1, (original.height * scale).round());
        Canvas(recorder).drawImageRect(
          original,
          Rect.fromLTWH(
            0,
            0,
            original.width.toDouble(),
            original.height.toDouble(),
          ),
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        try {
          decoded = await picture.toImage(width, height);
        } finally {
          picture.dispose();
          original.dispose();
        }
      }
      if (!mounted) {
        decoded.dispose();
        return;
      }
      _controller.reset();
      final old = _image;
      setState(() => _image = decoded);
      old?.dispose();
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取图片，请选择有效的 PNG、JPEG 或 WebP 图片。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _burst() {
    if (_image == null || MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('图片碎裂', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('选择本地图片，点击预览播放碎裂动画。图片不会上传服务器。'),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _loading ? null : _select,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _loading
                ? '正在读取…'
                : _image == null
                ? '选择图片'
                : '替换图片',
          ),
        ),
      ),
      const Text('支持 PNG / JPEG / WebP，最大 20 MB。'),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_image != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Semantics(
              label: _controller.isAnimating ? '图片，正在碎裂' : '图片，点击播放碎裂动画',
              button: true,
              onTap: _burst,
              child: ExcludeSemantics(
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _burst,
                    child: SizedBox(
                      height: 300,
                      child: CustomPaint(
                        painter: ImageFragmentPainter(
                          _image!,
                          _controller.isAnimating ? _controller.value : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Paints real source-image tiles rather than approximating pixels with colors.
class ImageFragmentPainter extends CustomPainter {
  ImageFragmentPainter(this.image, this.progress);
  final ui.Image image;
  final double? progress;
  @override
  void paint(Canvas canvas, Size size) {
    final source = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(
      BoxFit.contain,
      source,
      Size(size.width * .7, size.height * .65),
    );
    final target = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (progress == null) {
      canvas.drawImageRect(image, Offset.zero & source, target, paint);
      return;
    }
    final t = progress!;
    const columns = 16;
    final rows = (columns * source.height / source.width).round().clamp(1, 24);
    paint.color = Colors.white.withValues(alpha: 1 - t);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final src = Rect.fromLTRB(
          x * source.width / columns,
          y * source.height / rows,
          (x + 1) * source.width / columns,
          (y + 1) * source.height / rows,
        );
        final dst = Rect.fromLTWH(
          target.left + x * target.width / columns,
          target.top + y * target.height / rows,
          target.width / columns,
          target.height / rows,
        );
        final angle = math.atan2(y - rows / 2, x - columns / 2);
        final speed = 30 + (x * 13 + y * 23) % 35;
        final center =
            dst.center +
            Offset(
              math.cos(angle) * speed * t,
              math.sin(angle) * speed * t + 35 * t * t,
            );
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.sin(x * 3 + y) * t * 2);
        canvas.scale(1 - t * .4);
        canvas.drawImageRect(
          image,
          src,
          Rect.fromCenter(
            center: Offset.zero,
            width: dst.width,
            height: dst.height,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ImageFragmentPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.progress != progress;
}
