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

/// Builds an exact-mathematical right-angle corner — vertex at ([vertexX],
/// [vertexY]), arriving at orientation [theta] over a leg of length [leg1],
/// leaving turned exactly -90° over a leg of length [leg2] — through the
/// same real chain a stroked offset uses (`Cubic.line(...).tangentAt`,
/// `leftNormal`), and returns [StrokeJoiner.join]'s round-join result for
/// it.
///
/// Unlike [joinOuter], the corner's own position is a parameter: a corner
/// pinned at the origin never exercises the catastrophic cancellation
/// `tangentAt`'s `p1 - p0` suffers when both points are large, closely
/// spaced float32 coordinates, which is what makes far-from-origin corners
/// noisier than near-origin ones at the same orientation (see arc.dart's
/// `_kSweepRatioEpsilon` doc).
List<Cubic> roundJoinAt({
  required double vertexX,
  required double vertexY,
  required double theta,
  required double leg1,
  required double leg2,
}) {
  final p0 = Vector2(
    vertexX - leg1 * math.cos(theta),
    vertexY - leg1 * math.sin(theta),
  );
  final vertex = Vector2(vertexX, vertexY);
  final outAngle = theta - math.pi / 2;
  final p2 = Vector2(
    vertexX + leg2 * math.cos(outAngle),
    vertexY + leg2 * math.sin(outAngle),
  );

  final incoming = Cubic.line(p0, vertex).tangentAt(1);
  final outgoing = Cubic.line(vertex, p2).tangentAt(0);

  const stroke = StrokeProperties(width: 2, join: LineJoin.round);
  final from = vertex + leftNormal(incoming) * stroke.radius;
  final to = vertex + leftNormal(outgoing) * stroke.radius;

  return const StrokeJoiner(stroke).join(
    vertex: vertex,
    from: from,
    to: to,
    incoming: incoming,
    outgoing: outgoing,
  );
}

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
      // from and to are not free parameters: an offset point is
      // vertex + radius * leftNormal(tangent), so equal tangents put both at
      // the same place and there is nothing to bridge. Stating the corner
      // that way round — rather than passing from == to next to tangents a
      // quarter turn apart, which no offset chain can produce — is what
      // joinOuter's own doc comment warns is otherwise untellable from real
      // geometry.
      const stroke = StrokeProperties(width: 2);
      final vertex = Vector2(5, 3);
      final tangent = Vector2(1, 0);
      final offset = vertex + leftNormal(tangent) * stroke.radius;

      final joined = const StrokeJoiner(stroke).join(
        vertex: vertex,
        from: offset,
        to: offset,
        incoming: tangent,
        outgoing: tangent,
      );

      expect(joined, isEmpty);
    });

    test('bridges a tangential junction with a straight line', () {
      // A curve written as a chain of cubics meets itself tangentially at each
      // junction. Inserting join geometry there would litter the outline with
      // degenerate arcs.
      //
      // The turn has to be small enough to read as one curve and large enough
      // not to be treated as no turn at all: above kPointEpsilon in squared
      // tangent distance, below _kSmoothJunctionCosine in dot product.
      const stroke = StrokeProperties(width: 2, join: LineJoin.round);
      final vertex = Vector2(5, 0);
      final incoming = Vector2(1, 0);
      final outgoing = Vector2(math.cos(0.001), math.sin(0.001));

      final joined = const StrokeJoiner(stroke).join(
        vertex: vertex,
        from: vertex + leftNormal(incoming) * stroke.radius,
        to: vertex + leftNormal(outgoing) * stroke.radius,
        incoming: incoming,
        outgoing: outgoing,
      );

      expect(incoming.distanceToSquared(outgoing), greaterThan(1e-9));
      expect(incoming.dot(outgoing), greaterThan(0.9998));
      expect(joined, hasLength(1));
      expect(joined.single.curvatureAt(0.5).abs(), lessThan(_kEpsilon));
    });

    test('takes the same branch at every width, however the corner sits', () {
      // The property the whole plan/replay design rests on: two masters must
      // agree on every corner's segment count, or their point counts diverge
      // and they cannot carry variation deltas. A branch decided on from/to
      // rather than on the tangents does not have that property, because the
      // rounding in subtracting two float32 offset points is set by the
      // vertex's coordinate magnitude and so does not scale out of a
      // radius-relative threshold.
      //
      // Sampling has to be dense and aimed, not broad: whole-degree turns all
      // pass even unfixed. Each band below brackets one threshold —
      //   * ~0.0018°, where |incoming - outgoing|^2 meets kPointEpsilon and a
      //     junction reads as coincident rather than merely smooth;
      //   * ~151.045°, where the crossing reaches four radii, which is both
      //     _kMaxInnerCrossingRadii and the default miter limit.
      // Unfixed, this finds 324 flips; a whole-degree sweep over the same
      // range and widths finds none.
      //
      // The far-from-origin vertices are not padding. At the origin the
      // coincidence band produces no flip at all — the cancellation needs two
      // large, closely spaced coordinates, which is why real icons at
      // viewBox scale hit this and a fixture at the origin does not.
      const bands = [
        [1e-6, 1e-3],
        [151.0 * math.pi / 180, 151.09 * math.pi / 180],
      ];

      for (final vertex in [
        Vector2.zero(),
        Vector2(19, 12),
        Vector2(8.32846, 10.9843),
        Vector2(500, 900),
      ]) {
        for (final band in bands) {
          for (var i = 0; i <= 200; i++) {
            final phi = band[0] + (band[1] - band[0]) * i / 200;

            for (final join in LineJoin.values) {
              final counts = <int>{};

              for (final width in [1.33, 1.45, 1.49, 1.5, 1.51, 1.55, 2.0]) {
                final stroke = StrokeProperties(width: width, join: join);
                final incoming = Cubic.line(
                  vertex - Vector2(8, 0),
                  vertex,
                ).tangentAt(1);
                final outgoing = Cubic.line(
                  vertex,
                  vertex + Vector2(math.cos(phi), math.sin(phi)) * 8,
                ).tangentAt(0);

                counts.add(
                  StrokeJoiner(stroke)
                      .join(
                        vertex: vertex,
                        from: vertex + leftNormal(incoming) * stroke.radius,
                        to: vertex + leftNormal(outgoing) * stroke.radius,
                        incoming: incoming,
                        outgoing: outgoing,
                      )
                      .length,
                );
              }

              expect(
                counts,
                hasLength(1),
                reason:
                    'vertex $vertex, turn ${phi * 180 / math.pi}°, $join '
                    'produced $counts segment counts across widths; every '
                    'width must agree',
              );
            }
          }
        }
      }
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
      // At an orientation empirically confirmed to push the recovered sweep
      // a hair above pi/2 — the same float32-rounding mechanism that costs
      // both example/svg/arrow_right.svg's and example/svg/check.svg's
      // exact-90° round joins a doubled segment count (see arc_test.dart's
      // equivalent regression on arcToCubics directly).
      final geometry = roundJoinAt(
        vertexX: 0,
        vertexY: 0,
        theta: 0.0173,
        leg1: 1,
        leg2: 1,
      );

      expect(geometry, hasLength(1));
    });

    test(
      'round still treats an exact 90° turn as one segment far from the '
      'origin',
      () {
        // A corner pinned at the origin (the test above) never exercises
        // catastrophic cancellation in tangentAt's p1 - p0 — both points are
        // small, so subtracting them loses little precision. A corner out
        // at icon-canvas scale (offsets up to 2000, short legs) is where
        // that cancellation actually bites: this is the worst sample found
        // sweeping vertex offsets 0-2000 and leg lengths 0.5-50 through this
        // exact chain (500,000 samples; excess 3.39e-4 — see arc.dart's
        // `_kSweepRatioEpsilon` doc), reproduced directly rather than as a
        // raw sweep so a regression in the tangent chain itself, not just in
        // arcToCubics, would be caught here too.
        final geometry = roundJoinAt(
          vertexX: 1624.8622377670079,
          vertexY: 1373.683690419132,
          theta: 0.8337265167484509,
          leg1: 0.5778957200097815,
          leg2: 22.576726269762425,
        );

        expect(geometry, hasLength(1));
      },
    );

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
      // A hairpin: the stroke doubles back, and the inner edges only meet
      // well outside the corner. Running out to that point would distort far
      // more than the overlap it removes, so the joiner bridges straight
      // across instead.
      //
      // The turn is what puts the crossing there — at sqrt(2 / (1 + cos t))
      // radii, the bound of four radii is a turn of about 151°, so 160° is
      // past it while an ordinary corner is nowhere near. Placing `to` by
      // hand instead, far from where its own tangent puts it, manufactures a
      // distant crossing out of a 5.7° turn that would really cross at 1.001
      // radii — geometry no offset chain can produce.
      const stroke = StrokeProperties(width: 2);
      final vertex = Vector2.zero();
      final incoming = Vector2(1, 0);
      const turn = 160 * math.pi / 180;
      final outgoing = Vector2(math.cos(turn), math.sin(turn));
      final to = vertex + leftNormal(outgoing) * stroke.radius;

      final geometry = const StrokeJoiner(stroke).join(
        vertex: vertex,
        from: vertex + leftNormal(incoming) * stroke.radius,
        to: to,
        incoming: incoming,
        outgoing: outgoing,
      );

      expect(math.sqrt(2 / (1 + incoming.dot(outgoing))), greaterThan(4));
      expect(geometry, hasLength(1));
      expect(geometry.single.p3.distanceTo(to), lessThan(_kEpsilon));
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
