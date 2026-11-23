import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'suction_mesh.dart';

class ImageSuctionDemo extends StatefulWidget {
  const ImageSuctionDemo({super.key});
  @override
  State<ImageSuctionDemo> createState() => _ImageSuctionDemoState();
}

class _ImageSuctionDemoState extends State<ImageSuctionDemo>
    with SingleTickerProviderStateMixin {
  final _screenKey = GlobalKey();
  final _previewKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _geometry = ValueNotifier<SuctionGeometry?>(null);
  late final AnimationController _controller;
  ui.Image? _image;
  SuctionPainter? _painter;
  Offset? _targetFraction;
  Offset _grabOffset = Offset.zero;
  bool _failed = false;
  bool _syncPending = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1600),
        )..addStatusListener((_) {
          if (mounted) setState(() {});
        });
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final data = await rootBundle.load('assets/images/suction_landscape.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      late final ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _painter = SuctionPainter(
          image: image,
          animation: _controller,
          geometry: _geometry,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Offset _clamp(Offset point, Size size) {
    final padding = MediaQuery.paddingOf(context);
    // Keep the whole touch target inside app-controlled, touchable screen space.
    return Offset(
      point.dx.clamp(24 + padding.left, size.width - 24 - padding.right),
      point.dy.clamp(24 + padding.top, size.height - 24 - padding.bottom),
    );
  }

  void _scheduleGeometry() {
    if (_syncPending) return;
    _syncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPending = false;
      if (!mounted) return;
      _syncGeometry();
    });
  }

  void _syncGeometry() {
    final screen = _screenKey.currentContext?.findRenderObject() as RenderBox?;
    final preview =
        _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (screen == null ||
        preview == null ||
        !screen.hasSize ||
        !preview.hasSize) {
      return;
    }
    final source =
        screen.globalToLocal(preview.localToGlobal(Offset.zero)) & preview.size;
    final fraction = _targetFraction;
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport = viewportBox == null
        ? null
        : screen.globalToLocal(viewportBox.localToGlobal(Offset.zero)) &
              viewportBox.size;
    final target = _clamp(
      fraction == null
          ? source.bottomRight
          : Offset(
              fraction.dx * screen.size.width,
              fraction.dy * screen.size.height,
            ),
      screen.size,
    );
    final old = _geometry.value;
    if (old?.source != source ||
        old?.target != target ||
        old?.viewport != viewport) {
      _geometry.value = SuctionGeometry(source, target, viewport: viewport);
    }
  }

  void _drag(DragUpdateDetails details) {
    final screen = _screenKey.currentContext?.findRenderObject() as RenderBox?;
    final scene = _geometry.value;
    if (_controller.isAnimating || screen == null || scene == null) return;
    final target = _clamp(
      screen.globalToLocal(details.globalPosition) + _grabOffset,
      screen.size,
    );
    _targetFraction = Offset(
      target.dx / screen.size.width,
      target.dy / screen.size.height,
    );
    _geometry.value = SuctionGeometry(
      scene.source,
      target,
      viewport: scene.viewport,
    );
  }

  void _absorb() {
    _syncGeometry();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _painter?.dispose();
    _geometry.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleGeometry();
    final running = _controller.isAnimating;
    final done = _controller.isCompleted;
    final status = _failed
        ? '图片加载失败'
        : _image == null
        ? '正在加载图片…'
        : done
        ? '已吸入，点击重置可再次播放'
        : running
        ? '正在吸入…'
        : '准备就绪';
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleGeometry();
        return Stack(
          key: _screenKey,
          fit: StackFit.expand,
          children: [
            Scaffold(
              appBar: AppBar(title: const Text('图片吸入动画')),
              body: SafeArea(
                child: NotificationListener<ScrollNotification>(
                  key: _viewportKey,
                  onNotification: (_) {
                    _scheduleGeometry();
                    return false;
                  },
                  child: ListView(
                    physics: running
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        '把风景吸向你想去的地方',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('拖动圆形吸入口到屏幕任意位置，再点击吸入。重置会保留位置。'),
                      const SizedBox(height: 28),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: DecoratedBox(
                              key: _previewKey,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: _image == null
                                  ? Center(
                                      child: _failed
                                          ? TextButton(
                                              onPressed: _load,
                                              child: const Text('重新加载'),
                                            )
                                          : const CircularProgressIndicator(),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(child: Text(status, semanticsLabel: status)),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        children: [
                          FilledButton.icon(
                            onPressed: _image == null || running || done
                                ? null
                                : _absorb,
                            icon: const Icon(Icons.south_east),
                            label: const Text('吸入'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _controller.reset(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('重置'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_painter != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Semantics(
                    label: done ? '图片已吸入' : '山峦与落日风景图片',
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _painter),
                    ),
                  ),
                ),
              ),
            ValueListenableBuilder<SuctionGeometry?>(
              valueListenable: _geometry,
              builder: (context, scene, _) {
                if (scene == null) return const SizedBox.shrink();
                return Positioned(
                  left: scene.target.dx - 24,
                  top: scene.target.dy - 24,
                  child: Semantics(
                    label: running ? '吸入口，播放中位置锁定' : '吸入口，拖动可调整全屏位置',
                    child: GestureDetector(
                      key: const ValueKey('suction-inlet'),
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (details) {
                        final screen =
                            _screenKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (screen != null) {
                          _grabOffset =
                              scene.target -
                              screen.globalToLocal(details.globalPosition);
                        }
                      },
                      onPanUpdate: _drag,
                      child: Tooltip(
                        message: running ? '播放中位置锁定' : '拖动吸入口',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.open_with,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
