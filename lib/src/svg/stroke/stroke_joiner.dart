import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../geometry/arc.dart';
import '../geometry/cubic.dart';
import '../geometry/line_intersection.dart';
import '../geometry/tolerances.dart';
import 'stroke_properties.dart';

/// Cosine of the sharpest turn still treated as a smooth junction.
///
/// Roughly one degree. A curve written as a chain of cubics meets itself
/// tangentially at each junction, and inserting join geometry there would
/// litter the outline with degenerate arcs.
const _kSmoothJunctionCosine = 0.9998;

/// How far from the corner, in stroke radii, an inner crossing may sit before
/// it is abandoned.
const _kMaxInnerCrossingRadii = 4;

/// How far from the corner its two offset edges cross, in stroke radii.
///
/// Both the miter tip and the inner crossing sit at `radius / sin(theta / 2)`
/// from the vertex, where `theta` is the corner's interior angle, so the
/// ratio to the radius depends on the turn alone and the radius cancels
/// exactly. Measuring it from [lineIntersection]'s output instead — the way
/// both callers below used to — puts the radius back in through the back
/// door: [from] and [to] are float32 offset points whose rounding is set by
/// the vertex's coordinate magnitude rather than by the radius, so the
/// measured ratio drifts with width. At one fixed 28° corner around
/// (19, 12) it ranges over 1.0306132994 to 1.0306140083 across radii
/// 0.5-1.0. A corner sitting that close to [StrokeProperties.miterLimit] or
/// to [_kMaxInnerCrossingRadii] then takes one branch at one master's width
/// and the other branch at the next, which changes the segment count and
/// leaves the two masters un-interpolatable.
double _crossingRadii(Vector2 incoming, Vector2 outgoing) {
  // Clamped because a float32 dot product can leave [-1, 1] by an ulp.
  // Below -1 the square root would take a negative argument, and the
  // resulting NaN compares false against every threshold, quietly keeping
  // the degenerate crossing both thresholds exist to reject. At exactly -1 —
  // a full reversal — this is infinity, which both thresholds reject, as
  // they should.
  final dot = incoming.dot(outgoing).clamp(-1.0, 1.0);

  return math.sqrt(2 / (1 + dot));
}

/// Bridges the gap between two offset segments meeting at a corner.
///
/// The two sides of a corner behave differently. On the outer side the offset
/// edges pull apart and the gap is filled according to `stroke-linejoin`. On
/// the inner side they overrun each other, and the fix is to pull both back to
/// where their tangents cross — leaving the overrun folds a reversed loop into
/// the contour, which the nonzero rule punches out as a hole.
class StrokeJoiner {
  const StrokeJoiner(this.stroke);

  final StrokeProperties stroke;

  /// The geometry running from [from], the end of the previous offset segment,
  /// to [to], the start of the next, around the corner at [vertex].
  List<Cubic> join({
    required Vector2 vertex,
    required Vector2 from,
    required Vector2 to,
    required Vector2 incoming,
    required Vector2 outgoing,
  }) {
    // The gap between from and to is radius * (leftNormal(incoming) -
    // leftNormal(outgoing)), and leftNormal is a rotation, so dividing the
    // radius out of both sides of the old test leaves exactly this: the same
    // inequality with the radius cancelled rather than squared into the
    // bound. Cancelling it is what makes the branch width-invariant;
    // squaring it into the bound only appeared to. Measuring the gap
    // directly cannot cancel anything, because from and to are float32
    // offset points and subtracting two of them at a vertex around (16, 10)
    // loses most of the significance — the ulp there is about 1.9e-6 against
    // a true gap of about 2.5e-5 — leaving noise set by the vertex's
    // magnitude, not by the radius. The bound then scales as radius squared
    // while the measured gap does not: between widths 1.45 and 1.55 the
    // bound grows 1.143x and the measured gap squared grows 1.250x, so the
    // two cross and one master bridges a corner the other drops.
    if (incoming.distanceToSquared(outgoing) <= kPointEpsilon) {
      return const [];
    }

    // Tangentially continuous: a chain of cubics describing one curve. Any gap
    // is numerical, so close it with a straight bridge rather than a join.
    if (incoming.dot(outgoing) >= _kSmoothJunctionCosine) {
      return [Cubic.line(from, to)];
    }

    final cross = incoming.x * outgoing.y - incoming.y * outgoing.x;

    // Offsetting to the left makes a right turn the outer side.
    return cross < 0
        ? _outer(vertex, from, to, incoming, outgoing)
        : _inner(from, to, incoming, outgoing);
  }

  List<Cubic> _inner(
    Vector2 from,
    Vector2 to,
    Vector2 incoming,
    Vector2 outgoing,
  ) {
    final crossing = lineIntersection(from, incoming, to, outgoing);

    // A very sharp inner corner puts the crossing far from the path, where
    // using it would distort more than the overlap it removes.
    if (crossing == null ||
        _crossingRadii(incoming, outgoing) > _kMaxInnerCrossingRadii) {
      return [Cubic.line(from, to)];
    }

    return [Cubic.line(from, crossing), Cubic.line(crossing, to)];
  }

  List<Cubic> _outer(
    Vector2 vertex,
    Vector2 from,
    Vector2 to,
    Vector2 incoming,
    Vector2 outgoing,
  ) {
    switch (stroke.join) {
      case LineJoin.bevel:
        return [Cubic.line(from, to)];

      case LineJoin.round:
        // The arc still starts exactly at from — join()'s contract is that
        // the returned geometry connects to the surrounding offset chain, and
        // from's own angle is what guarantees that. Only the sweep is taken
        // from incoming/outgoing instead of from end's angle minus start's:
        // to (like from) is an offset point whose float32 rounding scales
        // with the radius, so a sweep recovered from atan2(to) - atan2(from)
        // sat on the knife edge of arcToCubics' ceil at an exact quarter
        // turn — an ordinary 90° corner could take a different number of arc
        // segments at different widths. incoming and outgoing are exact unit
        // tangents off the source curve, independent of radius, so the sweep
        // — and the segment count arcToCubics derives from it — comes out
        // identical at every width.
        final start = math.atan2(from.y - vertex.y, from.x - vertex.x);
        final startNormal = leftNormal(incoming);
        final endNormal = leftNormal(outgoing);
        final sweep = shortSweep(
          math.atan2(endNormal.y, endNormal.x) -
              math.atan2(startNormal.y, startNormal.x),
        );

        return arcToCubics(vertex, stroke.radius, start, sweep);

      case LineJoin.miter:
        final tip = lineIntersection(from, incoming, to, outgoing);

        // stroke-miterlimit is the ratio of miter length to stroke width; past
        // it SVG requires falling back to a bevel. The ratio comes from the
        // tangents rather than from tip's own distance so that both masters
        // fall back at the same corners — see [_crossingRadii]. tip is still
        // where the miter is drawn to; only the decision moved.
        if (tip == null ||
            _crossingRadii(incoming, outgoing) > stroke.miterLimit) {
          return [Cubic.line(from, to)];
        }

        return [Cubic.line(from, tip), Cubic.line(tip, to)];
    }
  }
}
