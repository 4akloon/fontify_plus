import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';

double signedArea(List<List<double>> points) {
  var sum = 0.0;

  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += a[0] * b[1] - b[0] * a[1];
  }

  return sum / 2;
}

/// Flattens outlined contours into one point list per contour.
///
/// The outliner emits cubics wherever the geometry was curved, so area
/// assertions have to sample the curves rather than use their end points.
List<List<List<double>>> flatten(List<List<Cubic>> contours) {
  const steps = 24;
  final result = <List<List<double>>>[];

  for (final contour in contours) {
    if (contour.isEmpty) {
      continue;
    }

    final points = <List<double>>[
      [contour.first.p0.x, contour.first.p0.y],
    ];

    for (final segment in contour) {
      for (var i = 1; i <= steps; i++) {
        final point = segment.pointAt(i / steps);
        points.add([point.x, point.y]);
      }
    }

    if (points.length > 2) {
      result.add(points);
    }
  }

  return result;
}

double totalArea(List<List<Cubic>> contours) =>
    flatten(contours).fold(0.0, (sum, c) => sum + signedArea(c).abs());

/// Points the glyph will cost: one for the contour start, three per segment.
int pointCount(List<List<Cubic>> contours) =>
    contours.fold(0, (sum, contour) => sum + 1 + contour.length * 3);

const kStroke = StrokeProperties(width: 2);
