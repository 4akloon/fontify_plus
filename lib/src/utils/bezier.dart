import 'dart:math' as math;

/// A cubic segment as its four control points.
typedef _Cubic = (
  math.Point<num>,
  math.Point<num>,
  math.Point<num>,
  math.Point<num>,
);

/// One quadratic segment: its control point and where it ends.
typedef QuadraticSegment = ({math.Point<num> control, math.Point<num> end});

/// How far an approximating quadratic may stray from the cubic it replaces,
/// in font units.
///
/// TrueType coordinates are integers, so anything under half a unit is below
/// the resolution the points are stored at.
const kQuadraticApproximationTolerance = 0.5;

/// Recursion cap. Each level cuts the error by eight, so the tolerance is met
/// long before this.
const _kMaxSubdivisionDepth = 8;

/// Converts quadratic bezier curve to a cubic one.
///
/// Takes three points as parameters, where [qp1] is a control point.
///
/// Returns two new control points in a list.
List<math.Point<num>> quadCurveToCubic(
  math.Point<num> qp0,
  math.Point<num> qp1,
  math.Point<num> qp2,
) {
  final cp1 = qp0 + (qp1 - qp0) * (2 / 3);
  final cp2 = qp2 + (qp1 - qp2) * (2 / 3);

  return [cp1, cp2];
}

/// Approximates the cubic through [p0], [p1], [p2], [p3] with quadratics no
/// farther than [tolerance] from it.
///
/// A cubic is not generally expressible as a quadratic, and TrueType stores
/// quadratics only, so a glyph that came from SVG has to be approximated
/// before it can go into `glyf`. Each piece keeps the end points exact and is
/// subdivided until the error bound below is met, so the result meets the
/// tolerance everywhere rather than only at the samples.
List<QuadraticSegment> cubicCurveToQuadratics(
  math.Point<num> p0,
  math.Point<num> p1,
  math.Point<num> p2,
  math.Point<num> p3, [
  double tolerance = kQuadraticApproximationTolerance,
]) {
  final result = <QuadraticSegment>[];

  _approximate((p0, p1, p2, p3), tolerance, _kMaxSubdivisionDepth, result);

  return result;
}

void _approximate(
  _Cubic cubic,
  double tolerance,
  int depth,
  List<QuadraticSegment> out,
) {
  if (depth == 0 || _singleQuadraticError(cubic) <= tolerance) {
    out.add((control: _quadraticControl(cubic), end: cubic.$4));
    return;
  }

  final (left, right) = _splitAtHalf(cubic);

  _approximate(left, tolerance, depth - 1, out);
  _approximate(right, tolerance, depth - 1, out);
}

/// The control point of the quadratic that best matches [cubic].
///
/// It is where the two end tangents would put a control point, averaged: the
/// quadratic then shares the cubic's end points and end tangent directions.
math.Point<num> _quadraticControl(_Cubic cubic) {
  final (p0, p1, p2, p3) = cubic;

  return math.Point<num>(
    (3 * p1.x - p0.x + 3 * p2.x - p3.x) / 4,
    (3 * p1.y - p0.y + 3 * p2.y - p3.y) / 4,
  );
}

/// The most that quadratic can stray from [cubic].
///
/// Raising the quadratic back to third degree leaves a residual that is a
/// fixed multiple of the cubic's third difference, and the constant works out
/// to sqrt(3)/36. Subdividing halves the parameter interval, which cuts the
/// third difference — and so this bound — by eight.
double _singleQuadraticError(_Cubic cubic) {
  final (p0, p1, p2, p3) = cubic;

  final dx = p3.x - 3 * p2.x + 3 * p1.x - p0.x;
  final dy = p3.y - 3 * p2.y + 3 * p1.y - p0.y;

  return math.sqrt(3) / 36 * math.sqrt(dx * dx + dy * dy);
}

/// Splits [cubic] in half, by de Casteljau.
(_Cubic, _Cubic) _splitAtHalf(_Cubic cubic) {
  final (p0, p1, p2, p3) = cubic;

  final a = _midpoint(p0, p1);
  final b = _midpoint(p1, p2);
  final c = _midpoint(p2, p3);
  final d = _midpoint(a, b);
  final e = _midpoint(b, c);
  final f = _midpoint(d, e);

  return ((p0, a, d, f), (f, e, c, p3));
}

math.Point<num> _midpoint(math.Point<num> a, math.Point<num> b) =>
    math.Point<num>((a.x + b.x) / 2, (a.y + b.y) / 2);
