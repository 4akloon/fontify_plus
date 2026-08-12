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
/// Sized from two independent measurements, one per side, not a round
/// guess:
///
/// Lower bound — how big the noise actually gets. `tangentAt` normalizes
/// `p1 - p0`; when the corner sits far from the origin, `p0` and `p1` are
/// two large, closely-spaced float32 coordinates, and subtracting them to
/// recover a short leg is catastrophic cancellation. An orientation- and
/// leg-length-only sweep (corner pinned near the origin) misses this
/// entirely and understates the noise by three orders of magnitude — it
/// reports ~2e-7, but this package's own `arrow_right.svg` (a real corner,
/// vertex around (19, 12)) already measures 2.68e-7, past that supposed
/// ceiling. Rerunning the same real tangent-derivation chain
/// (`Cubic.line(...).tangentAt` → `leftNormal` → `atan2` → `shortSweep`,
/// exactly as `stroke_joiner.dart` computes a round join's sweep) with the
/// corner's vertex swept across offsets 0–2000 and leg lengths 0.5–50 —
/// coordinate scales a 512–1024 viewBox plausibly produces — the worst
/// positive excess over 500,000 samples was **3.39e-4**.
///
/// Upper bound — how big it's geometrically free to get. Letting a "quarter
/// turn" actually span `(1 + delta) * 90°` grows the single-cubic
/// approximation's radial error away from its baseline ~0.0273%-of-radius
/// (the error inherent to *any* single-cubic quarter arc — the standard
/// four-arc circle approximation this rule is built on). Measured
/// directly: at `delta = 0.002` the error is only 1.21% larger than that
/// baseline (0.0273% → 0.0276% of radius) — nowhere near "meaningful" next
/// to the curve-fitting tolerance ([kCurveTolerance]) the rest of this
/// package already accepts. `delta` has to reach 0.0111
/// (91°) before this rule must instead treat the corner as a genuinely
/// different angle (see the "still spans two" tests below), so that,
/// not the geometric error, is what actually bounds this from above.
///
/// This constant, `2e-3`, sits inside both margins: about 5.9x above the
/// worst noise measured above, and about 5.6x below the 91° boundary this
/// rule must not blur.
const _kSweepRatioEpsilon = 2e-3;

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
