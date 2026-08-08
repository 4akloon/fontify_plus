import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../../utils/svg.dart';
import '../element.dart';
import '../path.dart';
import 'path_convertible.dart';

class RectElement extends SvgElement implements PathConvertible {
  RectElement(
    this.rectangle,
    this.rx,
    this.ry,
    SvgElement? parent,
    XmlElement element,
  ) : super(parent, element);

  factory RectElement.fromXmlElement(SvgElement? parent, XmlElement element) {
    final rect = math.Rectangle(
      element.getScalarAttribute('x')!,
      element.getScalarAttribute('y')!,
      element.getScalarAttribute('width')!,
      element.getScalarAttribute('height')!,
    );

    var rx = element.getScalarAttribute('rx', zeroIfAbsent: false);
    var ry = element.getScalarAttribute('ry', zeroIfAbsent: false);

    // Either radius alone stands for both, as SVG requires.
    ry ??= rx;
    rx ??= ry;

    return RectElement(rect, rx ?? 0, ry ?? 0, parent, element);
  }

  final math.Rectangle rectangle;
  final num rx;
  final num ry;

  num get x => rectangle.left;

  num get y => rectangle.top;

  num get width => rectangle.width;

  num get height => rectangle.height;

  bool get _isRounded => rx != 0 || ry != 0;

  @override
  PathElement getPath() {
    final data = StringBuffer('M${x + rx} $y')
      ..write('h${width - rx * 2}')
      ..write(_corner(rx, ry))
      ..write('v${height - ry * 2}')
      ..write(_corner(-rx, ry))
      ..write('h${-(width - rx * 2)}')
      ..write(_corner(-rx, -ry))
      ..write('v${-(height - ry * 2)}')
      ..write(_corner(rx, -ry))
      ..write('z');

    return PathElement(
      null,
      data.toString(),
      parent,
      xmlElement,
      transform: transform,
    );
  }

  /// One rounded corner, or nothing when the rectangle has square corners.
  String _corner(num dx, num dy) => _isRounded ? 'a $rx $ry 0 0 1 $dx $dy' : '';
}
