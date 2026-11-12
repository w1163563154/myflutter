import 'package:flutter/material.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _selected = 0;
  late final _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );
  late final Animation<double> _curve = _transition.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: reduced ? const AlwaysStoppedAnimation(1) : _curve,
          child: SlideTransition(
            position: reduced
                ? const AlwaysStoppedAnimation(Offset.zero)
                : Tween(
                    begin: const Offset(0, .025),
                    end: Offset.zero,
                  ).animate(_curve),
            child: IndexedStack(
              index: _selected,
              children: const [
                Center(child: Text('探索动画')),
                EmptyTab(icon: Icons.movie_outlined, title: '视频内容即将上线'),
                EmptyTab(icon: Icons.person_outline, title: '这里将记录你的灵感'),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) {
          if (index == _selected) return;
          setState(() => _selected = index);
          if (reduced) {
            _transition.value = 1;
          } else {
            _transition.forward(from: 0);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '动画集'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), label: '视频集'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }
}

class EmptyTab extends StatelessWidget {
  const EmptyTab({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('敬请期待'),
        ],
      ),
    ),
  );
}
