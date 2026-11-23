import 'package:three_js/three_js.dart' as three;

/// three_js 0.3.0 initializes native resources asynchronously. Defer disposal
/// until that operation completes, and prevent a delayed start after exit.
class SolarRenderer extends three.ThreeJS {
  SolarRenderer({
    required super.settings,
    required super.setup,
    required super.onSetupComplete,
    required this.onFailure,
  });
  final void Function(Object) onFailure;
  bool _starting = false;
  bool _closed = false;
  @override
  Future<void> initPlatformState() async {
    if (_closed) return;
    _starting = true;
    try {
      await super.initPlatformState();
    } catch (error) {
      visible = false;
      if (!_closed) onFailure(error);
    } finally {
      _starting = false;
      if (_closed) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    visible = false;
    ticker?.stop();
    if (!_starting) super.dispose();
  }
}
