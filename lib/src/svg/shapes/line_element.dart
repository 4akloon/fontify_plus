import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../../utils/svg.dart';
import '../element.dart';
import '../path.dart';
import 'path_convertible.dart';

class LineElement extends SvgElement implements PathConvertible {
  LineElement(this.p1, this.p2, SvgElement? parent, XmlElement element)
      : super(parent, element);

  factory LineElement.fromXmlElement(SvgElement? parent, XmlElement element) {
    final p1 = math.Point(
      element.getScalarAttribute('x1')!,
      element.getScalarAttribute('y1')!,
    );

    final p2 = math.Point(
      element.getScalarAttribute('x2')!,
      element.getScalarAttribute('y2')!,
    );

    return LineElement(p1, p2, parent, element);
  }

  /// Width given to the sliver that stands in for the line.
  ///
  /// A line has no area, so filling it directly would produce nothing. This is
  /// only a fallback: a line carrying a real `stroke-width` is outlined
  /// properly before it ever reaches here.
  static const _kW = 1;

  final math.Point p1;
  final math.Point p2;

  num get x1 => p1.x;

  num get y1 => p1.y;

  num get x2 => p2.x;

  num get y2 => p2.y;

  @override
  PathElement getPath() {
    final data =
        'M$x1 $y1 ${x1 + _kW} ${y1 + _kW} ${x2 + _kW} ${y2 + _kW} $x2 $y2 z';

    return PathElement(null, data, parent, xmlElement, transform: transform);
  }
}
