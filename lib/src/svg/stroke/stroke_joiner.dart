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
    if (from.distanceToSquared(to) <= kPointEpsilon) {
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
        : _inner(vertex, from, to, incoming, outgoing);
  }

  List<Cubic> _inner(
    Vector2 vertex,
    Vector2 from,
    Vector2 to,
    Vector2 incoming,
    Vector2 outgoing,
  ) {
    final crossing = lineIntersection(from, incoming, to, outgoing);

    // A very sharp inner corner puts the crossing far from the path, where
    // using it would distort more than the overlap it removes.
    if (crossing == null ||
        crossing.distanceTo(vertex) > stroke.radius * _kMaxInnerCrossingRadii) {
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
        final start = math.atan2(from.y - vertex.y, from.x - vertex.x);
        final end = math.atan2(to.y - vertex.y, to.x - vertex.x);

        return arcToCubics(
          vertex,
          stroke.radius,
          start,
          shortSweep(end - start),
        );

      case LineJoin.miter:
        final tip = lineIntersection(from, incoming, to, outgoing);

        // stroke-miterlimit is the ratio of miter length to stroke width; past
        // it SVG requires falling back to a bevel.
        if (tip == null ||
            tip.distanceTo(vertex) / stroke.radius > stroke.miterLimit) {
          return [Cubic.line(from, to)];
        }

        return [Cubic.line(from, tip), Cubic.line(tip, to)];
    }
  }
}
