import 'dart:math' as math;

import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// How much floating-point slack these assertions allow.
///
/// [Vector2] stores its components in a `Float32List`, so the whole geometry
/// pipeline carries about seven significant digits — not the fifteen a `double`
/// would. Anything tighter than this fails on rounding alone.
const _kEpsilon = 1e-5;

/// A quarter-circle-ish arc, curved enough that its derivatives are all
/// non-degenerate.
final _curve = Cubic(
  Vector2(0, 0),
  Vector2(0, 5),
  Vector2(10, 5),
  Vector2(10, 0),
);

void main() {
  group('Cubic.line', () {
    test('interpolates linearly', () {
      final line = Cubic.line(Vector2(0, 0), Vector2(9, 3));

      for (final t in [0.0, 0.25, 0.5, 1.0]) {
        expect(line.pointAt(t).x, closeTo(9 * t, _kEpsilon));
        expect(line.pointAt(t).y, closeTo(3 * t, _kEpsilon));
      }
    });

    test('spaces its controls evenly, so it stays straight under splitting',
        () {
      final line = Cubic.line(Vector2(0, 0), Vector2(9, 0));
      final (left, right) = line.splitAt(0.5);

      for (final half in [left, right]) {
        for (final control in [half.p1, half.p2]) {
          expect(control.y, closeTo(0, _kEpsilon));
        }
      }
    });
  });

  group('pointAt', () {
    test('hits the end points exactly', () {
      expect(_curve.pointAt(0), _curve.p0);
      expect(_curve.pointAt(1), _curve.p3);
    });

    test('agrees with the explicit Bernstein form', () {
      const t = 0.3;
      const u = 1 - t;

      final expected = _curve.p0 * (u * u * u) +
          _curve.p1 * (3 * u * u * t) +
          _curve.p2 * (3 * u * t * t) +
          _curve.p3 * (t * t * t);

      expect(_curve.pointAt(t).distanceTo(expected), lessThan(_kEpsilon));
    });
  });

  group('tangentAt', () {
    test('is a unit vector', () {
      for (final t in [0.0, 0.5, 1.0]) {
        expect(_curve.tangentAt(t).length, closeTo(1, _kEpsilon));
      }
    });

    test('points along the first control leg at the start', () {
      final tangent = _curve.tangentAt(0);

      expect(tangent.x, closeTo(0, _kEpsilon));
      expect(tangent.y, closeTo(1, _kEpsilon));
    });

    test('falls back when the first control coincides with the start', () {
      // A curve written with a flat start: the derivative vanishes at t=0, so
      // a naive normalize would divide by zero.
      final flat = Cubic(
        Vector2(0, 0),
        Vector2(0, 0),
        Vector2(5, 0),
        Vector2(10, 0),
      );

      final tangent = flat.tangentAt(0);

      expect(tangent.length, closeTo(1, _kEpsilon));
      expect(tangent.x, closeTo(1, _kEpsilon));
    });

    test('never returns a zero vector, even for a degenerate curve', () {
      final point = Cubic(
        Vector2.zero(),
        Vector2.zero(),
        Vector2.zero(),
        Vector2.zero(),
      );

      expect(point.tangentAt(0.5).length, closeTo(1, _kEpsilon));
    });
  });

  group('curvatureAt', () {
    test('matches a circle of known radius', () {
      // A single cubic approximating a quarter circle of radius 10, whose
      // curvature is 1/10 throughout.
      const handle = 4 / 3 * 0.41421356237; // 4/3 tan(pi/8)
      final quarter = Cubic(
        Vector2(10, 0),
        Vector2(10, 10 * handle),
        Vector2(10 * handle, 10),
        Vector2(0, 10),
      );

      expect(quarter.curvatureAt(0.5).abs(), closeTo(0.1, 0.001));
    });

    test('is zero along a straight segment', () {
      final line = Cubic.line(Vector2(0, 0), Vector2(10, 4));

      for (final t in [0.0, 0.5, 1.0]) {
        expect(line.curvatureAt(t).abs(), lessThan(_kEpsilon));
      }
    });

    test('is signed by which way the curve turns', () {
      final left = Cubic(
        Vector2(0, 0),
        Vector2(0, 5),
        Vector2(10, 5),
        Vector2(10, 0),
      );

      expect(
          left.curvatureAt(0.5) * left.reversed.curvatureAt(0.5), lessThan(0));
    });

    test('is zero where the curve does not move', () {
      final point = Cubic(
        Vector2.zero(),
        Vector2.zero(),
        Vector2.zero(),
        Vector2.zero(),
      );

      expect(point.curvatureAt(0.5), 0);
    });
  });

  group('splitAt', () {
    test('the halves together trace the original', () {
      final (left, right) = _curve.splitAt(0.4);

      expect(left.p0, _curve.p0);
      expect(right.p3, _curve.p3);
      expect(left.p3.distanceTo(right.p0), lessThan(_kEpsilon));

      for (var i = 0; i <= 20; i++) {
        final t = i / 20;

        expect(
          left.pointAt(t).distanceTo(_curve.pointAt(t * 0.4)),
          lessThan(_kEpsilon),
        );
        expect(
          right.pointAt(t).distanceTo(_curve.pointAt(0.4 + t * 0.6)),
          lessThan(_kEpsilon),
        );
      }
    });
  });

  group('reversed', () {
    test('traces the same geometry backwards', () {
      final reversed = _curve.reversed;

      for (var i = 0; i <= 10; i++) {
        final t = i / 10;

        expect(
          reversed.pointAt(t).distanceTo(_curve.pointAt(1 - t)),
          lessThan(_kEpsilon),
        );
      }
    });

    test('flips the tangent', () {
      expect(
        _curve.reversed.tangentAt(0).dot(_curve.tangentAt(1)),
        closeTo(-1, _kEpsilon),
      );
    });
  });

  group('leftNormal', () {
    test('is perpendicular and same length', () {
      final direction = Vector2(math.cos(0.7), math.sin(0.7));
      final normal = leftNormal(direction);

      expect(normal.dot(direction), closeTo(0, _kEpsilon));
      expect(normal.length, closeTo(direction.length, _kEpsilon));
    });

    test('turns a quarter turn counter-clockwise', () {
      final normal = leftNormal(Vector2(1, 0));

      expect(normal.x, closeTo(0, _kEpsilon));
      expect(normal.y, closeTo(1, _kEpsilon));
    });
  });
}
