import 'dart:math' as math;

import 'package:path_parsing/path_parsing.dart';
import 'package:vector_math/vector_math.dart';

import '../common/outline.dart';
import 'path.dart';
import 'svg.dart';

/// A helper for converting SVG path to generic outline format.
class PathToOutlineConverter extends PathProxy {
  PathToOutlineConverter(this.svg, this.path);

  final Svg svg;
  final PathElement path;

  final _outlines = <Outline>[];
  final _points = <math.Point<num>>[];
  final _isOnCurve = <bool>[];

  @override
  void close() {
    final isEvenOdd = path.fillRule == 'evenodd';
    final fillRule = isEvenOdd ? FillRule.evenodd : FillRule.nonzero;

    // Y coordinates have to be flipped
    final bottom = svg.viewBox.top + svg.viewBox.height;
    var points = _points.map((p) => math.Point<num>(p.x, bottom - p.y));

    // Applying transform
    final transform = path.getResultTransformMatrix();
    if (transform != null) {
      points = points.map((e) {
        final v = Vector3(e.x.toDouble(), e.y.toDouble(), 1)
          ..applyMatrix3(transform);

        return math.Point(v.x, v.y);
      });
    }

    final outline =
        Outline(points.toList(), [..._isOnCurve], false, false, fillRule);
    _outlines.add(outline);

    _points.clear();
    _isOnCurve.clear();
  }

  @override
  void lineTo(double x, double y) {
    _points.add(math.Point<num>(x, y));
    _isOnCurve.add(true);
  }

  @override
  void moveTo(double x, double y) {
    // A moveTo starts a new subpath. Without flushing here, a path such as
    // "M8 2V13 M13 8H2" — two separate strokes, no Z — would accumulate into a
    // single outline and render as one zigzag contour.
    if (_points.isNotEmpty) {
      close();
    }

    _points.add(math.Point<num>(x, y));
    _isOnCurve.add(true);
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
    final curvePoints = [
      math.Point<num>(x1, y1),
      math.Point<num>(x2, y2),
      math.Point<num>(x3, y3),
    ];

    _points.addAll(curvePoints);
    _isOnCurve.addAll([false, false, true]);
  }

  /// Converts an SVG `<path>` to a list of outlines.
  List<Outline> convert() {
    writeSvgPathDataToPath(path.data, this);

    if (_points.isNotEmpty) {
      close();
    }

    return _outlines;
  }
}
