import 'dart:math' as math;

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import '../../otf/table/glyph/simple.dart';
import '../../svg/outline_builder.dart';
import '../../svg/stroke/stroke_outliner.dart';
import '../../svg/svg_parser.dart';
import '../../utils/misc.dart';
import '../outline.dart';
import 'generic_glyph_metadata.dart';
import 'generic_glyph_metrics.dart';

/// Generic glyph.
/// Used as an intermediate storage between different types of glyphs
/// (including OpenType's CharString, TrueType outlines).
///
/// Conversion to and from those formats lives in extensions beside this file,
/// so that this class stays the glyph's geometry and nothing else.
class GenericGlyph {
  GenericGlyph(this.outlines, this.bounds, [GenericGlyphMetadata? metadata])
    : metadata = metadata ?? GenericGlyphMetadata();

  GenericGlyph.empty()
    : outlines = [],
      bounds = const math.Rectangle(0, 0, 0, 0),
      metadata = GenericGlyphMetadata();

  factory GenericGlyph.fromSimpleTrueTypeGlyph(SimpleGlyph glyph) {
    final isOnCurveList = glyph.flags.map((e) => e.onCurvePoint).toList();
    final endPoints = [-1, ...glyph.endPtsOfContours];

    final outlines = [
      for (var i = 1; i < endPoints.length; i++)
        Outline(
          glyph.pointList.sublist(endPoints[i - 1] + 1, endPoints[i] + 1),
          isOnCurveList.sublist(endPoints[i - 1] + 1, endPoints[i] + 1),
          true,
          true,
          FillRule.nonzero,
        ),
    ];

    final bounds = math.Rectangle(
      glyph.header.xMin,
      glyph.header.yMin,
      glyph.header.xMax - glyph.header.xMin,
      glyph.header.yMax - glyph.header.yMin,
    );

    return GenericGlyph(outlines, bounds);
  }

  /// Builds a glyph from an SVG document.
  ///
  /// [name] identifies the icon in errors and in the generated class.
  ///
  /// When [outlineStrokes] is true — the default — a stroked path is replaced
  /// by the filled region its stroke covers. Font glyphs are fill-only, so
  /// without it an outline-style icon collapses to its zero-area centreline.
  ///
  /// Throws `SvgParserException` for anything the parser rejects.
  factory GenericGlyph.fromSvg(
    String name,
    String xmlString, {
    bool outlineStrokes = true,
  }) {
    final geometry = parseSvgGeometry(name, xmlString);
    final height = geometry.height;
    final outlines = <Outline>[];

    for (final shape in geometry.shapes) {
      final stroke = outlineStrokes ? shape.stroke : null;

      // A path can be both filled and stroked; the fill is its own region and
      // survives independently. With outlining off, the raw path is all there
      // is to emit — which is what makes a stroked icon come out blank.
      if (shape.filled || stroke == null) {
        outlines.addAll(
          outlinesFromCommands(
            shape.path.commands,
            height: height,
            fillRule: shape.path.fillType == vg.PathFillType.evenOdd
                ? FillRule.evenodd
                : FillRule.nonzero,
          ),
        );
      }

      if (stroke == null) {
        continue;
      }

      outlines.addAll(
        outlinesFromContours(
          StrokeOutliner(stroke).outline(shape.path.commands),
          height: height,
        ),
      );
    }

    return GenericGlyph(
      outlines,
      math.Rectangle<num>(0, 0, geometry.width, geometry.height),
      GenericGlyphMetadata(name: name),
    );
  }

  final List<Outline> outlines;
  final math.Rectangle bounds;
  final GenericGlyphMetadata metadata;

  /// Every point of every contour, in order.
  List<math.Point> get pointList => [for (final o in outlines) ...o.pointList];

  /// On-curve flags aligned with [pointList].
  List<bool> get isOnCurveList => [
    for (final o in outlines) ...o.isOnCurveList,
  ];

  /// Index into [pointList] of each contour's last point.
  List<int> get endPoints {
    final endPoints = [-1];

    for (final outline in outlines) {
      endPoints.add(endPoints.last + outline.pointList.length);
    }

    return endPoints..removeAt(0);
  }

  /// The bounding box of this glyph's ink.
  GenericGlyphMetrics get metrics {
    final points = pointList;

    if (points.isEmpty) {
      return GenericGlyphMetrics.empty();
    }

    var xMin = kInt32Max;
    var yMin = kInt32Max;
    var xMax = kInt32Min;
    var yMax = kInt32Min;

    for (final p in points) {
      xMin = math.min(xMin, p.x.toInt());
      xMax = math.max(xMax, p.x.toInt());
      yMin = math.min(yMin, p.y.toInt());
      yMax = math.max(yMax, p.y.toInt());
    }

    return GenericGlyphMetrics(xMin, xMax, yMin, yMax);
  }

  /// Deep copy of a glyph and its outlines
  GenericGlyph copy() => GenericGlyph(
    [for (final outline in outlines) outline.copy()],
    bounds,
    metadata.copy(),
  );
}
