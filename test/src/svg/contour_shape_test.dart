import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/outline_builder.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Cubic _line(double x0, double y0, double x1, double y1) =>
    Cubic.line(Vector2(x0, y0), Vector2(x1, y1));

/// A square, all straight sides.
final _square = [
  [
    _line(0, 0, 10, 0),
    _line(10, 0, 10, 10),
    _line(10, 10, 0, 10),
    _line(0, 10, 0, 0),
  ],
];

/// The same ring with one side bowed out.
final _bowed = [
  [
    Cubic(Vector2(0, 0), Vector2(3, -4), Vector2(7, -4), Vector2(10, 0)),
    _line(10, 0, 10, 10),
    _line(10, 10, 0, 10),
    _line(0, 10, 0, 0),
  ],
];

/// A triangle whose closing segment lands exactly back on the start.
final _closedTriangle = [
  [_line(0, 0, 10, 0), _line(10, 0, 10, 10), _line(10, 10, 0, 0)],
];

/// The same triangle, but its closing segment stops short of the start by
/// 1e-6 — far past kPointEpsilon (1e-9), and comfortably inside the float32
/// rounding band Task 6 measured stroke offsetting can introduce (up to
/// 6.3e-4). Every segment classifies the same as [_closedTriangle]'s, so a
/// shape planned from one is a legal replay target for the other.
final _openTriangle = [
  [_line(0, 0, 10, 0), _line(10, 0, 10, 10), _line(10, 10, 1e-6, 1e-6)],
];

void main() {
  group('planContourShape', () {
    test('marks straight segments straight and curved ones curved', () {
      expect(planContourShape(_square, height: 10).straight, [
        [true, true, true, true],
      ]);
      expect(planContourShape(_bowed, height: 10).straight, [
        [false, true, true, true],
      ]);
    });

    test('a recorded shape forces the point count it recorded', () {
      // The bowed contour's own shape spends three points on its curve.
      final own = outlinesFromContours(
        _bowed,
        height: 10,
        shape: planContourShape(_bowed, height: 10),
      );

      // Forced to the square's shape, the same geometry must spend one.
      final forced = outlinesFromContours(
        _bowed,
        height: 10,
        shape: planContourShape(_square, height: 10),
      );

      expect(
        own.single.pointList.length,
        greaterThan(forced.single.pointList.length),
      );
    });

    test('forces a recorded drop rather than re-deciding it from geometry', () {
      // Whether a closing point repeats its start is exactly the kind of
      // live-coordinate check ContourShape exists to freeze. A shape that
      // recorded the drop must force it on replay even when the replayed
      // contour's own closing point no longer coincides with its start —
      // otherwise two masters built from the same recorded shape could
      // still disagree on point count.
      final reference = outlinesFromContours(
        _closedTriangle,
        height: 10,
        shape: planContourShape(_closedTriangle, height: 10),
      ).single;

      final replayed = outlinesFromContours(
        _openTriangle,
        height: 10,
        shape: planContourShape(_closedTriangle, height: 10),
      ).single;

      expect(replayed.pointList.length, reference.pointList.length);
    });
  });
}
