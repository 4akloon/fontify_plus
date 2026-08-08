import 'package:vector_math/vector_math.dart';

import 'tolerances.dart';

/// Where two lines given by a point and a direction cross, or null when they
/// are parallel.
Vector2? lineIntersection(
  Vector2 pointA,
  Vector2 directionA,
  Vector2 pointB,
  Vector2 directionB,
) {
  final determinant = directionA.x * directionB.y - directionA.y * directionB.x;

  if (determinant.abs() <= kPointEpsilon) {
    return null;
  }

  final delta = pointB - pointA;
  final t = (delta.x * directionB.y - delta.y * directionB.x) / determinant;

  return pointA + directionA * t;
}
