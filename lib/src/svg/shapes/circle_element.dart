import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../../utils/svg.dart';
import '../element.dart';
import '../path.dart';
import 'path_convertible.dart';

class CircleElement extends SvgElement implements PathConvertible {
  CircleElement(this.center, this.r, SvgElement? parent, XmlElement element)
      : super(parent, element);

  factory CircleElement.fromXmlElement(SvgElement? parent, XmlElement element) {
    final center = math.Point(
      element.getScalarAttribute('cx')!,
      element.getScalarAttribute('cy')!,
    );

    return CircleElement(
        center, element.getScalarAttribute('r')!, parent, element);
  }

  final math.Point center;
  final num r;

  num get cx => center.x;

  num get cy => center.y;

  @override
  PathElement getPath() {
    // Two half-turn arcs: a single arc command cannot describe a full circle,
    // because its start and end points would coincide.
    final data = 'M${cx - r},${cy}A$r,$r 0,0,0 ${cx + r},'
        '${cy}A$r,$r 0,0,0 ${cx - r},${cy}z';

    return PathElement(null, data, parent, xmlElement, transform: transform);
  }
}
