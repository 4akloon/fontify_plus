import 'package:vector_math/vector_math.dart';

import 'tolerances.dart';

/// A cubic Bézier segment.
class Cubic {
  const Cubic(this.p0, this.p1, this.p2, this.p3);

  /// A straight line expressed as a cubic, with evenly spaced controls.
  factory Cubic.line(Vector2 start, Vector2 end) {
    final third = (end - start) / 3;

    return Cubic(start, start + third, end - third, end);
  }

  final Vector2 p0;
  final Vector2 p1;
  final Vector2 p2;
  final Vector2 p3;

  /// The same curve traced the other way.
  Cubic get reversed => Cubic(p3, p2, p1, p0);

  Vector2 pointAt(double t) {
    final u = 1 - t;

    return p0 * (u * u * u) +
        p1 * (3 * u * u * t) +
        p2 * (3 * u * t * t) +
        p3 * (t * t * t);
  }

  /// Unit tangent at [t].
  ///
  /// The derivative vanishes when control points coincide — a common way to
  /// write a curve with a flat start — so fall back to the next non-degenerate
  /// difference rather than returning a zero vector.
  Vector2 tangentAt(double t) {
    final derivative = firstDerivativeAt(t);

    if (derivative.length2 > kZeroLengthSquared) {
      return derivative.normalized();
    }

    for (final fallback in [p3 - p0, p2 - p0, p3 - p1]) {
      if (fallback.length2 > kZeroLengthSquared) {
        return fallback.normalized();
      }
    }

    return Vector2(1, 0);
  }

  Vector2 firstDerivativeAt(double t) {
    final u = 1 - t;

    return (p1 - p0) * (3 * u * u) +
        (p2 - p1) * (6 * u * t) +
        (p3 - p2) * (3 * t * t);
  }

  Vector2 secondDerivativeAt(double t) {
    final u = 1 - t;

    return (p2 - p1 * 2.0 + p0) * (6 * u) + (p3 - p2 * 2.0 + p1) * (6 * t);
  }

  /// Signed curvature at [t], positive where the curve turns toward its left
  /// normal — the direction an offset moves.
  double curvatureAt(double t) {
    final d1 = firstDerivativeAt(t);
    final d2 = secondDerivativeAt(t);

    final speed = d1.length;

    if (speed <= kZeroLength) {
      return 0;
    }

    return (d1.x * d2.y - d1.y * d2.x) / (speed * speed * speed);
  }

  /// Splits at [t] into the two halves, by de Casteljau.
  (Cubic, Cubic) splitAt(double t) {
    final a = p0 + (p1 - p0) * t;
    final b = p1 + (p2 - p1) * t;
    final c = p2 + (p3 - p2) * t;
    final d = a + (b - a) * t;
    final e = b + (c - b) * t;
    final f = d + (e - d) * t;

    return (Cubic(p0, a, d, f), Cubic(f, e, c, p3));
  }
}

/// Left-hand normal of a unit direction.
Vector2 leftNormal(Vector2 direction) => Vector2(-direction.y, direction.x);
