import 'package:flutter/foundation.dart';

class PlanetData {
  const PlanetData(
    this.name,
    this.radius,
    this.orbit,
    this.period,
    this.spin,
    this.color,
  );
  final String name;
  final double radius, orbit, period, spin;
  final int color;
}

const planets = [
  PlanetData('水星', .42, 5, 12, .25, 0xa49b91),
  PlanetData('金星', .7, 7.5, 19, -.15, 0xdcb275),
  PlanetData('地球', .76, 10, 28, 1.2, 0x438bd1),
  PlanetData('火星', .54, 13, 40, 1.1, 0xc46843),
  PlanetData('木星', 1.65, 17.5, 65, 2.4, 0xd4b38c),
  PlanetData('土星', 1.38, 23, 90, 2.1, 0xdac997),
  PlanetData('天王星', 1, 29, 125, -.9, 0x91d8de),
  PlanetData('海王星', .97, 35, 160, 1.3, 0x416ed7),
];

class SolarSystemModel extends ChangeNotifier {
  int focusRevision = 0;
  bool panMode = false;
  int focusIndex = -2; // -2 overview, -1 Sun, 0–7 planets, 8 Moon
  double get moonAngle => time * 6.283185307 / 5;
  bool paused = false;
  bool active = true;
  bool showLabels = true;
  bool showOrbits = true;
  double speed = 1;
  double time = 0;
  void advance(double seconds) {
    if (paused || !active || !seconds.isFinite || seconds <= 0) return;
    time += seconds * speed;
  }

  double orbitAngle(int index) =>
      index * .83 + time * 6.283185307 / planets[index].period;
  double spinAngle(int index) => time * planets[index].spin;
  void refresh() => notifyListeners();
}
