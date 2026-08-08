import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../utils/exception.dart';
import '../utils/svg.dart';
import 'element.dart';
import 'path.dart';
import 'stroke.dart';
import 'stroke_outliner.dart';

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
  /// centreline — see [outlineStrokeToPathData].
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

    final parsedVb = root
        .getAttribute('viewBox')
        ?.split(RegExp(r'[\s|,]'))
        .where((e) => e.isNotEmpty)
        .map(num.parse);
    final vb = [...?parsedVb];

    if (vb.isEmpty || vb.length > 4) {
      throw SvgParserException('viewBox must contain 1..4 parameters');
    }

    final fvb = [
      ...List.filled(4 - vb.length, 0),
      ...vb,
    ];

    final viewBox = math.Rectangle(fvb[0], fvb[1], fvb[2], fvb[3]);

    final svg = Svg(name, viewBox, [], root);

    final elementList = root.parseSvgElements(svg, ignoreShapes);
    svg.elementList.addAll(
      outlineStrokes ? _outlineStrokedPaths(elementList) : elementList,
    );

    return svg;
  }

  /// Replaces stroked paths with the filled region their stroke covers.
  ///
  /// Groups are already flattened by this point, so the list holds every path
  /// in the document.
  static List<SvgElement> _outlineStrokedPaths(List<SvgElement> elementList) {
    final result = <SvgElement>[];

    for (final element in elementList) {
      if (element is! PathElement) {
        result.add(element);
        continue;
      }

      final stroke = StrokeProperties.resolve(element);

      if (stroke == null) {
        result.add(element);
        continue;
      }

      // A path can be both filled and stroked; the fill is its own region and
      // survives independently of the stroke.
      if (_isFilled(element)) {
        result.add(element);
      }

      final outlined = outlineStrokeToPathData(element.data, stroke);

      if (outlined == null) {
        continue;
      }

      result.add(
        PathElement(
          element.fillRule,
          outlined,
          element.parent,
          element.xmlElement,
          transform: element.transform,
        ),
      );
    }

    return result;
  }

  /// Whether a path paints a fill in addition to its stroke.
  ///
  /// SVG's initial fill is black, so a path is filled unless it opts out — but
  /// outline-style icons universally set `fill="none"`, which is what makes the
  /// distinction worth drawing.
  static bool _isFilled(PathElement element) {
    SvgElement? current = element;

    while (current != null) {
      final fill = current.xmlElement?.getAttribute('fill')?.trim();

      if (fill != null) {
        return fill != 'none' && fill.isNotEmpty;
      }

      current = current.parent;
    }

    return true;
  }

  final String name;
  final math.Rectangle viewBox;
  final List<SvgElement> elementList;

  @override
  String toString() => '$name (${elementList.length} elements)';
}
