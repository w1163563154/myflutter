import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;
import 'solar_system_model.dart';
import 'solar_renderer.dart';

class SolarSystemScene extends StatefulWidget {
  const SolarSystemScene({
    super.key,
    required this.model,
    required this.resetSignal,
  });
  final SolarSystemModel model;
  final ValueNotifier<int> resetSignal;
  @override
  State<SolarSystemScene> createState() => _SolarSystemSceneState();
}

class _SolarSystemSceneState extends State<SolarSystemScene> {
  late three.ThreeJS engine;
  three.OrbitControls? controls;
  final bodies = <three.Mesh>[];
  final orbitLines = <three.Line>[];
  final positions = ValueNotifier<List<Offset>>([]);
  bool ready = false, disposed = false;
  String? error;
  Timer? timeout;
  late final three.Mesh sun;
  late three.Mesh moon;
  late three.Group moonSystem;
  late three.Line moonOrbit;
  int lastFocus = -2;
  int lastFocusRevision = 0;
  three.Vector3? lastFollow;

  void configureNavigation() {
    controls?.mouseButtons['left'] = widget.model.panMode
        ? three.Mouse.pan
        : three.Mouse.rotate;
    controls?.touches['ONE'] = widget.model.panMode
        ? three.Touch.pan
        : three.Touch.rotate;
  }

  three.Vector3 focusPosition(int index) {
    if (index == -1) return three.Vector3();
    if (index == 8) return moon.position.clone().add(moonSystem.position);
    return bodies[index].parent!.position.clone();
  }

  void followSelection() {
    final index = widget.model.focusIndex;
    if (index == -2) {
      if (lastFocus != -2) resetView();
      lastFollow = null;
    } else {
      final position = focusPosition(index);
      if (lastFocus != index ||
          lastFocusRevision != widget.model.focusRevision) {
        final radius = index == -1
            ? 2.5
            : index == 8
            ? .24
            : planets[index].radius;
        final distance = index == 2 ? 7.0 : math.max(2.0, radius * 6);
        controls!.target.setFrom(position);
        controls!.sphericalDelta.set(0, 0, 0);
        controls!.panOffset.setValues(0, 0, 0);
        controls!.scale = 1;
        controls!.minDistance = radius * 1.5;
        engine.camera.position
            .setFrom(position)
            .add(three.Vector3(0, distance * .5, distance));
      } else if (lastFollow != null) {
        final delta = position.clone().sub(lastFollow!);
        controls!.target.add(delta);
        engine.camera.position.add(delta);
      }
      lastFollow = position;
    }
    lastFocus = index;
    lastFocusRevision = widget.model.focusRevision;
  }

  @override
  void initState() {
    super.initState();
    engine = SolarRenderer(
      onFailure: (e) {
        if (mounted) setState(() => error = '3D 初始化失败：$e');
      },
      settings: three.Settings(clearColor: 0x050914, enableShadowMap: false),
      setup: setup,
      onSetupComplete: () {
        timeout?.cancel();
        engine.visible = widget.model.active;
        if (!widget.model.active) engine.ticker?.stop();
        if (mounted && error == null) setState(() => ready = true);
      },
    );
    // Assign before asynchronous initialization so early navigation is safe.
    engine.scene = three.Scene();
    engine.camera = three.PerspectiveCamera(48, 1, .1, 1000);
    engine.windowResizeUpdate = (_) => resetView();
    widget.resetSignal.addListener(resetView);
    timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && !ready) setState(() => error = '3D 场景加载超时，请检查设备图形支持后重试。');
    });
  }

  @override
  void didUpdateWidget(covariant SolarSystemScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    configureNavigation();
    engine.visible = widget.model.active;
    if (widget.model.active) {
      engine.clock.getDelta();
      if (ready && !(engine.ticker?.isActive ?? true)) engine.ticker?.start();
    } else {
      engine.ticker?.stop();
    }
  }

  void resetView() {
    final aspect = (engine.camera as three.PerspectiveCamera).aspect;
    final distance = math.max(
      86.0,
      41 /
          math.sin(
            math.atan(math.tan(24 * math.pi / 180) * math.min(1.0, aspect)),
          ),
    );
    engine.camera.position.setValues(0, distance * .607, distance * .795);
    controls?.sphericalDelta.set(0, 0, 0);
    controls?.scale = 1;
    controls?.panOffset.setValues(0, 0, 0);
    controls?.minDistance = 4;
    lastFollow = null;
    lastFocus = -2;
    controls?.target.setValues(0, 0, 0);
    controls?.update();
  }

  Future<void> setup() async {
    try {
      if (disposed) return;
      (engine.camera as three.PerspectiveCamera).aspect =
          engine.width / engine.height;
      engine.camera.updateProjectionMatrix();
      resetView();
      engine.scene.add(three.AmbientLight(0xb0c8ff, .24));
      engine.scene.add(three.PointLight(0xfff2dc, 2.4, 0, 0));
      final loader = three.TextureLoader();
      for (var i = 0; i <= planets.length; i++) {
        final bytes = await rootBundle.load('assets/solar/$i.jpg');
        final texture = await loader.fromBytes(bytes.buffer.asUint8List());
        if (disposed) {
          texture?.dispose();
          return;
        }
        if (texture == null) throw StateError('无法读取星球表面纹理');
        final mesh = three.Mesh(
          three.SphereGeometry(i == 0 ? 2.5 : planets[i - 1].radius, 40, 28),
          i == 0
              ? three.MeshBasicMaterial({three.MaterialProperty.map: texture})
              : three.MeshPhongMaterial({
                  three.MaterialProperty.map: texture,
                  three.MaterialProperty.shininess: 8,
                }),
        );
        if (i == 0) {
          sun = mesh;
          engine.scene.add(mesh);
        } else {
          final tilt = three.Group()..rotation.z = i == 3 ? .41 : .06;
          tilt.add(mesh);
          engine.scene.add(tilt);
          bodies.add(mesh);
          final data = planets[i - 1];
          final points = List.generate(193, (j) {
            final a = j / 192 * math.pi * 2;
            return three.Vector3(
              math.cos(a) * data.orbit,
              0,
              math.sin(a) * data.orbit,
            );
          });
          final line = three.Line(
            three.BufferGeometry().setFromPoints(points),
            three.LineBasicMaterial({
              three.MaterialProperty.color: 0x354259,
              three.MaterialProperty.transparent: true,
              three.MaterialProperty.opacity: .65,
            }),
          );
          orbitLines.add(line);
          engine.scene.add(line);
          if (i == 6) {
            final ring = three.Mesh(
              three.RingGeometry(1.85, 3, 96),
              three.MeshPhongMaterial({
                three.MaterialProperty.color: 0xbaaa85,
                three.MaterialProperty.side: three.DoubleSide,
                three.MaterialProperty.transparent: true,
                three.MaterialProperty.opacity: .8,
              }),
            );
            ring.rotation.x = -math.pi / 2;
            mesh.add(ring);
          }
        }
      }
      moonSystem = three.Group();
      final moonBytes = await rootBundle.load('assets/solar/moon.jpg');
      final moonTexture = await loader.fromBytes(
        moonBytes.buffer.asUint8List(),
      );
      if (disposed) {
        moonTexture?.dispose();
        return;
      }
      if (moonTexture == null) throw StateError('无法读取月球纹理');
      moon = three.Mesh(
        three.SphereGeometry(.24, 32, 24),
        three.MeshPhongMaterial({three.MaterialProperty.map: moonTexture}),
      );
      moonSystem.add(moon);
      moonOrbit = three.Line(
        three.BufferGeometry().setFromPoints(
          List.generate(97, (i) {
            final a = i / 96 * math.pi * 2;
            return three.Vector3(
              math.cos(a) * 1.65,
              math.sin(a) * .14,
              math.sin(a) * 1.65,
            );
          }),
        ),
        three.LineBasicMaterial({three.MaterialProperty.color: 0x728399}),
      );
      moonSystem.add(moonOrbit);
      engine.scene.add(moonSystem);
      final random = math.Random(42);
      final stars = List.generate(1100, (_) {
        final a = random.nextDouble() * math.pi * 2;
        final z = random.nextDouble() * 2 - 1;
        final r = math.sqrt(1 - z * z) * 220;
        return three.Vector3(math.cos(a) * r, z * 220, math.sin(a) * r);
      });
      engine.scene.add(
        three.Points(
          three.BufferGeometry().setFromPoints(stars),
          three.PointsMaterial({
            three.MaterialProperty.color: 0xbccce9,
            three.MaterialProperty.size: .45,
            three.MaterialProperty.sizeAttenuation: true,
          }),
        ),
      );
      controls = three.OrbitControls(engine.camera, engine.globalKey)
        ..enablePan = true
        ..screenSpacePanning = true
        ..minDistance = 4
        ..maxDistance = 400
        ..enableDamping = true;
      configureNavigation();
      engine.addAnimationEvent((dt) {
        if (disposed || !widget.model.active) return;
        // Drop the first/resume frame's accumulated gap.
        widget.model.advance(dt > .25 ? 0 : dt);
        sun.rotation.y = widget.model.time * .12;
        for (var i = 0; i < bodies.length; i++) {
          final a = widget.model.orbitAngle(i);
          bodies[i].parent!.position.setValues(
            math.cos(a) * planets[i].orbit,
            0,
            math.sin(a) * planets[i].orbit,
          );
          bodies[i].rotation.y = widget.model.spinAngle(i);
          orbitLines[i].visible = widget.model.showOrbits;
        }
        moonSystem.position.setFrom(bodies[2].parent!.position);
        final moonAngle = widget.model.moonAngle;
        moon.position.setValues(
          math.cos(moonAngle) * 1.65,
          math.sin(moonAngle) * .14,
          math.sin(moonAngle) * 1.65,
        );
        moon.rotation.y = -moonAngle;
        moonOrbit.visible = widget.model.showOrbits;
        followSelection();
        controls?.update();
        final offsets = <Offset>[];
        for (var i = 0; i < bodies.length; i++) {
          final v = bodies[i].parent!.position.clone();
          v.y += planets[i].radius + .7;
          v.project(engine.camera);
          offsets.add(
            v.z < -1 || v.z > 1
                ? const Offset(-9999, -9999)
                : Offset(
                    (v.x + 1) * engine.width / 2,
                    (1 - v.y) * engine.height / 2,
                  ),
          );
        }
        final moonLabel = moon.position.clone().add(moonSystem.position);
        moonLabel.y += .5;
        moonLabel.project(engine.camera);
        offsets.add(
          moonLabel.z < -1 || moonLabel.z > 1
              ? const Offset(-9999, -9999)
              : Offset(
                  (moonLabel.x + 1) * engine.width / 2,
                  (1 - moonLabel.y) * engine.height / 2,
                ),
        );
        positions.value = offsets;
      });
    } catch (e) {
      if (mounted) setState(() => error = '无法加载 3D 场景：$e');
    }
  }

  @override
  void dispose() {
    disposed = true;
    timeout?.cancel();
    widget.resetSignal.removeListener(resetView);
    controls?.dispose();
    engine.dispose();
    positions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Stack(
        fit: StackFit.expand,
        children: [
          MediaQuery(
            data: MediaQuery.of(context).copyWith(size: constraints.biggest),
            child: engine.build(),
          ),
          if (ready)
            IgnorePointer(
              child: ValueListenableBuilder<List<Offset>>(
                valueListenable: positions,
                builder: (_, values, _) => CustomPaint(
                  painter: _Labels(values, widget.model.showLabels),
                ),
              ),
            ),
          if (!ready && error == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在构建太阳系…', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          if (error != null)
            ColoredBox(
              color: const Color(0xff050914),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Labels extends CustomPainter {
  _Labels(this.positions, this.visible);
  final List<Offset> positions;
  final bool visible;
  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    for (var i = 0; i < positions.length; i++) {
      final p = positions[i];
      if (p.dx < 0 || p.dx > size.width || p.dy < 0 || p.dy > size.height) {
        continue;
      }
      final text = TextPainter(
        text: TextSpan(
          text: i == 8 ? '月球' : planets[i].name,
          style: const TextStyle(
            color: Color(0xffd4deef),
            fontSize: 11,
            shadows: [Shadow(blurRadius: 5, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p - Offset(text.width / 2, text.height));
    }
  }

  @override
  bool shouldRepaint(_Labels oldDelegate) => true;
}
