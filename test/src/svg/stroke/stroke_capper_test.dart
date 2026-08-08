import 'dart:math' as math;

import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_capper.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// [Vector2] is float32-backed, so seven significant digits is the ceiling.
const _kEpsilon = 1e-5;

/// The stroke runs along +x and ends at the origin, so the cap spans from
/// (0, 1) to (0, -1) and may bulge toward +x.
List<Cubic> capAt(LineCap cap) => StrokeCapper(
  StrokeProperties(width: 2, cap: cap),
).cap(Vector2.zero(), Vector2(1, 0));

/// Points sampled along a chain, for measuring how far it reaches.
Iterable<Vector2> samples(List<Cubic> chain) sync* {
  for (final segment in chain) {
    for (var i = 0; i <= 10; i++) {
      yield segment.pointAt(i / 10);
    }
  }
}

void main() {
  group('StrokeCapper', () {
    for (final cap in LineCap.values) {
      test('$cap spans the full stroke width', () {
        final geometry = capAt(cap);

        expect(geometry.first.p0.y, closeTo(1, _kEpsilon));
        expect(geometry.last.p3.y, closeTo(-1, _kEpsilon));
      });

      test('$cap is a connected chain', () {
        final geometry = capAt(cap);

        for (var i = 1; i < geometry.length; i++) {
          expect(
            geometry[i - 1].p3.distanceTo(geometry[i].p0),
            lessThan(_kEpsilon),
          );
        }
      });
    }

    test('butt stops squarely at the endpoint', () {
      for (final point in samples(capAt(LineCap.butt))) {
        expect(point.x, closeTo(0, _kEpsilon));
      }
    });

    test('round bulges out by the radius, not inward', () {
      // Both sweep directions are equally short at half a turn, so the sign
      // cannot be recovered from the end points alone — getting it wrong put
      // the cap inside the stroke.
      final reach = samples(
        capAt(LineCap.round),
      ).map((p) => p.x).reduce(math.max);

      expect(reach, closeTo(1, 0.01));
      expect(
        samples(capAt(LineCap.round)).map((p) => p.x).reduce(math.min),
        greaterThan(-_kEpsilon),
      );
    });

    test('round stays on the circle of radius 1', () {
      for (final point in samples(capAt(LineCap.round))) {
        expect(point.length, closeTo(1, 0.01));
      }
    });

    test('square extends by the radius and turns two corners', () {
      final geometry = capAt(LineCap.square);

      expect(geometry, hasLength(3));
      expect(
        samples(geometry).map((p) => p.x).reduce(math.max),
        closeTo(1, _kEpsilon),
      );
    });

    test('a wider stroke caps proportionally further out', () {
      final wide = const StrokeCapper(
        StrokeProperties(width: 10, cap: LineCap.square),
      ).cap(Vector2.zero(), Vector2(1, 0));

      expect(wide.first.p0.y, closeTo(5, _kEpsilon));
      expect(
        samples(wide).map((p) => p.x).reduce(math.max),
        closeTo(5, _kEpsilon),
      );
    });

    test('follows the direction it is given', () {
      final upward = const StrokeCapper(
        StrokeProperties(width: 2, cap: LineCap.square),
      ).cap(Vector2.zero(), Vector2(0, 1));

      expect(
        samples(upward).map((p) => p.y).reduce(math.max),
        closeTo(1, _kEpsilon),
      );
    });
  });
}
