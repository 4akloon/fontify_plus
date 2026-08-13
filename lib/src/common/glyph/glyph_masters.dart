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
/// can select — and its [ContourShape] is the intersection of every master's
/// own classification, so a piece that is a cubic at any width stays a cubic
/// on all of them. Recording straightness from the wide evaluation alone
/// froze collapsed inner walls as lines.
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
      final fill = [
        if (shape.filled)
          ...outlinesFromCommands(
            shape.path.commands,
            height: height,
            fillRule: shape.path.fillType == vg.PathFillType.evenOdd
                ? FillRule.evenodd
                : FillRule.nonzero,
          ),
      ];

      final stroke = shape.stroke;

      if (stroke != null) {
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

        final defaultContours = defaultWidth == null
            ? null
            : plan.evaluate(defaultWidth);

        if (defaultContours != null) {
          _checkContoursReplayShape(name, maxContours, defaultContours);
        }

        // Straight only where every master is straight; drop the closing
        // repeat only where every master drops it. Recording from max alone
        // froze collapsed inner walls as lines, and keeping a cubic while
        // still dropping its end left CFF contours ending off-curve.
        var contourShape = planContourShape(
          maxContours,
          height: height,
        ).and(planContourShape(minContours, height: height));

        if (defaultContours != null) {
          contourShape = contourShape.and(
            planContourShape(defaultContours, height: height),
          );
        }

        final maxStroke = outlinesFromContours(
          maxContours,
          height: height,
          shape: contourShape,
        );

        // Same topology at every width, so the outer wall's winding at max
        // orients the fill for every master.
        alignFillWindingToStrokeOuter(fill, maxStroke);

        minOutlines
          ..addAll(fill.map((outline) => outline.copy()))
          ..addAll(
            outlinesFromContours(
              minContours,
              height: height,
              shape: contourShape,
            ),
          );
        maxOutlines
          ..addAll(fill.map((outline) => outline.copy()))
          ..addAll(maxStroke);

        if (defaultContours != null) {
          atDefaultOutlines
            ..addAll(fill.map((outline) => outline.copy()))
            ..addAll(
              outlinesFromContours(
                defaultContours,
                height: height,
                shape: contourShape,
              ),
            );
        }
      } else {
        minOutlines.addAll(fill.map((outline) => outline.copy()));
        maxOutlines.addAll(fill.map((outline) => outline.copy()));

        if (defaultWidth != null) {
          atDefaultOutlines.addAll(fill.map((outline) => outline.copy()));
        }
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
///
/// No input can currently reach it. Every branch downstream of
/// `StrokePlan.evaluate` decides on the source tangents, which do not depend
/// on the width, and the one that did not — `arcToCubics` emitting nothing
/// below [kZeroLength] — is now unreachable because `evaluate` rejects a
/// width whose radius is that small. That is the point rather than a reason
/// to delete this: it guards against a *code* change reintroducing a
/// width-dependent branch, which is exactly the defect that made real icons
/// fail to build, and it went unnoticed because nothing asserted the
/// invariant it was supposed to protect. It is deliberately untested for
/// want of any way to reach it; `checkCompatible` above covers the same
/// exception on a path that is reachable.
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
