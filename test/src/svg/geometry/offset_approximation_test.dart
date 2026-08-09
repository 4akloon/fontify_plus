import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/geometry/offset_approximation.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// [Vector2] is float32-backed, so seven significant digits is the ceiling.
const _kEpsilon = 1e-5;

/// A symmetric arch. Its end tangents are anti-parallel, which is the
/// degenerate case for the 2x2 solve.
// ignore: unused_element
final _arch = Cubic(
  Vector2(0, 0),
  Vector2(0, 5),
  Vector2(10, 5),
  Vector2(10, 0),
);

/// A quarter turn. Its end tangents are perpendicular, so the solve is
/// well conditioned.
final _curve = Cubic(
  Vector2(0, 0),
  Vector2(0, 4),
  Vector2(4, 8),
  Vector2(8, 8),
);

void main() {
  group('offsetPointAt', () {
    test('sits exactly the given distance from the curve, on its left', () {
      const distance = 1.5;

      for (final t in [0.0, 0.25, 0.5, 1.0]) {
        final source = _curve.pointAt(t);
        final offset = offsetPointAt(_curve, t, distance);

        expect(offset.distanceTo(source), closeTo(distance, _kEpsilon));
        expect(
          (offset - source).dot(_curve.tangentAt(t)),
          closeTo(0, _kEpsilon),
          reason: 'the offset moves along the normal, not the tangent',
        );
      }
    });

    test('a negative distance offsets the other side', () {
      final left = offsetPointAt(_curve, 0.5, 2);
      final right = offsetPointAt(_curve, 0.5, -2);

      expect(left.distanceTo(right), closeTo(4, _kEpsilon));
    });
  });

  group('offsetChord', () {
    test('is the straight line between the offset end points', () {
      const distance = 0.75;
      final chord = offsetChord(_curve, distance);

      expect(
        chord.p0.distanceTo(offsetPointAt(_curve, 0, distance)),
        lessThan(_kEpsilon),
      );
      expect(
        chord.p3.distanceTo(offsetPointAt(_curve, 1, distance)),
        lessThan(_kEpsilon),
      );
      expect(chord.curvatureAt(0.5).abs(), lessThan(_kEpsilon));
    });
  });

  group('approximateOffset', () {
    test('keeps the end points exact', () {
      const distance = 0.5;
      final offset = approximateOffset(_curve, distance)!;

      expect(
        offset.p0.distanceTo(offsetPointAt(_curve, 0, distance)),
        lessThan(_kEpsilon),
      );
      expect(
        offset.p3.distanceTo(offsetPointAt(_curve, 1, distance)),
        lessThan(_kEpsilon),
      );
    });

    test('keeps the end tangents exact', () {
      const distance = 0.5;
      final offset = approximateOffset(_curve, distance)!;

      expect(
        offset.tangentAt(0).dot(_curve.tangentAt(0)),
        closeTo(1, _kEpsilon),
      );
      expect(
        offset.tangentAt(1).dot(_curve.tangentAt(1)),
        closeTo(1, _kEpsilon),
      );
    });

    test('passes through the true offset at the midpoint', () {
      // The constraint that keeps the approximation from bowing.
      const distance = 0.5;
      final offset = approximateOffset(_curve, distance)!;

      expect(
        offset.pointAt(0.5).distanceTo(offsetPointAt(_curve, 0.5, distance)),
        lessThan(_kEpsilon),
      );
    });

    test(
      'falls back to the source spacing when the end tangents are parallel',
      () {
        // The 2x2 solve is singular here, so the midpoint constraint cannot be
        // met by a single cubic. Keeping the source's own control spacing gives
        // a usable starting shape that CubicOffsetter then subdivides; what
        // matters is that the end points stay exact and nothing blows up.
        const distance = 0.5;
        final offset = approximateOffset(_arch, distance)!;

        expect(
          offset.p0.distanceTo(offsetPointAt(_arch, 0, distance)),
          lessThan(_kEpsilon),
        );
        expect(
          offset.p3.distanceTo(offsetPointAt(_arch, 1, distance)),
          lessThan(_kEpsilon),
        );
        expect(
          offset.p0.distanceTo(offset.p1),
          closeTo(_arch.p0.distanceTo(_arch.p1), _kEpsilon),
        );
      },
    );

    test('handles parallel end tangents by translating', () {
      final line = Cubic.line(Vector2(0, 0), Vector2(10, 0));
      final offset = approximateOffset(line, 2)!;

      expect(offset.p0.y, closeTo(2, _kEpsilon));
      expect(offset.p3.y, closeTo(2, _kEpsilon));
      expect(offset.p3.x - offset.p0.x, closeTo(10, _kEpsilon));
    });

    test('gives up when the fit would fold a control point backwards', () {
      // Inside a turn tighter than the offset, the solve wants a negative
      // control distance, which would loop the curve. Null tells the caller to
      // subdivide instead of accepting a loop.
      final tight = Cubic(
        Vector2(0, 0),
        Vector2(0.3, 0),
        Vector2(0.6, 0.3),
        Vector2(0.6, 0.6),
      );

      expect(approximateOffset(tight, 5), isNull);
    });
  });

  group('maxOffsetDeviation', () {
    test('is zero for a curve that is already the offset', () {
      final offset = approximateOffset(_curve, 0)!;

      expect(maxOffsetDeviation(_curve, offset, 0), lessThan(_kEpsilon));
    });

    test('measures how far a candidate strays', () {
      final chord = offsetChord(_curve, 1);

      // The straight chord cuts across the curve's bulge, so it must be well
      // off the true offset in the middle.
      expect(maxOffsetDeviation(_curve, chord, 1), greaterThan(1));
    });
  });
}
