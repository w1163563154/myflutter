import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/solar_system_model.dart';

void main() {
  test('moon orbits Earth and pauses with the simulation', () {
    final model = SolarSystemModel();
    final initial = model.moonAngle;
    model.advance(1);
    expect(model.moonAngle, isNot(initial));
    model.paused = true;
    final paused = model.moonAngle;
    model.advance(2);
    expect(model.moonAngle, paused);
  });
  test(
    'motion advances independently and respects pause, speed and background',
    () {
      final model = SolarSystemModel();
      final initial = model.orbitAngle(2);
      model.advance(1);
      expect(model.orbitAngle(2), isNot(initial));
      expect(model.spinAngle(2), isNot(model.orbitAngle(2)));
      model.paused = true;
      final stopped = model.time;
      model.advance(1);
      expect(model.time, stopped);
      model.paused = false;
      model.active = false;
      model.advance(1);
      expect(model.time, stopped);
      model.active = true;
      model.speed = 4;
      model.advance(0.1);
      expect(model.time, closeTo(stopped + .4, .00001));
    },
  );
}
