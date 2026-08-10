import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'cubic.dart';
import 'tolerances.dart';

/// How far the sweep/quarter-turn ratio may sit above an integer and still
/// be treated as exactly that integer, when deciding how many cubics to
/// split an arc into.
///
/// [sweep] typically reaches this function as the difference of two
/// `atan2` calls on unit tangents that were each rounded to float32
/// ([Vector2] is float32-backed) after a chain of subtraction and
/// normalization — an exact quarter turn can land a hair above or below
/// `pi/2` depending on how that rounding fell, and `ceil` turns "a hair
/// above" into a full extra cubic.
///
/// Sized from measurement, not a round guess: building right-angle corners
/// through the real tangent-derivation chain (`Cubic.line(...).tangentAt`),
/// at every orientation and at radii from 1 to 1000, the ratio's error from
/// 1.0 topped out at 2.15e-7 — consistent with a couple of float32 unit
/// roundoffs (~1.19e-7 each) surviving the `atan2` difference, and matching
/// the two real corners this was measured against directly
/// (`example/svg/arrow_right.svg` and `example/svg/check.svg`, which land
/// at 2.68e-7 and 8.05e-8 respectively). This constant is a decade above
/// that observed ceiling — comfortable headroom above the noise, while
/// still four orders of magnitude below the smallest genuine excess this
/// rule has to keep catching (a 91° corner sits at ratio 1.011).
const _kSweepRatioEpsilon = 1e-6;

/// Approximates a circular arc as a chain of cubics.
///
/// Round joins and caps are exact circular arcs. Sampling them into a polyline
/// is what made caps cost a dozen points each; a quarter turn is within a
/// fraction of a unit of a single cubic.
List<Cubic> arcToCubics(
  Vector2 centre,
  double radius,
  double startAngle,
  double sweep,
) {
  if (radius <= kZeroLength || sweep.abs() <= kZeroLength) {
    return const [];
  }

  // Error grows sharply past a quarter turn, so never span more than one —
  // but subtract _kSweepRatioEpsilon before rounding up, so a ratio that
  // only clears an integer boundary by float32 rounding noise is treated as
  // that integer rather than the next one up. A sweep genuinely past the
  // boundary (see _kSweepRatioEpsilon's doc) still rounds up normally. The
  // floor guards a tiny-but-nonzero sweep that subtracting the epsilon would
  // otherwise round down to zero segments.
  final ratio = sweep.abs() / (math.pi / 2);
  final count = math.max(1, (ratio - _kSweepRatioEpsilon).ceil());
  final step = sweep / count;

  // Control point distance that makes a cubic match a circular arc: the
  // standard 4/3 tan(theta/4).
  final handle = 4 / 3 * math.tan(step / 4) * radius;

  final result = <Cubic>[];
  var angle = startAngle;

  for (var i = 0; i < count; i++) {
    final next = angle + step;

    final from = centre + Vector2(math.cos(angle), math.sin(angle)) * radius;
    final to = centre + Vector2(math.cos(next), math.sin(next)) * radius;

    // Tangents run perpendicular to the radius, in the direction of travel.
    final fromTangent = Vector2(-math.sin(angle), math.cos(angle));
    final toTangent = Vector2(-math.sin(next), math.cos(next));

    result.add(
      Cubic(from, from + fromTangent * handle, to - toTangent * handle, to),
    );

    angle = next;
  }

  return result;
}

/// Normalizes a sweep to the short way round.
double shortSweep(double sweep) {
  var result = sweep;

  while (result > math.pi) {
    result -= 2 * math.pi;
  }
  while (result < -math.pi) {
    result += 2 * math.pi;
  }

  return result;
}
