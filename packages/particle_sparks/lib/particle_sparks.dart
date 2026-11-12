import 'package:flutter/material.dart';
import 'src/particle_shape.dart';
export 'src/particle_shape.dart' show ParticleShape, SparkShape;

class ParticleSparksDemo extends StatelessWidget {
  const ParticleSparksDemo({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('粒子火花动画')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('轻触形状，释放火花', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('每一种形状，都藏着不同的能量。点击可重复播放。'),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final shape in SparkShape.values)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ParticleShape(shape: shape),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(shape.label),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
