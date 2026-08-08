import 'package:xml/xml.dart';

import '../element.dart';
import '../path.dart';
import 'path_convertible.dart';

/// A shape whose geometry is a bare list of points.
///
/// NOTE: the contour is closed for both subclasses. That is correct for
/// `polygon`; for `polyline` SVG leaves the contour open, and closing it is a
/// long-standing simplification of this converter. It only shows on a stroked
/// polyline, where an extra closing segment appears.
abstract class PointListElement extends SvgElement implements PathConvertible {
  PointListElement(this.points, SvgElement? parent, XmlElement element)
      : super(parent, element);

  final String points;

  @override
  PathElement getPath() => PathElement(
        null,
        'M${points}z',
        parent,
        xmlElement,
        transform: transform,
      );
}

class PolylineElement extends PointListElement {
  PolylineElement(super.points, super.parent, super.element);

  factory PolylineElement.fromXmlElement(
    SvgElement? parent,
    XmlElement element,
  ) =>
      PolylineElement(element.getAttribute('points')!, parent, element);
}

class PolygonElement extends PointListElement {
  PolygonElement(super.points, super.parent, super.element);

  factory PolygonElement.fromXmlElement(
    SvgElement? parent,
    XmlElement element,
  ) =>
      PolygonElement(element.getAttribute('points')!, parent, element);
}
