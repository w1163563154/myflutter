import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/main.dart';
import 'package:myflutter/image_suction_demo.dart';
import 'package:myflutter/suction_mesh.dart';

Future<void> loaded(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text('准备就绪').evaluate().isNotEmpty) return;
  }
  fail(
    'bundled image did not load: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join('|')}',
  );
}

Future<void> capture(WidgetTester tester, String name) async {
  final folder = Platform.environment['SUCTION_REVIEW'];
  if (folder == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(folder).create(recursive: true);
    await File('$folder/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'screen target survives scroll and resize with matching canvas coordinates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => tester.pumpWidget(const MaterialApp(home: ImageSuctionDemo())),
      );
      await loaded(tester);
      final handle = find.byKey(const ValueKey('suction-inlet'));
      await tester.drag(handle, const Offset(-150, 200));
      await tester.pumpAndSettle();
      final original = tester.getCenter(handle);
      SuctionGeometry scene() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SuctionPainter>()
          .single
          .geometry
          .value!;
      expect(scene().target, original);
      final fraction = Offset(original.dx / 390, original.dy / 720);
      tester.view.physicalSize = const Size(720, 390);
      await tester.pumpAndSettle();
      expect(tester.getCenter(handle).dx, closeTo(fraction.dx * 720, .01));
      expect(tester.getCenter(handle).dy, closeTo(fraction.dy * 390, .01));
      final before = scene();
      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(scene().source.top, lessThan(before.source.top));
      expect(scene().target, before.target);
      expect(scene().viewport!.top, greaterThanOrEqualTo(kToolbarHeight));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'inlet drags outside picture, clamps to screen, reset retains target',
    (tester) async {
      tester.view.physicalSize = const Size(390, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => tester.pumpWidget(const MaterialApp(home: ImageSuctionDemo())),
      );
      await loaded(tester);
      final handle = find.byKey(const ValueKey('suction-inlet'));
      expect(handle, findsOneWidget);
      final start = tester.getCenter(handle);
      await tester.drag(handle, const Offset(-160, 200));
      await tester.pumpAndSettle();
      final target = tester.getCenter(handle);
      expect(target, start + const Offset(-160, 200));
      expect(target.dy, greaterThan(550));
      await tester.tap(find.text('吸入'));
      await tester.pump();
      await tester.drag(handle, const Offset(100, -100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getCenter(handle), target);
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(handle), target);
      await tester.drag(handle, const Offset(-1000, -1000));
      await tester.pumpAndSettle();
      final clamped = tester.getRect(handle);
      expect(clamped.left, greaterThanOrEqualTo(0));
      expect(clamped.top, greaterThanOrEqualTo(0));
      expect(clamped.size, const Size(48, 48));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('suction entry opens and returns', (tester) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => tester.pumpWidget(const MyApp()));
    await tester.tap(find.text('小工具'));
    await tester.pumpAndSettle();
    final entry = find.text('图片吸入动画');
    await tester.scrollUntilVisible(entry, 180);
    await tester.runAsync(() => tester.tap(entry));
    await loaded(tester);
    expect(find.text('吸入'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.text('探索动画'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('absorb completes, reset interrupts, replay and exit are safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => tester.pumpWidget(
        const RepaintBoundary(
          key: ValueKey('capture'),
          child: MaterialApp(home: ImageSuctionDemo()),
        ),
      ),
    );
    await loaded(tester);
    await capture(tester, 'initial');
    await tester.tap(find.text('吸入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('正在吸入…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await capture(tester, 'middle');
    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(find.text('准备就绪'), findsOneWidget);
    await capture(tester, 'reset');
    await tester.tap(find.text('吸入'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('已吸入，点击重置可再次播放'), findsOneWidget);
    await tester.pumpAndSettle();
    await capture(tester, 'complete');
    await tester.tap(find.text('重置'));
    await tester.pump();
    await tester.tap(find.text('吸入'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion completes immediately', (tester) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: ImageSuctionDemo(),
          ),
        ),
      ),
    );
    await loaded(tester);
    await tester.tap(find.text('吸入'));
    await tester.pump();
    expect(find.text('已吸入，点击重置可再次播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed asset retries and loading may finish after exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await tester.runAsync(
      () => File('assets/images/suction_landscape.png').readAsBytes(),
    );
    var failAsset = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      'flutter/assets',
      (_) async => failAsset ? null : ByteData.sublistView(bytes!),
    );
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    await tester.pumpWidget(const MaterialApp(home: ImageSuctionDemo()));
    await tester.pumpAndSettle();
    expect(find.text('图片加载失败'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    failAsset = false;
    await tester.runAsync(() => tester.tap(find.text('重新加载')));
    await loaded(tester);
    expect(find.text('准备就绪'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => tester.pumpWidget(const MaterialApp(home: ImageSuctionDemo())),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
