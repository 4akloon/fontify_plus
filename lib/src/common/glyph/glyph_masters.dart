import 'dart:math' as math;

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import '../../svg/geometry/cubic.dart';
import '../../svg/outline_builder.dart';
import '../../svg/stroke/stroke_outliner.dart';
import '../../svg/stroke/stroke_properties.dart';
import '../../svg/svg_parser.dart';
import '../../utils/exception.dart';
import '../../utils/logger.dart';
import '../outline.dart';
import '../stroke_width_range.dart';
import 'generic_glyph_base.dart';
import 'generic_glyph_metadata.dart';

/// A glyph drawn at both ends of a [StrokeWidthRange].
///
/// These are the only two drawings a variable font stores: every width
/// between them is reached by interpolating, point for point, between [min]
/// and [max] — which is only possible because [GlyphMasterBuilder] built them
/// to share a topology in the first place.
class GlyphMasters {
  const GlyphMasters({required this.min, required this.max});

  /// The glyph stroked at the range's minimum width.
  final GenericGlyph min;

  /// The glyph stroked at the range's maximum width.
  final GenericGlyph max;
}

/// Builds both endpoint masters of a glyph across a fixed [StrokeWidthRange].
///
/// [range] is configuration reused across every glyph in a font. A path can be
/// both filled and stroked, and the two are independent: the fill is built
/// once from the source commands and shared verbatim by both masters, because
/// a fill's area does not depend on stroke width. Each stroked shape is
/// planned once, at [StrokeWidthRange.max] — the densest subdivision and the
/// earliest offset degeneracy both occur at the widest offset, so a plan safe
/// there stays safe at every narrower width the axis can select — and its
/// [ContourShape] is recorded from that same evaluation, then applied to both
/// masters, so the two never make the classification decision independently
/// and drift apart.
///
/// Throws [SvgParserException] for anything the parser rejects, and
/// [IncompatibleMastersException] if the resulting masters cannot carry
/// variation deltas between them — which points at a bug in the geometry
/// pipeline, not at the input SVG.
class GlyphMasterBuilder {
  const GlyphMasterBuilder(this.range);

  /// The stroke-width axis ends applied to every glyph this builder produces.
  final StrokeWidthRange range;

  /// Builds both endpoint masters of glyph [name] from [xmlString].
  GlyphMasters fromSvg(String name, String xmlString) {
    final geometry = parseSvgGeometry(name, xmlString);
    final height = geometry.height;

    // The axis replaces every authored stroke-width with one value, so an icon
    // that deliberately drew a hairline detail against thicker main strokes
    // loses that hierarchy. The override is what "strokeWidth = 1.33" means and
    // is not up for negotiation here, but the loss is a real design decision
    // being taken on the author's behalf, so it is not taken quietly.
    final authoredWidths = {
      for (final shape in geometry.shapes)
        if (shape.stroke != null) shape.stroke!.width,
    };

    if (authoredWidths.length > 1) {
      final widths = (authoredWidths.toList()..sort()).join(', ');

      logger.w(
        '$name: draws strokes at more than one width ($widths). The '
        'stroke_width_range axis applies one width to all of them, so the '
        'difference between them is lost.',
      );
    }

    final minOutlines = <Outline>[];
    final maxOutlines = <Outline>[];

    for (final shape in geometry.shapes) {
      if (shape.filled) {
        final fill = outlinesFromCommands(
          shape.path.commands,
          height: height,
          fillRule: shape.path.fillType == vg.PathFillType.evenOdd
              ? FillRule.evenodd
              : FillRule.nonzero,
        );

        // One computation, two independent copies: a later per-master pass
        // (quantization, placement) mutates an Outline's point lists in place,
        // and sharing the same instance between masters would let a mutation on
        // one bleed into the other.
        minOutlines.addAll(fill.map((outline) => outline.copy()));
        maxOutlines.addAll(fill.map((outline) => outline.copy()));
      }

      final stroke = shape.stroke;

      if (stroke == null) {
        continue;
      }

      // The path's own authored stroke-width named one point on the axis, not
      // both ends of it; the range supplies both widths here instead. Cap, join
      // and miter limit are unaffected by width and carry over unchanged.
      final atMax = StrokeProperties(
        width: range.max,
        cap: stroke.cap,
        join: stroke.join,
        miterLimit: stroke.miterLimit,
      );

      final plan = StrokeOutliner(atMax).plan(shape.path.commands);
      final maxContours = plan.evaluate(range.max);
      final minContours = plan.evaluate(range.min);

      _checkContoursReplayShape(name, maxContours, minContours);

      // Recorded once, from the reference evaluation, and applied to both
      // widths: recording it per width would reintroduce exactly the structural
      // divergence the stroke plan exists to remove.
      final shapeAtMax = planContourShape(maxContours, height: height);

      maxOutlines.addAll(
        outlinesFromContours(maxContours, height: height, shape: shapeAtMax),
      );
      minOutlines.addAll(
        outlinesFromContours(minContours, height: height, shape: shapeAtMax),
      );
    }

    final bounds = math.Rectangle<num>(0, 0, geometry.width, geometry.height);

    final minGlyph = GenericGlyph(
      minOutlines,
      bounds,
      GenericGlyphMetadata(name: name),
    );
    final maxGlyph = GenericGlyph(
      maxOutlines,
      bounds,
      GenericGlyphMetadata(name: name),
    );

    checkCompatible(name, minGlyph, maxGlyph);

    return GlyphMasters(min: minGlyph, max: maxGlyph);
  }

  /// Throws unless [a] and [b] can carry variation deltas between them.
  ///
  /// An all-zero delta is legitimate — a fill does not vary with stroke width,
  /// and neither does a glyph whose stroke geometry happens to coincide at both
  /// ends of the range — so this compares structure only (contour count, point
  /// counts, on-curve flags) and never requires [a] and [b] to differ.
  void checkCompatible(String glyphName, GenericGlyph a, GenericGlyph b) {
    if (a.outlines.length != b.outlines.length) {
      throw IncompatibleMastersException(
        glyphName,
        'contour count ${a.outlines.length} vs ${b.outlines.length}',
      );
    }

    for (var i = 0; i < a.outlines.length; i++) {
      final x = a.outlines[i];
      final y = b.outlines[i];

      if (x.pointList.length != y.pointList.length) {
        throw IncompatibleMastersException(
          glyphName,
          'contour $i has ${x.pointList.length} points vs ${y.pointList.length}',
        );
      }

      for (var j = 0; j < x.isOnCurveList.length; j++) {
        if (x.isOnCurveList[j] != y.isOnCurveList[j]) {
          throw IncompatibleMastersException(
            glyphName,
            'contour $i point $j differs in on-curve flag',
          );
        }
      }
    }
  }
}

/// Throws unless every contour in [replay] has the same segment count as the
/// contour at the same position in [reference] — the evaluation
/// [planContourShape] recorded a [ContourShape] from.
///
/// [outlinesFromContours] indexes that recording positionally, one entry per
/// emitted segment. A replay whose segment count differs either reads past
/// the end of the recording or leaves part of it unread, and either way is
/// wrong in a way the caller has no way to notice on its own. The offsetter,
/// joiner and capper are built to reproduce the reference's structure at any
/// width, but nothing upstream of this checks that they actually did, so a
/// regression there would otherwise surface as a bare `RangeError` instead of
/// a message that names the glyph.
void _checkContoursReplayShape(
  String glyphName,
  List<List<Cubic>> reference,
  List<List<Cubic>> replay,
) {
  if (reference.length != replay.length) {
    throw IncompatibleMastersException(
      glyphName,
      'contour count ${reference.length} vs ${replay.length}',
    );
  }

  for (var c = 0; c < reference.length; c++) {
    final wanted = reference[c].length;
    final got = replay[c].length;

    if (wanted != got) {
      throw IncompatibleMastersException(
        glyphName,
        'contour $c diverges at segment index ${math.min(wanted, got)}: '
        'its shape was planned from $wanted segments, this evaluation has '
        '$got',
      );
    }
  }
}
