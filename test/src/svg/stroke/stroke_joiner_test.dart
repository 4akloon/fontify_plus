import 'dart:math' as math;

import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_joiner.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// [Vector2] is float32-backed, so seven significant digits is the ceiling.
const _kEpsilon = 1e-5;

/// A right-angle corner at the origin.
///
/// The stroke arrives travelling +x and leaves travelling +y. Offsetting to
/// the left puts the offset edges at y = 1, so this is the *inner* side: the
/// two edges overrun each other.
List<Cubic> joinInner({
  LineJoin join = LineJoin.miter,
  double miterLimit = 4,
}) =>
    StrokeJoiner(
      StrokeProperties(width: 2, join: join, miterLimit: miterLimit),
    ).join(
      vertex: Vector2.zero(),
      from: Vector2(0, 1),
      to: Vector2(-1, 0),
      incoming: Vector2(1, 0),
      outgoing: Vector2(0, 1),
    );

/// The same corner taken the other way, so the offset edges pull apart.
///
/// from is vertex + radius * leftNormal(incoming) = (0, 1), not (0, -1) —
/// confirmed against a real offset chain (CubicOffsetter on an actual right
/// turn), the same relationship joinInner's from/incoming already satisfy.
/// A round join computed from from/to alone, as this codebase's did before
/// deriving its sweep from incoming/outgoing, cannot tell such an
/// inconsistency from real geometry; deriving the sweep from the tangents
/// can, which is how this got caught.
List<Cubic> joinOuter({
  LineJoin join = LineJoin.miter,
  double miterLimit = 4,
}) =>
    StrokeJoiner(
      StrokeProperties(width: 2, join: join, miterLimit: miterLimit),
    ).join(
      vertex: Vector2.zero(),
      from: Vector2(0, 1),
      to: Vector2(1, 0),
      incoming: Vector2(1, 0),
      outgoing: Vector2(0, -1),
    );

Iterable<Vector2> samples(List<Cubic> chain) sync* {
  for (final segment in chain) {
    for (var i = 0; i <= 8; i++) {
      yield segment.pointAt(i / 8);
    }
  }
}

void main() {
  group('StrokeJoiner', () {
    test('bridges nothing when the two edges already meet', () {
      final joined = const StrokeJoiner(StrokeProperties(width: 2)).join(
        vertex: Vector2.zero(),
        from: Vector2(0, 1),
        to: Vector2(0, 1),
        incoming: Vector2(1, 0),
        outgoing: Vector2(0, 1),
      );

      expect(joined, isEmpty);
    });

    test('bridges a tangential junction with a straight line', () {
      // A curve written as a chain of cubics meets itself tangentially at each
      // junction. Inserting join geometry there would litter the outline with
      // degenerate arcs.
      final joined =
          const StrokeJoiner(
            StrokeProperties(width: 2, join: LineJoin.round),
          ).join(
            vertex: Vector2(5, 0),
            from: Vector2(5, 1),
            to: Vector2(5.0001, 1),
            incoming: Vector2(1, 0),
            outgoing: Vector2(1, 0),
          );

      expect(joined, hasLength(1));
      expect(joined.single.curvatureAt(0.5).abs(), lessThan(_kEpsilon));
    });

    test('starts and ends exactly where it was told to', () {
      for (final join in LineJoin.values) {
        for (final geometry in [joinInner(join: join), joinOuter(join: join)]) {
          expect(geometry, isNotEmpty);
        }

        final outer = joinOuter(join: join);
        expect(outer.first.p0.distanceTo(Vector2(0, 1)), lessThan(_kEpsilon));
        expect(outer.last.p3.distanceTo(Vector2(1, 0)), lessThan(_kEpsilon));
      }
    });

    test('is a connected chain', () {
      for (final join in LineJoin.values) {
        final geometry = joinOuter(join: join);

        for (var i = 1; i < geometry.length; i++) {
          expect(
            geometry[i - 1].p3.distanceTo(geometry[i].p0),
            lessThan(_kEpsilon),
          );
        }
      }
    });

    test('bevel closes the outer gap with one straight line', () {
      final geometry = joinOuter(join: LineJoin.bevel);

      expect(geometry, hasLength(1));
      expect(geometry.single.curvatureAt(0.5).abs(), lessThan(_kEpsilon));
    });

    test('miter runs the outer edges out to where they cross', () {
      final geometry = joinOuter(join: LineJoin.miter);

      expect(geometry, hasLength(2));
      expect(
        geometry.first.p3.distanceTo(Vector2(1, 1)),
        lessThan(_kEpsilon),
        reason: 'the tangents of a right angle cross at the corner offset',
      );
    });

    test('miter falls back to a bevel past the miter limit', () {
      // The miter length here is sqrt(2) radii; a limit below that must clip.
      expect(joinOuter(miterLimit: 1.2), hasLength(1));
      expect(joinOuter(miterLimit: 2), hasLength(2));
    });

    test('round fills the outer gap with an arc of the stroke radius', () {
      final geometry = joinOuter(join: LineJoin.round);

      for (final point in samples(geometry)) {
        expect(point.length, closeTo(1, 0.01));
      }
    });

    test('round treats an exact 90° turn as one segment, not two', () {
      // incoming/outgoing run through the same tangentAt(t).normalized()
      // chain a real offset chain uses (Cubic.line, not a hand-picked exact
      // vector), at an orientation empirically confirmed to push the
      // recovered sweep a hair above pi/2 — the same float32-rounding
      // mechanism that costs both example/svg/arrow_right.svg's and
      // example/svg/check.svg's exact-90° round joins a doubled segment
      // count (see arc_test.dart's equivalent regression on arcToCubics
      // directly).
      const theta = 0.0173;
      const outAngle = theta - math.pi / 2;
      final vertex = Vector2(math.cos(theta), math.sin(theta));
      final next = vertex + Vector2(math.cos(outAngle), math.sin(outAngle));

      final incoming = Cubic.line(Vector2.zero(), vertex).tangentAt(1);
      final outgoing = Cubic.line(vertex, next).tangentAt(0);

      const stroke = StrokeProperties(width: 2, join: LineJoin.round);
      final from = vertex + leftNormal(incoming) * stroke.radius;
      final to = vertex + leftNormal(outgoing) * stroke.radius;

      final geometry = const StrokeJoiner(stroke).join(
        vertex: vertex,
        from: from,
        to: to,
        incoming: incoming,
        outgoing: outgoing,
      );

      expect(geometry, hasLength(1));
    });

    test('round takes the short way round', () {
      final geometry = joinOuter(join: LineJoin.round);
      final sweep = samples(geometry)
          .map((p) => math.atan2(p.y, p.x))
          .reduce((a, b) => a.abs() > b.abs() ? a : b);

      expect(sweep.abs(), lessThanOrEqualTo(math.pi / 2 + _kEpsilon));
    });

    test('trims the inner side back to where the tangents cross', () {
      // Leaving the overrun folds a reversed loop into the contour, which the
      // nonzero rule punches out as a hole.
      final geometry = joinInner();

      expect(geometry, hasLength(2));
      expect(
        geometry.first.p3.distanceTo(Vector2(-1, 1)),
        lessThan(_kEpsilon),
      );
    });

    test('abandons an inner crossing that sits far from the corner', () {
      // The two edges converge so slowly that they meet fifteen radii away.
      // Running out to that point would distort far more than the overlap it
      // removes, so the joiner bridges straight across instead.
      final geometry = const StrokeJoiner(StrokeProperties(width: 2)).join(
        vertex: Vector2.zero(),
        from: Vector2(0, 1),
        to: Vector2(10, 0.5),
        incoming: Vector2(1, 0),
        outgoing: Vector2(0.995, 0.0995),
      );

      expect(geometry, hasLength(1));
      expect(
        geometry.single.p3.distanceTo(Vector2(10, 0.5)),
        lessThan(_kEpsilon),
      );
    });

    test('bridges straight across when the inner tangents never cross', () {
      // Anti-parallel tangents have no crossing at all.
      final geometry = const StrokeJoiner(StrokeProperties(width: 2)).join(
        vertex: Vector2.zero(),
        from: Vector2(0, 1),
        to: Vector2(5, 1),
        incoming: Vector2(1, 0),
        outgoing: Vector2(1, 0.0001),
      );

      expect(geometry, hasLength(1));
    });

    test('the join style does not affect the inner side', () {
      for (final join in LineJoin.values) {
        expect(joinInner(join: join).length, joinInner().length);
      }
    });
  });
}
