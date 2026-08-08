import 'dart:math' as math;

import 'package:path_parsing/path_parsing.dart';
import 'package:vector_math/vector_math.dart';

import 'bezier_offset.dart';
import 'stroke.dart';

/// How far the offset may stray from the true offset, in SVG user units.
///
/// Icons are authored in small viewBoxes (commonly 16 or 24 units) and scaled
/// onto the em square, so at the usual 1000 upem this is about 1.2 font units —
/// the resolution a typeface is drawn at anyway, and well under a pixel at any
/// size an icon is displayed.
const _kOffsetTolerance = 0.02;

/// Points closer together than this are treated as coincident.
const _kEpsilon = 1e-9;

/// Cosine of the sharpest turn still treated as a smooth junction.
///
/// Roughly one degree. A curve written as a chain of cubics meets itself
/// tangentially at each junction, and inserting join geometry there would
/// litter the outline with degenerate arcs.
const _kSmoothJunctionCosine = 0.9998;

/// Converts a stroked SVG path into the filled region that the stroke covers.
///
/// Returns path data describing that region, or null when [pathData] contains
/// nothing strokeable.
///
/// Font glyphs have no stroke — an outline is either filled or it is invisible.
/// A stroked path handed straight to the rasterizer collapses to its zero-area
/// centreline, which is why outline-style icon sets come out blank or hairline
/// thin without this step.
///
/// The result relies on the nonzero winding rule rather than a boolean union:
/// overlapping contours wound the same way merge when filled, so crossing
/// subpaths (a plus sign, an X) need no clipping pass. Contours are emitted in
/// consistent orientation to make that hold.
String? outlineStrokeToPathData(String pathData, StrokeProperties stroke) {
  final subPaths = _SubPathBuilder().build(pathData);
  final contours = <List<Cubic>>[];

  for (final subPath in subPaths) {
    contours.addAll(_outlineSubPath(subPath, stroke));
  }

  if (contours.isEmpty) {
    return null;
  }

  return _toPathData(contours);
}

/// One subpath, kept as curves rather than flattened.
///
/// Offsetting proceeds segment by segment either way, but keeping the curves
/// means their offsets can be approximated directly. Flattening first discards
/// the exact end tangents that make that approximation cheap, and no amount of
/// refitting afterwards recovers them.
class _SubPath {
  _SubPath(this.start);

  final Vector2 start;
  final segments = <Cubic>[];
  bool closed = false;

  Vector2 get end => segments.isEmpty ? start : segments.last.p3;
}

/// Collects SVG path data as cubic segments.
class _SubPathBuilder extends PathProxy {
  final _subPaths = <_SubPath>[];

  _SubPath? _current;
  Vector2 _cursor = Vector2.zero();

  @override
  void moveTo(double x, double y) {
    _finish();
    _cursor = Vector2(x, y);
    _current = _SubPath(_cursor.clone());
  }

  @override
  void lineTo(double x, double y) {
    final end = Vector2(x, y);
    final current = _current ??= _SubPath(_cursor.clone());

    if (current.end.distanceToSquared(end) > _kEpsilon) {
      current.segments.add(Cubic.line(current.end, end));
    }

    _cursor = end;
  }

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final current = _current ??= _SubPath(_cursor.clone());
    final end = Vector2(x3, y3);

    current.segments.add(
      Cubic(current.end, Vector2(x1, y1), Vector2(x2, y2), end),
    );

    _cursor = end;
  }

  @override
  void close() {
    final current = _current;

    if (current != null &&
        current.segments.isNotEmpty &&
        current.end.distanceToSquared(current.start) > _kEpsilon) {
      current.segments.add(Cubic.line(current.end, current.start));
    }

    current?.closed = true;
    _finish();
  }

  void _finish() {
    final current = _current;

    if (current != null && current.segments.isNotEmpty) {
      _subPaths.add(current);
    }

    _current = null;
  }

  List<_SubPath> build(String pathData) {
    writeSvgPathDataToPath(pathData, this);
    _finish();

    return _subPaths;
  }
}

/// Builds the filled contours covering one stroked subpath.
List<List<Cubic>> _outlineSubPath(_SubPath subPath, StrokeProperties stroke) {
  final radius = stroke.radius;

  if (subPath.segments.isEmpty) {
    return const [];
  }

  if (subPath.closed) {
    // A closed stroke is an annulus: the outer wall and the inner wall, wound
    // opposite so the nonzero rule leaves the middle hollow.
    return [
      _offsetSide(subPath.segments, true, radius, stroke),
      _offsetSide(_reverse(subPath.segments), true, radius, stroke),
    ];
  }

  // An open stroke is a single loop: up one side, around the end cap, back down
  // the other side, around the start cap.
  final forward = subPath.segments;
  final backward = _reverse(forward);

  return [
    <Cubic>[
      ..._offsetSide(forward, false, radius, stroke),
      ..._cap(forward.last.p3, forward.last.tangentAt(1), radius, stroke.cap),
      ..._offsetSide(backward, false, radius, stroke),
      ..._cap(backward.last.p3, backward.last.tangentAt(1), radius, stroke.cap),
    ],
  ];
}

/// Reverses a chain of segments, so offsetting to the left walks the other side.
List<Cubic> _reverse(List<Cubic> segments) => [
      for (final s in segments.reversed) Cubic(s.p3, s.p2, s.p1, s.p0),
    ];

/// Offsets a chain of segments to its left, inserting join geometry.
List<Cubic> _offsetSide(
  List<Cubic> segments,
  bool closed,
  double radius,
  StrokeProperties stroke,
) {
  final result = <Cubic>[];

  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final offset = offsetCubic(segment, radius, _kOffsetTolerance);

    if (offset.isEmpty) {
      continue;
    }

    if (result.isNotEmpty) {
      _join(
        result,
        segment.p0,
        segments[i - 1].tangentAt(1),
        segment.tangentAt(0),
        offset.first.p0,
        radius,
        stroke,
      );
    }

    result.addAll(offset);
  }

  if (closed && result.isNotEmpty) {
    // Close the ring by joining the last segment back to the first.
    _join(
      result,
      segments.first.p0,
      segments.last.tangentAt(1),
      segments.first.tangentAt(0),
      result.first.p0,
      radius,
      stroke,
    );
  }

  return result;
}

/// Bridges the gap between two offset segments meeting at [vertex].
///
/// The two sides of a corner behave differently. On the outer side the offset
/// edges pull apart and the gap is filled according to `stroke-linejoin`. On the
/// inner side they overrun each other, and the fix is to pull both back to where
/// their tangents cross — leaving the overrun folds a reversed loop into the
/// contour, which the nonzero rule punches out as a hole.
void _join(
  List<Cubic> result,
  Vector2 vertex,
  Vector2 incomingTangent,
  Vector2 outgoingTangent,
  Vector2 nextStart,
  double radius,
  StrokeProperties stroke,
) {
  final previousEnd = result.last.p3;

  if (previousEnd.distanceToSquared(nextStart) <= _kEpsilon) {
    return;
  }

  // Tangentially continuous: a chain of cubics describing one curve. Any gap is
  // numerical, so close it with a straight bridge rather than a join.
  if (incomingTangent.dot(outgoingTangent) >= _kSmoothJunctionCosine) {
    result.add(Cubic.line(previousEnd, nextStart));
    return;
  }

  final cross = incomingTangent.x * outgoingTangent.y -
      incomingTangent.y * outgoingTangent.x;

  // Offsetting to the left makes a right turn the outer side.
  final isOuter = cross < 0;

  if (!isOuter) {
    final crossing = _tangentCrossing(
      previousEnd,
      incomingTangent,
      nextStart,
      outgoingTangent,
    );

    // A very sharp inner corner puts the crossing far from the path, where
    // using it would distort more than the overlap it removes.
    if (crossing != null && crossing.distanceTo(vertex) <= radius * 4) {
      result
        ..add(Cubic.line(previousEnd, crossing))
        ..add(Cubic.line(crossing, nextStart));
      return;
    }

    result.add(Cubic.line(previousEnd, nextStart));
    return;
  }

  switch (stroke.join) {
    case LineJoin.bevel:
      result.add(Cubic.line(previousEnd, nextStart));
      return;

    case LineJoin.round:
      final from = math.atan2(
        previousEnd.y - vertex.y,
        previousEnd.x - vertex.x,
      );
      final to = math.atan2(nextStart.y - vertex.y, nextStart.x - vertex.x);

      result.addAll(arcToCubics(vertex, radius, from, _shortSweep(to - from)));
      return;

    case LineJoin.miter:
      final tip = _tangentCrossing(
        previousEnd,
        incomingTangent,
        nextStart,
        outgoingTangent,
      );

      // stroke-miterlimit is the ratio of miter length to stroke width; past it
      // SVG requires falling back to a bevel.
      if (tip == null || tip.distanceTo(vertex) / radius > stroke.miterLimit) {
        result.add(Cubic.line(previousEnd, nextStart));
        return;
      }

      result
        ..add(Cubic.line(previousEnd, tip))
        ..add(Cubic.line(tip, nextStart));
      return;
  }
}

/// Turns the stroke around at an endpoint.
///
/// [direction] points along the stroke, out of the endpoint.
List<Cubic> _cap(
  Vector2 endPoint,
  Vector2 direction,
  double radius,
  LineCap cap,
) {
  final normal = leftNormal(direction) * radius;
  final from = endPoint + normal;
  final to = endPoint - normal;

  switch (cap) {
    case LineCap.butt:
      return [Cubic.line(from, to)];

    case LineCap.round:
      // Sweep the way that passes through [direction], so the cap bulges out
      // beyond the endpoint. Both directions are equally short at half a turn,
      // so the sign cannot be recovered from the endpoints alone.
      return arcToCubics(
        endPoint,
        radius,
        math.atan2(normal.y, normal.x),
        -math.pi,
      );

    case LineCap.square:
      final extension = direction * radius;

      return [
        Cubic.line(from, from + extension),
        Cubic.line(from + extension, to + extension),
        Cubic.line(to + extension, to),
      ];
  }
}

/// Intersection of two lines given by a point and a direction, or null when
/// they are parallel.
Vector2? _tangentCrossing(
  Vector2 pointA,
  Vector2 directionA,
  Vector2 pointB,
  Vector2 directionB,
) {
  final determinant = directionA.x * directionB.y - directionA.y * directionB.x;

  if (determinant.abs() <= _kEpsilon) {
    return null;
  }

  final delta = pointB - pointA;
  final t = (delta.x * directionB.y - delta.y * directionB.x) / determinant;

  return pointA + directionA * t;
}

/// Normalizes a sweep to the short way round.
double _shortSweep(double sweep) {
  var result = sweep;

  while (result > math.pi) {
    result -= 2 * math.pi;
  }
  while (result < -math.pi) {
    result += 2 * math.pi;
  }

  return result;
}

/// Serializes contours as closed SVG path data.
String _toPathData(List<List<Cubic>> contours) {
  final buffer = StringBuffer();

  for (final contour in contours) {
    if (contour.isEmpty) {
      continue;
    }

    buffer.write(
      'M${_coordinate(contour.first.p0.x)} ${_coordinate(contour.first.p0.y)}',
    );

    for (final segment in contour) {
      if (_isStraight(segment)) {
        buffer.write(
          'L${_coordinate(segment.p3.x)} ${_coordinate(segment.p3.y)}',
        );
      } else {
        buffer.write(
          'C${_coordinate(segment.p1.x)} ${_coordinate(segment.p1.y)} '
          '${_coordinate(segment.p2.x)} ${_coordinate(segment.p2.y)} '
          '${_coordinate(segment.p3.x)} ${_coordinate(segment.p3.y)}',
        );
      }
    }

    buffer.write('Z');
  }

  return buffer.toString();
}

/// Whether a cubic's controls lie on its chord, so it can be written as a line.
///
/// Joins and caps produce plenty of straight pieces; spending six coordinates
/// on each would undo much of what offsetting curves directly buys.
bool _isStraight(Cubic segment) {
  final chord = segment.p3 - segment.p0;
  final length = chord.length;

  if (length <= _kEpsilon) {
    return true;
  }

  final direction = chord / length;

  for (final control in [segment.p1, segment.p2]) {
    final offset = control - segment.p0;
    final along = offset.dot(direction);
    final perpendicular = (offset - direction * along).length;

    if (perpendicular > _kOffsetTolerance / 4 || along < 0 || along > length) {
      return false;
    }
  }

  return true;
}

/// Trims float noise so the emitted path data stays readable and compact.
String _coordinate(double value) {
  final rounded = double.parse(value.toStringAsFixed(4));

  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}
