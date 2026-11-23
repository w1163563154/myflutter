import 'package:flutter/material.dart';
import 'vault_service.dart';

/// Wraps the Navigator so inactivity handling also covers editor routes.
class VaultGuard extends StatefulWidget {
  const VaultGuard({super.key, required this.child});
  final Widget child;
  @override
  State<VaultGuard> createState() => _VaultGuardState();
}

class _VaultGuardState extends State<VaultGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      VaultService.instance.lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => VaultService.instance.activity(),
    onPointerSignal: (_) => VaultService.instance.activity(),
    child: Focus(
      onKeyEvent: (node, event) {
        VaultService.instance.activity();
        return KeyEventResult.ignored;
      },
      child: widget.child,
    ),
  );
}
