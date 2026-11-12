import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:particle_sparks/src/image_particles.dart';

Future<Uint8List> sample() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 48, 32), Paint()..color = Colors.orange);
  final picture = recorder.endRecording();
  final image = await picture.toImage(48, 32);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('pending selection can finish after disposal', (tester) async {
    final completer = Completer<Uint8List?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ImageParticles(loadImage: () => completer.future)),
      ),
    );
    await tester.tap(find.text('选择图片'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    completer.complete(Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion leaves selected image intact', (tester) async {
    final bytes = await tester.runAsync(sample);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ImageParticles(loadImage: () async => bytes)),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('选择图片'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('图片，点击播放碎裂动画'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('图片，点击播放碎裂动画'), findsOneWidget);
  });
  testWidgets('select image, burst, replay, restore and replace', (
    tester,
  ) async {
    final bytes = await tester.runAsync(sample);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ImageParticles(loadImage: () async => bytes)),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('选择图片'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('图片，点击播放碎裂动画'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('图片，点击播放碎裂动画'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('图片，正在碎裂'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('图片，正在碎裂'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('图片，点击播放碎裂动画'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('替换图片'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('图片，点击播放碎裂动画'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancel and invalid file do not crash', (tester) async {
    Uint8List? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ImageParticles(loadImage: () async => selected)),
      ),
    );
    await tester.tap(find.text('选择图片'));
    await tester.pumpAndSettle();
    expect(find.text('选择图片'), findsOneWidget);
    selected = Uint8List.fromList([1, 2, 3]);
    await tester.runAsync(() async {
      await tester.tap(find.text('选择图片'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('无法读取图片，请选择有效的 PNG、JPEG 或 WebP 图片。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
