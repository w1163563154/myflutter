import 'package:flutter/material.dart';
import 'package:particle_sparks/particle_sparks.dart';
import 'package:tap_ripple/tap_ripple.dart';

class AnimationGallery extends StatelessWidget {
  const AnimationGallery({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const SizedBox(height: 20),
      Text(
        '探索动画',
        style: Theme.of(
          context,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text('触碰、发现，让每个瞬间鲜活起来。'),
      const SizedBox(height: 32),
      _DemoCard(
        title: '粒子火花动画',
        subtitle: '轻触几何形状，释放绚丽粒子',
        icon: Icons.auto_awesome,
        color: const Color(0xFF7155D9),
        page: const ParticleSparksDemo(),
      ),
      const SizedBox(height: 16),
      _DemoCard(
        title: '点击水波动画',
        subtitle: '指尖轻点，涟漪随心荡漾',
        icon: Icons.water_drop_outlined,
        color: const Color(0xFF258AA5),
        page: const TapRippleDemo(),
      ),
    ],
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    color: color.withValues(alpha: .08),
    child: InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: color),
          ],
        ),
      ),
    ),
  );
}
