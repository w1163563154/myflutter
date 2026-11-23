import 'package:flutter/material.dart';
import 'solar_system_model.dart';
import 'solar_system_scene.dart';

typedef SolarSceneBuilder =
    Widget Function(BuildContext, SolarSystemModel, ValueNotifier<int>);

class SolarSystemPage extends StatefulWidget {
  const SolarSystemPage({super.key, this.sceneBuilder});
  final SolarSceneBuilder? sceneBuilder;
  @override
  State<SolarSystemPage> createState() => _SolarSystemPageState();
}

class _SolarSystemPageState extends State<SolarSystemPage>
    with WidgetsBindingObserver {
  final model = SolarSystemModel();
  final reset = ValueNotifier(0);
  bool initialized = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      model.paused = MediaQuery.disableAnimationsOf(context);
      initialized = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => model.active = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    reset.dispose();
    super.dispose();
  }

  void change(VoidCallback action) => setState(action);
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffe9b65b),
        brightness: Brightness.dark,
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xff050914),
      appBar: AppBar(
        title: const Text('3D 太阳系'),
        backgroundColor: const Color(0xff050914),
        actions: [
          IconButton(
            tooltip: '重新加载',
            icon: const Icon(Icons.refresh),
            onPressed: () => change(() => generation++),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.public, size: 16, color: Color(0xffe9b65b)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SOLAR SYSTEM  /  太阳系漫游',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.3,
                      color: Colors.white60,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.sceneBuilder?.call(context, model, reset) ??
                      SolarSystemScene(
                        key: ValueKey(generation),
                        model: model,
                        resetSignal: reset,
                      ),
                  const Positioned(
                    left: 16,
                    bottom: 12,
                    child: IgnorePointer(
                      child: Text(
                        '旋转 / 平移切换 · 双指缩放和平移 · 右键拖动平移',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xff101827),
                border: Border(top: BorderSide(color: Color(0xff253047))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: model.paused ? '继续' : '暂停',
                        onPressed: () =>
                            change(() => model.paused = !model.paused),
                        icon: Icon(
                          model.paused ? Icons.play_arrow : Icons.pause,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${model.speed.toStringAsFixed(2)}×',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: model.speed,
                          min: .25,
                          max: 4,
                          divisions: 15,
                          label: '${model.speed}×',
                          onChanged: (v) => change(() => model.speed = v),
                        ),
                      ),
                      IconButton(
                        tooltip: '恢复视角',
                        onPressed: () => change(() {
                          model.focusIndex = -2;
                          reset.value++;
                        }),
                        icon: const Icon(Icons.center_focus_strong),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        '定位 ',
                        style: TextStyle(color: Colors.white60),
                      ),
                      Expanded(
                        child: DropdownButton<int>(
                          value: model.focusIndex,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: -2,
                              child: Text('太阳系全景'),
                            ),
                            const DropdownMenuItem(
                              value: -1,
                              child: Text('太阳'),
                            ),
                            for (var i = 0; i < planets.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(planets[i].name),
                              ),
                            const DropdownMenuItem(value: 8, child: Text('月球')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              change(() {
                                model.focusIndex = value;
                                model.focusRevision++;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('旋转')),
                          ButtonSegment(value: true, label: Text('平移')),
                        ],
                        selected: {model.panMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) =>
                            change(() => model.panMode = value.first),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('轨道'),
                        selected: model.showOrbits,
                        onSelected: (v) => change(() => model.showOrbits = v),
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('名称'),
                        selected: model.showLabels,
                        onSelected: (v) => change(() => model.showLabels = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '大小、距离与时间为展示比例',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
