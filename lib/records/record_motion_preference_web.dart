import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('window')
external _BrowserWindow get _window;

extension type _BrowserWindow(JSObject _) implements JSObject {
  external _MediaQueryList matchMedia(String query);
}

extension type _MediaQueryList(JSObject _) implements JSObject {
  external bool get matches;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

ValueNotifier<bool> watchReducedMotion() => _BrowserMotionPreference(
  _window.matchMedia('(prefers-reduced-motion: reduce)'),
);

class _BrowserMotionPreference extends ValueNotifier<bool> {
  _BrowserMotionPreference(this._query) : super(_query.matches) {
    _onChange = ((JSAny? _) {
      value = _query.matches;
    }).toJS;
    _query.addEventListener('change', _onChange);
  }

  final _MediaQueryList _query;
  late final JSFunction _onChange;

  @override
  void dispose() {
    _query.removeEventListener('change', _onChange);
    super.dispose();
  }
}
