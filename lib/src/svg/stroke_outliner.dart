import 'dart:math' as math;

import 'package:path_parsing/path_parsing.dart';
import 'package:vector_math/vector_math.dart';

import 'stroke.dart';

/// Curve flattening tolerance, in SVG user units.
///
/// Icons are authored in small viewBoxes (commonly 16 or 24 units) and then
/// scaled to the font's em square, so the tolerance has to be a small fraction
/// of a unit to survive that magnification. 0.02 keeps a 16-unit icon smooth at
/// 1000 upem while holding the point count low enough to keep glyphs compact.
const _kFlattenTolerance = 0.02;

/// Points closer together than this are treated as coincident.
const _kEpsilon = 1e-9;

/// Converts a stroked SVG path into the filled region that the stroke covers.
///
/// Returns path data describing that region as closed polygonal contours, or
/// null when [pathData] contains nothing strokeable.
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
  final subPaths = _flatten(pathData);
  final contours = <List<Vector2>>[];

  for (final subPath in subPaths) {
    contours.addAll(_outlineSubPath(subPath, stroke));
  }

  if (contours.isEmpty) {
    return null;
  }

  return _toPathData(contours);
}

/// A polyline approximation of one subpath.
class _SubPath {
  _SubPath(Vector2 start) : points = [start];

  final List<Vector2> points;
  bool closed = false;

  void add(Vector2 point) {
    // Collapse repeated points: zero-length segments have no direction, so they
    // would produce meaningless normals downstream.
    if (points.isEmpty || points.last.distanceToSquared(point) > _kEpsilon) {
      points.add(point);
    }
  }
}

/// Walks SVG path data and reduces every curve to line segments.
class _PathFlattener extends PathProxy {
  final subPaths = <_SubPath>[];

  _SubPath? _current;
  Vector2 _cursor = Vector2.zero();

  @override
  void moveTo(double x, double y) {
    // A moveTo always begins a new subpath. Appending to the current one would
    // splice unrelated strokes into a single contour — the reason a two-stroke
    // plus sign renders as one zigzag.
    _finish();
    _cursor = Vector2(x, y);
    _current = _SubPath(_cursor.clone());
  }

  @override
  void lineTo(double x, double y) {
    _cursor = Vector2(x, y);
    (_current ??= _SubPath(_cursor.clone())).add(_cursor.clone());
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
    final p0 = _cursor.clone();
    final p1 = Vector2(x1, y1);
    final p2 = Vector2(x2, y2);
    final p3 = Vector2(x3, y3);

    final current = _current ??= _SubPath(p0.clone());
    final steps = _cubicSegmentCount(p0, p1, p2, p3);

    for (var i = 1; i <= steps; i++) {
      current.add(_cubicAt(p0, p1, p2, p3, i / steps));
    }

    _cursor = p3;
  }

  @override
  void close() {
    _current?.closed = true;
    _finish();
  }

  void _finish() {
    final current = _current;

    if (current != null && current.points.isNotEmpty) {
      subPaths.add(current);
    }

    _current = null;
  }

  List<_SubPath> flatten(String pathData) {
    writeSvgPathDataToPath(pathData, this);
    _finish();

    return subPaths;
  }
}

List<_SubPath> _flatten(String pathData) => _PathFlattener().flatten(pathData);

/// Chooses a segment count for a cubic from its control polygon length.
///
/// The control polygon bounds the curve, so its length caps how far the curve
/// can stray; the error of an n-segment chord approximation falls off as n^-2.
int _cubicSegmentCount(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3) {
  final polygonLength =
      p0.distanceTo(p1) + p1.distanceTo(p2) + p2.distanceTo(p3);

  if (polygonLength <= _kEpsilon) {
    return 1;
  }

  final steps = math.sqrt(polygonLength / _kFlattenTolerance).ceil();

  return steps.clamp(2, 64);
}

Vector2 _cubicAt(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, double t) {
  final u = 1 - t;
  final a = u * u * u;
  final b = 3 * u * u * t;
  final c = 3 * u * t * t;
  final d = t * t * t;

  return Vector2(
    a * p0.x + b * p1.x + c * p2.x + d * p3.x,
    a * p0.y + b * p1.y + c * p2.y + d * p3.y,
  );
}

/// Left-hand normal of a unit direction.
Vector2 _leftNormal(Vector2 direction) => Vector2(-direction.y, direction.x);

/// Builds the filled contours covering one stroked subpath.
List<List<Vector2>> _outlineSubPath(_SubPath subPath, StrokeProperties stroke) {
  final points = [...subPath.points];
  final radius = stroke.radius;

  // A closed subpath whose last point repeats the first carries a redundant
  // vertex; the closing segment is implied.
  if (subPath.closed &&
      points.length > 1 &&
      points.first.distanceToSquared(points.last) <= _kEpsilon) {
    points.removeLast();
  }

  if (points.length < 2) {
    // A degenerate subpath is visible only when the cap paints something.
    if (points.length == 1 && stroke.cap == LineCap.round) {
      return [_circle(points.first, radius)];
    }

    if (points.length == 1 && stroke.cap == LineCap.square) {
      final c = points.first;
      return [
        [
          Vector2(c.x - radius, c.y - radius),
          Vector2(c.x + radius, c.y - radius),
          Vector2(c.x + radius, c.y + radius),
          Vector2(c.x - radius, c.y + radius),
        ],
      ];
    }

    return const [];
  }

  if (subPath.closed) {
    // A closed stroke is an annulus: the outer wall and the inner wall, wound
    // opposite so the nonzero rule leaves the middle hollow.
    return [
      _offsetSide(points, true, radius, stroke),
      _offsetSide(points.reversed.toList(), true, radius, stroke),
    ];
  }

  // An open stroke is a single loop: up one side, around the end cap, back down
  // the other side, around the start cap.
  final contour = <Vector2>[
    ..._offsetSide(points, false, radius, stroke),
  ];

  _appendCap(
    contour,
    points[points.length - 1],
    _direction(points[points.length - 2], points[points.length - 1]),
    radius,
    stroke.cap,
  );

  contour.addAll(_offsetSide(points.reversed.toList(), false, radius, stroke));

  _appendCap(
    contour,
    points.first,
    _direction(points[1], points.first),
    radius,
    stroke.cap,
  );

  return [contour];
}

Vector2 _direction(Vector2 from, Vector2 to) {
  final delta = to - from;
  final length = delta.length;

  return length <= _kEpsilon ? Vector2(1, 0) : delta / length;
}

/// Offsets a polyline to its left by [radius], inserting join geometry.
List<Vector2> _offsetSide(
  List<Vector2> points,
  bool closed,
  double radius,
  StrokeProperties stroke,
) {
  final result = <Vector2>[];
  final segmentCount = closed ? points.length : points.length - 1;

  Vector2? previousNormal;

  for (var i = 0; i < segmentCount; i++) {
    final start = points[i];
    final end = points[(i + 1) % points.length];

    final direction = _direction(start, end);
    final normal = _leftNormal(direction) * radius;

    var skipStart = false;

    if (previousNormal != null) {
      skipStart =
          _appendJoin(result, start, previousNormal, normal, radius, stroke);
    }

    if (!skipStart) {
      result.add(start + normal);
    }

    result.add(end + normal);

    previousNormal = normal;
  }

  if (closed && previousNormal != null && result.isNotEmpty) {
    // Close the ring by joining the last segment back to the first.
    final firstDirection = _direction(points[0], points[1 % points.length]);
    final firstNormal = _leftNormal(firstDirection) * radius;

    if (_appendJoin(
      result,
      points[0],
      previousNormal,
      firstNormal,
      radius,
      stroke,
    )) {
      // The closing join replaced the ring's first point too.
      result.removeAt(0);
    }
  }

  return result;
}

/// Adds the corner geometry between two offset segments meeting at [vertex].
///
/// Returns true when the caller must not emit the incoming segment's offset
/// start point, because this join has already replaced it.
///
/// The two sides of a corner behave differently. On the outer side the offset
/// edges pull apart and the gap has to be filled according to `stroke-linejoin`.
/// On the inner side they overrun each other, and the fix is to trim both back
/// to where they cross — leaving the overrun in place would fold a reversed
/// loop into the contour, which the nonzero rule punches out as a hole.
bool _appendJoin(
  List<Vector2> result,
  Vector2 vertex,
  Vector2 previousNormal,
  Vector2 normal,
  double radius,
  StrokeProperties stroke,
) {
  final cross = previousNormal.x * normal.y - previousNormal.y * normal.x;

  // Collinear segments need no join.
  if (cross.abs() <= _kEpsilon) {
    return false;
  }

  // Offsetting to the left makes a right turn the outer side.
  final isOuter = cross < 0;

  if (!isOuter) {
    return _trimInnerCorner(result, vertex, previousNormal, normal, radius);
  }

  switch (stroke.join) {
    case LineJoin.bevel:
      // The straight line between the two offset endpoints is the bevel; the
      // points bracketing this call already supply it.
      return false;

    case LineJoin.round:
      _appendArc(result, vertex, previousNormal, normal, radius);
      return false;

    case LineJoin.miter:
      final miter = _miterPoint(vertex, previousNormal, normal, radius);

      if (miter == null) {
        return false;
      }

      // stroke-miterlimit is the ratio of miter length to stroke width; past it
      // SVG requires falling back to a bevel.
      if (miter.distanceTo(vertex) / radius > stroke.miterLimit) {
        return false;
      }

      result.add(miter);
      return false;
  }
}

/// Replaces an inner corner's overlapping edge ends with their crossing point.
///
/// Drops the outgoing point of the previous segment and reports that the next
/// segment's start point is likewise unneeded.
bool _trimInnerCorner(
  List<Vector2> result,
  Vector2 vertex,
  Vector2 previousNormal,
  Vector2 normal,
  double radius,
) {
  if (result.isEmpty) {
    return false;
  }

  final crossing = _miterPoint(vertex, previousNormal, normal, radius);

  // A very sharp inner corner puts the crossing far from the path, where using
  // it would distort the outline more than the small overlap it removes.
  if (crossing == null || crossing.distanceTo(vertex) > radius * 4) {
    return false;
  }

  result
    ..removeLast()
    ..add(crossing);

  return true;
}

/// Intersection of the two offset edges, or null when they are parallel.
Vector2? _miterPoint(
  Vector2 vertex,
  Vector2 previousNormal,
  Vector2 normal,
  double radius,
) {
  final bisector = previousNormal + normal;
  final length = bisector.length;

  if (length <= _kEpsilon) {
    return null;
  }

  final unitBisector = bisector / length;

  // cos of half the angle between the two offset directions.
  final cosHalf = unitBisector.dot(normal) / radius;

  if (cosHalf.abs() <= _kEpsilon) {
    return null;
  }

  return vertex + unitBisector * (radius / cosHalf);
}

/// Appends an arc around [centre] from [from] to [to], both offset vectors of
/// length [radius].
void _appendArc(
  List<Vector2> result,
  Vector2 centre,
  Vector2 from,
  Vector2 to,
  double radius,
) {
  final startAngle = math.atan2(from.y, from.x);
  var sweep = math.atan2(to.y, to.x) - startAngle;

  // Take the short way round; the long way would wrap the arc the wrong side of
  // the corner.
  while (sweep > math.pi) {
    sweep -= 2 * math.pi;
  }
  while (sweep < -math.pi) {
    sweep += 2 * math.pi;
  }

  _appendArcSweep(result, centre, startAngle, sweep, radius);
}

/// Appends an arc of an explicitly given sweep.
///
/// A cap turns through exactly half a circle, where the two directions are
/// equally short and the sign cannot be recovered from the endpoints — picking
/// wrong folds the cap back over the stroke and cancels its area. Callers that
/// know the direction pass it here instead.
void _appendArcSweep(
  List<Vector2> result,
  Vector2 centre,
  double startAngle,
  double sweep,
  double radius,
) {
  final steps = _arcSegmentCount(radius, sweep.abs());

  for (var i = 1; i < steps; i++) {
    final angle = startAngle + sweep * (i / steps);
    result.add(
      Vector2(
        centre.x + radius * math.cos(angle),
        centre.y + radius * math.sin(angle),
      ),
    );
  }
}

/// Segment count for an arc, from the sagitta of a chord at the flattening
/// tolerance.
int _arcSegmentCount(double radius, double sweep) {
  if (radius <= _kEpsilon || sweep <= _kEpsilon) {
    return 1;
  }

  final ratio = 1 - _kFlattenTolerance / radius;
  final maxAngle =
      ratio <= -1 ? math.pi : 2 * math.acos(ratio.clamp(-1.0, 1.0));

  if (maxAngle <= _kEpsilon) {
    return 32;
  }

  return (sweep / maxAngle).ceil().clamp(2, 64);
}

/// Appends the cap that turns the stroke around at an endpoint.
///
/// [direction] points along the stroke, out of the endpoint.
void _appendCap(
  List<Vector2> result,
  Vector2 endPoint,
  Vector2 direction,
  double radius,
  LineCap cap,
) {
  final normal = _leftNormal(direction) * radius;

  switch (cap) {
    case LineCap.butt:
      // The contour closes straight across; nothing to add.
      return;

    case LineCap.round:
      // Sweep from the left normal to the right normal the way that passes
      // through [direction], so the cap bulges out beyond the endpoint.
      _appendArcSweep(
        result,
        endPoint,
        math.atan2(normal.y, normal.x),
        -math.pi,
        radius,
      );
      return;

    case LineCap.square:
      final extension = direction * radius;
      result
        ..add(endPoint + normal + extension)
        ..add(endPoint - normal + extension);
      return;
  }
}

List<Vector2> _circle(Vector2 centre, double radius) {
  final steps = _arcSegmentCount(radius, 2 * math.pi);

  return [
    for (var i = 0; i < steps; i++)
      Vector2(
        centre.x + radius * math.cos(2 * math.pi * i / steps),
        centre.y + radius * math.sin(2 * math.pi * i / steps),
      ),
  ];
}

/// Serializes contours as closed polygonal SVG path data.
String _toPathData(List<List<Vector2>> contours) {
  final buffer = StringBuffer();

  for (final contour in contours) {
    if (contour.length < 3) {
      continue;
    }

    buffer.write(
        'M${_coordinate(contour.first.x)} ${_coordinate(contour.first.y)}');

    for (var i = 1; i < contour.length; i++) {
      buffer.write(
        'L${_coordinate(contour[i].x)} ${_coordinate(contour[i].y)}',
      );
    }

    buffer.write('Z');
  }

  return buffer.toString();
}

/// Trims float noise so the emitted path data stays readable and compact.
String _coordinate(double value) {
  final rounded = double.parse(value.toStringAsFixed(4));

  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}
