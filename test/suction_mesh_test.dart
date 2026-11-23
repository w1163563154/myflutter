import 'package:flutter_test/flutter_test.dart';
import 'package:myflutter/suction_mesh.dart';

void main() {
  test(
    'arbitrary targets including outside image converge without overflow',
    () {
      for (final target in [
        const Offset(-1, -2),
        const Offset(.5, .5),
        const Offset(2, 3),
      ]) {
        for (final point in [
          Offset.zero,
          const Offset(1, 0),
          const Offset(0, 1),
          const Offset(1, 1),
        ]) {
          expect(suctionPoint(point, 0, target: target), point);
          expect(suctionPoint(point, 1, target: target), target);
          for (final t in [.1, .5, .9, .999]) {
            final p = suctionPoint(point, t, target: target);
            expect(p.dx.isFinite && p.dy.isFinite, isTrue);
            expect(
              p.dx,
              inInclusiveRange(
                point.dx < target.dx ? point.dx : target.dx,
                point.dx > target.dx ? point.dx : target.dx,
              ),
            );
            expect(
              p.dy,
              inInclusiveRange(
                point.dy < target.dy ? point.dy : target.dy,
                point.dy > target.dy ? point.dy : target.dy,
              ),
            );
          }
        }
      }
    },
  );
  test('mesh preserves rectangle at start and collapses at end', () {
    for (var y = 0; y <= 10; y++) {
      for (var x = 0; x <= 10; x++) {
        final point = Offset(x / 10, y / 10);
        expect(suctionPoint(point, 0), point);
        expect(suctionPoint(point, 1), const Offset(1, 1));
        for (final t in [.1, .3, .5, .8, .99]) {
          final moved = suctionPoint(point, t);
          expect(moved.dx.isFinite && moved.dy.isFinite, isTrue);
          expect(moved.dx, inInclusiveRange(0, 1));
          expect(moved.dy, inInclusiveRange(0, 1));
        }
      }
    }
  });
  test('corner leads while distant edge bends nonuniformly', () {
    const near = Offset(.8, .8), far = Offset(0, 0);
    final n = suctionPoint(near, .4), f = suctionPoint(far, .4);
    expect(
      (n - const Offset(1, 1)).distance / (near - const Offset(1, 1)).distance,
      lessThan(
        (f - const Offset(1, 1)).distance / (far - const Offset(1, 1)).distance,
      ),
    );
    final mid = suctionPoint(const Offset(.5, 0), .5);
    final a = suctionPoint(Offset.zero, .5);
    final b = suctionPoint(const Offset(1, 0), .5);
    expect((mid - (a + b) / 2).distance, greaterThan(.015));
  });
}
