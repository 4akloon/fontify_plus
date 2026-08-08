import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:path_parsing/path_parsing.dart';

double signedArea(List<List<double>> points) {
  var sum = 0.0;

  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += a[0] * b[1] - b[0] * a[1];
  }

  return sum / 2;
}

/// Flattens path data into one point list per contour.
///
/// The outliner emits cubics wherever the geometry was curved, so these
/// assertions have to go through a real path parser rather than splitting the
/// string on command letters.
class ContourReader extends PathProxy {
  final contours = <List<List<double>>>[];

  List<List<double>>? _current;
  var _cursor = [0.0, 0.0];

  @override
  void moveTo(double x, double y) {
    _flush();
    _cursor = [x, y];
    _current = [
      [x, y],
    ];
  }

  @override
  void lineTo(double x, double y) {
    _cursor = [x, y];
    (_current ??= []).add([x, y]);
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
    final p0 = _cursor;
    const steps = 24;

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final u = 1 - t;
      final a = u * u * u;
      final b = 3 * u * u * t;
      final c = 3 * u * t * t;
      final d = t * t * t;

      (_current ??= []).add([
        a * p0[0] + b * x1 + c * x2 + d * x3,
        a * p0[1] + b * y1 + c * y2 + d * y3,
      ]);
    }

    _cursor = [x3, y3];
  }

  @override
  void close() => _flush();

  void _flush() {
    final current = _current;

    if (current != null && current.length > 2) {
      contours.add(current);
    }

    _current = null;
  }

  List<List<List<double>>> read(String pathData) {
    writeSvgPathDataToPath(pathData, this);
    _flush();

    return contours;
  }
}

List<List<List<double>>> contours(String pathData) =>
    ContourReader().read(pathData);

double totalArea(String pathData) =>
    contours(pathData).fold(0.0, (sum, c) => sum + signedArea(c).abs());

/// Number of drawing commands in path data — the size the glyph will cost.
int commandCount(String pathData) =>
    RegExp('[MLCZ]').allMatches(pathData).length;

const kStroke = StrokeProperties(width: 2);
