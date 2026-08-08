import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../utils/exception.dart';
import '../utils/svg.dart';
import 'element.dart';
import 'stroke/stroke_pass.dart';

/// SVG root element.
class Svg extends SvgElement {
  Svg(
    this.name,
    this.viewBox,
    this.elementList,
    XmlElement xmlElement,
  ) : super(null, xmlElement);

  /// Parses SVG.
  ///
  /// If [ignoreShapes] is set to true, shapes (circle, rect, etc.) are
  /// discarded rather than converted into paths. Defaults to false — dropping
  /// them silently loses geometry the author drew.
  ///
  /// If [outlineStrokes] is set to true, stroked paths are replaced by the
  /// filled region their stroke covers. Defaults to true. Font glyphs are
  /// fill-only, so without this a stroked icon collapses to its zero-area
  /// centreline — see [outlineStrokedPaths].
  ///
  /// NOTE: Paint attributes other than stroke geometry (such as "fill" colour)
  /// are ignored, which means only the shape's outline is used.
  ///
  /// Throws [XmlParserException] if XML parsing exception occurs.
  /// Throws [SvgParserException] on any problem related to SVG parsing.
  factory Svg.parse(
    String name,
    String xmlString, {
    bool? ignoreShapes,
    bool? outlineStrokes,
  }) {
    ignoreShapes ??= false;
    outlineStrokes ??= true;

    final xml = XmlDocument.parse(xmlString);
    final root = xml.rootElement;

    if (root.name.local != 'svg') {
      throw SvgParserException('Root element must be SVG');
    }

    final svg = Svg(name, _parseViewBox(root), [], root);

    final elementList = root.parseSvgElements(svg, ignoreShapes);
    svg.elementList.addAll(
      outlineStrokes ? outlineStrokedPaths(elementList) : elementList,
    );

    return svg;
  }

  /// Reads the root's viewBox.
  ///
  /// Fewer than four numbers are left-padded with zeroes, matching how SVG
  /// treats an abbreviated list.
  static math.Rectangle<num> _parseViewBox(XmlElement root) {
    final parsed = root
        .getAttribute('viewBox')
        ?.split(RegExp(r'[\s|,]'))
        .where((e) => e.isNotEmpty)
        .map(num.parse);

    final values = [...?parsed];

    if (values.isEmpty || values.length > 4) {
      throw SvgParserException('viewBox must contain 1..4 parameters');
    }

    final padded = [...List.filled(4 - values.length, 0), ...values];

    return math.Rectangle(padded[0], padded[1], padded[2], padded[3]);
  }

  final String name;
  final math.Rectangle viewBox;
  final List<SvgElement> elementList;

  @override
  String toString() => '$name (${elementList.length} elements)';
}
