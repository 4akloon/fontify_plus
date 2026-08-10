import 'dart:math' as math;

import 'package:fontify_plus/src/svg/geometry/arc.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// [Vector2] is float32-backed, so seven significant digits is the ceiling.
const _kEpsilon = 1e-5;

void main() {
  group('arcToCubics', () {
    test('splits a full turn into quarter arcs', () {
      expect(arcToCubics(Vector2.zero(), 1, 0, 2 * math.pi), hasLength(4));
    });

    test('never spans more than a quarter turn', () {
      // Error grows sharply past a quarter, so the count is what keeps the
      // approximation honest.
      for (final sweep in [0.1, 1.0, math.pi, 5.0, 2 * math.pi]) {
        for (final segment in arcToCubics(Vector2.zero(), 1, 0, sweep)) {
          final start = segment.tangentAt(0);
          final end = segment.tangentAt(1);

          expect(start.dot(end), greaterThan(-_kEpsilon));
        }
      }
    });

    test('stays on the circle', () {
      final arc = arcToCubics(Vector2(3, 4), 2, 0.5, math.pi);

      for (final segment in arc) {
        for (var i = 0; i <= 20; i++) {
          expect(
            segment.pointAt(i / 20).distanceTo(Vector2(3, 4)),
            closeTo(2, 0.001),
            reason: 'a cubic approximation of an arc must hug the circle',
          );
        }
      }
    });

    test('starts and ends at the requested angles', () {
      const start = 0.4;
      const sweep = 1.9;

      final arc = arcToCubics(Vector2(1, 1), 3, start, sweep);

      expect(
        arc.first.p0.distanceTo(
          Vector2(1, 1) + Vector2(math.cos(start), math.sin(start)) * 3,
        ),
        lessThan(_kEpsilon),
      );
      expect(
        arc.last.p3.distanceTo(
          Vector2(1, 1) +
              Vector2(math.cos(start + sweep), math.sin(start + sweep)) * 3,
        ),
        lessThan(_kEpsilon),
      );
    });

    test('joins its segments end to end', () {
      final arc = arcToCubics(Vector2.zero(), 1, 0, 2 * math.pi);

      for (var i = 1; i < arc.length; i++) {
        expect(arc[i - 1].p3.distanceTo(arc[i].p0), lessThan(_kEpsilon));
      }
    });

    test('runs the requested way round', () {
      final clockwise = arcToCubics(Vector2.zero(), 1, 0, -math.pi);
      final counter = arcToCubics(Vector2.zero(), 1, 0, math.pi);

      expect(clockwise.first.pointAt(0.5).y, lessThan(0));
      expect(counter.first.pointAt(0.5).y, greaterThan(0));
    });

    test('returns nothing for a zero sweep', () {
      expect(arcToCubics(Vector2.zero(), 1, 0, 0), isEmpty);
    });

    test('returns nothing for a zero radius', () {
      expect(arcToCubics(Vector2.zero(), 0, 0, math.pi), isEmpty);
    });

    test('treats a sweep landing a hair above a quarter turn as one', () {
      // A quarter turn recovered from atan2 of two independently-rounded
      // float32 tangents lands a hair above pi/2 close to as often as below
      // it. Both of this package's own round-joined right angles hit
      // exactly this — see stroke_joiner_test.dart's equivalent regression
      // at the join level.
      const sweep = math.pi / 2 + 5e-8;

      expect(arcToCubics(Vector2.zero(), 1, 0, sweep), hasLength(1));
    });

    test('absorbs the worst catastrophic-cancellation noise measured', () {
      // A corner far from the origin makes tangentAt's p1 - p0 catastrophic
      // cancellation, not just orientation/leg-length rounding — see
      // arc.dart's _kSweepRatioEpsilon doc. Sweeping vertex offsets 0-2000
      // and leg lengths 0.5-50 through the real tangent chain found a worst
      // positive excess of 3.39e-4; this is that worst case, expressed
      // directly as a sweep, with no margin left to the epsilon.
      const sweep = math.pi / 2 * (1 + 3.39e-4);

      expect(arcToCubics(Vector2.zero(), 1, 0, sweep), hasLength(1));
    });

    test('still spans two for a sweep genuinely past a quarter turn', () {
      // 91 degrees: the epsilon that absorbs float32 rounding noise must not
      // be wide enough to also absorb a real extra degree of turn.
      const sweep = 91 * math.pi / 180;

      expect(arcToCubics(Vector2.zero(), 1, 0, sweep), hasLength(2));
    });

    test('still spans two for an exact half turn (a round cap)', () {
      // A round cap's sweep is the literal -pi, ratio exactly 2.0. An
      // epsilon wide enough to eat into that would flatten every round cap
      // in the package.
      expect(arcToCubics(Vector2.zero(), 1, 0, -math.pi), hasLength(2));
    });

    test('never rounds a tiny-but-nonzero sweep down to zero segments', () {
      // Subtracting the epsilon from the ratio before ceil-ing can itself
      // produce a negative number for a sweep this small (ratio is far
      // below even the epsilon), which without the floor would raw-ceil to
      // 0 and divide by it. Confirmed these three sweeps all raw-ceil to 0
      // without the floor: 2e-12 (just above the zero-sweep guard above),
      // 1e-9, and 1e-7.
      for (final sweep in [1e-9, 1e-7]) {
        expect(arcToCubics(Vector2.zero(), 1, 0, sweep), hasLength(1));
      }
    });
  });

  group('shortSweep', () {
    test('leaves a sweep within half a turn alone', () {
      for (final sweep in [0.0, 1.0, -1.0, math.pi, -math.pi]) {
        expect(shortSweep(sweep), closeTo(sweep, 1e-12));
      }
    });

    test('takes the other way round when that is shorter', () {
      expect(shortSweep(1.5 * math.pi), closeTo(-0.5 * math.pi, 1e-12));
      expect(shortSweep(-1.5 * math.pi), closeTo(0.5 * math.pi, 1e-12));
    });

    test('always lands within half a turn', () {
      for (var i = -10; i <= 10; i++) {
        expect(shortSweep(i * 1.3).abs(), lessThanOrEqualTo(math.pi + 1e-12));
      }
    });

    test('preserves the angle it describes', () {
      for (var i = -10; i <= 10; i++) {
        final sweep = i * 1.3;
        final difference = (shortSweep(sweep) - sweep) / (2 * math.pi);

        expect(difference, closeTo(difference.roundToDouble(), 1e-12));
      }
    });
  });
}
