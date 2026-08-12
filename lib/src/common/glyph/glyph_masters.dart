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

/// A glyph drawn at the ends of a [StrokeWidthRange], and optionally at one
/// width in between.
///
/// [min] and [max] are the drawings the axis interpolates between, point for
/// point — which is only possible because [GlyphMasterBuilder] built them to
/// share a topology in the first place. [atDefault] is a third drawing of the
/// same topology, present only when the caller asked for one.
class GlyphMasters {
  const GlyphMasters({required this.min, required this.max, this.atDefault});

  /// The glyph stroked at the range's minimum width.
  final GenericGlyph min;

  /// The glyph stroked at the range's maximum width.
  final GenericGlyph max;

  /// The glyph stroked at [GlyphMasterBuilder.defaultWidth], or null when no
  /// default width was supplied.
  ///
  /// The interpolated outline at any intermediate width is already exact —
  /// the offsetter's control points are affine in the stroke width — so this
  /// master adds no new geometry. It exists so the font can carry a named
  /// instance, and a `wght` default, at a width other than an axis end
  /// without moving either end.
  final GenericGlyph? atDefault;
}

/// Builds both endpoint masters of a glyph across a fixed [StrokeWidthRange],
/// plus an optional third master at [defaultWidth].
///
/// [range] and [defaultWidth] are configuration reused across every glyph in a
/// font. A path can be both filled and stroked, and the two are independent:
/// the fill is built once from the source commands and shared verbatim by
/// every master, because a fill's area does not depend on stroke width. Each
/// stroked shape is planned once, at [StrokeWidthRange.max] — the densest
/// subdivision and the earliest offset degeneracy both occur at the widest
/// offset, so a plan safe there stays safe at every narrower width the axis
/// can select — and its [ContourShape] is recorded from that same evaluation,
/// then applied to every master, so no two of them ever make the
/// classification decision independently and drift apart.
///
/// Throws [SvgParserException] for anything the parser rejects, and
/// [IncompatibleMastersException] if the resulting masters cannot carry
/// variation deltas between them — which points at a bug in the geometry
/// pipeline, not at the input SVG.
class GlyphMasterBuilder {
  /// Builds masters at the ends of [range], and at [defaultWidth] when one is
  /// given.
  ///
  /// Assumes [defaultWidth], if non-null, is already validated by the caller:
  /// finite, inside [range], and distinct from both of its ends. Nothing here
  /// re-checks that. The rules are enforced once, at the boundary the value
  /// arrives through — the Dart API raising [ArgumentError], the YAML/CLI
  /// config raising a `FontifyException` that names the offending key — each
  /// of which can say what went wrong in the vocabulary its own callers
  /// expect. Repeating the check here would be a third copy of those rules to
  /// keep in step, in a third vocabulary, reachable only after the other two
  /// had already let a bad value through.
  ///
  /// Not validating is not the same as accepting silently. A width that is
  /// non-finite, zero or negative is rejected by `StrokePlan.evaluate` with
  /// an [ArgumentError] naming it, which every width passes through, rather
  /// than reaching the font as NaN coordinates. That check is explicit
  /// because the geometry no longer catches it by accident: a degenerate
  /// width used to perturb the offset points enough to change a join's
  /// branch, and so a contour's segment count, but the joins now decide on
  /// the source tangents — the fix for masters diverging at ordinary widths
  /// — and replay a NaN width's structure exactly.
  const GlyphMasterBuilder(this.range, {this.defaultWidth});

  /// The stroke-width axis ends applied to every glyph this builder produces.
  final StrokeWidthRange range;

  /// The width of the third master, or null to build only the two endpoints.
  final double? defaultWidth;

  /// Builds the masters of glyph [name] from [xmlString].
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

    // Read once into a local so the null check below promotes it, and so the
    // "is there a third master" question is asked in exactly one form.
    final defaultWidth = this.defaultWidth;

    final minOutlines = <Outline>[];
    final maxOutlines = <Outline>[];

    // Left empty, and never read, when no default width was supplied.
    final atDefaultOutlines = <Outline>[];

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

        if (defaultWidth != null) {
          atDefaultOutlines.addAll(fill.map((outline) => outline.copy()));
        }
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

      if (defaultWidth != null) {
        // Evaluated from the same plan, and replayed against the same
        // recorded shape, as the two endpoints: a third master is only
        // interpolatable with them if it was never allowed to classify its
        // own geometry.
        final defaultContours = plan.evaluate(defaultWidth);

        _checkContoursReplayShape(name, maxContours, defaultContours);

        atDefaultOutlines.addAll(
          outlinesFromContours(
            defaultContours,
            height: height,
            shape: shapeAtMax,
          ),
        );
      }
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

    final atDefaultGlyph = defaultWidth == null
        ? null
        : GenericGlyph(
            atDefaultOutlines,
            bounds,
            GenericGlyphMetadata(name: name),
          );

    checkCompatible(name, minGlyph, maxGlyph);

    if (atDefaultGlyph != null) {
      checkCompatible(name, atDefaultGlyph, maxGlyph);
    }

    return GlyphMasters(
      min: minGlyph,
      max: maxGlyph,
      atDefault: atDefaultGlyph,
    );
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
