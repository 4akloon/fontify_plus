import 'package:fontify_plus/src/svg/geometry/line_intersection.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// [Vector2] is float32-backed, so seven significant digits is the ceiling.
const _kEpsilon = 1e-5;

void main() {
  group('lineIntersection', () {
    test('finds where two lines cross', () {
      final crossing = lineIntersection(
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(3, -2),
        Vector2(0, 1),
      );

      expect(crossing, isNotNull);
      expect(crossing!.x, closeTo(3, _kEpsilon));
      expect(crossing.y, closeTo(0, _kEpsilon));
    });

    test('extends the lines beyond the points given', () {
      // The crossing is behind both starting points; these are lines, not
      // segments, which is what a miter join needs.
      final crossing = lineIntersection(
        Vector2(10, 0),
        Vector2(1, 0),
        Vector2(0, 10),
        Vector2(0, 1),
      );

      expect(crossing!.x, closeTo(0, _kEpsilon));
      expect(crossing.y, closeTo(0, _kEpsilon));
    });

    test('returns null for parallel lines', () {
      expect(
        lineIntersection(
          Vector2(0, 0),
          Vector2(1, 0),
          Vector2(0, 5),
          Vector2(1, 0),
        ),
        isNull,
      );
    });

    test('returns null for anti-parallel lines', () {
      expect(
        lineIntersection(
          Vector2(0, 0),
          Vector2(1, 0),
          Vector2(0, 5),
          Vector2(-1, 0),
        ),
        isNull,
      );
    });

    test('returns null for coincident lines', () {
      // Infinitely many crossings is no more usable than none.
      expect(
        lineIntersection(
          Vector2(0, 0),
          Vector2(1, 0),
          Vector2(4, 0),
          Vector2(1, 0),
        ),
        isNull,
      );
    });
  });
}
