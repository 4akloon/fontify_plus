import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../geometry/arc.dart';
import '../geometry/cubic.dart';
import 'stroke_properties.dart';

/// Turns the stroke around at the end of an open subpath.
class StrokeCapper {
  const StrokeCapper(this.stroke);

  final StrokeProperties stroke;

  /// The geometry closing the stroke at [endPoint].
  ///
  /// [direction] points along the stroke, out of the endpoint.
  List<Cubic> cap(Vector2 endPoint, Vector2 direction) {
    final radius = stroke.radius;
    final normal = leftNormal(direction) * radius;

    final from = endPoint + normal;
    final to = endPoint - normal;

    switch (stroke.cap) {
      case LineCap.butt:
        return [Cubic.line(from, to)];

      case LineCap.round:
        // Sweep the way that passes through [direction], so the cap bulges out
        // beyond the endpoint. Both directions are equally short at half a
        // turn, so the sign cannot be recovered from the endpoints alone.
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
}
