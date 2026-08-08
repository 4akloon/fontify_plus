import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'cubic.dart';
import 'tolerances.dart';

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

  // Error grows sharply past a quarter turn, so never span more than one.
  final count = (sweep.abs() / (math.pi / 2)).ceil();
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
