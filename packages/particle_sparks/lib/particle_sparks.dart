import 'package:flutter/material.dart';

/// Standalone particle demo. Shape interaction is added in issue #4.
class ParticleSparksDemo extends StatelessWidget {
  const ParticleSparksDemo({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('粒子火花动画')),
    body: const Center(child: Text('轻触形状，释放火花')),
  );
}
