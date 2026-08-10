import 'dart:math' as math;

import '../common/generic_glyph.dart';
import '../utils/misc.dart';

/// Scale changes closer to identity than this are not worth applying.
///
/// Must match [GlyphTransform.resize]'s constant of the same name: both
/// compute the same ratio, and a placement that collapsed to no-op at a
/// different threshold than `resize` would stop reproducing [GlyphFitting.fit]
/// exactly.
const _kNegligibleScale = .02;

/// How a glyph is fitted onto the em square.
///
/// Replaces a nullable ascender/descender/fontHeight triple that could only be
/// checked at runtime: each way of fitting now carries exactly the values it
/// needs, so an inconsistent combination cannot be expressed.
abstract class GlyphFitting {
  const GlyphFitting();

  GenericGlyph fit(GenericGlyph glyph);

  /// The transform [fit] would apply to [reference].
  GlyphPlacement placementFor(GenericGlyph reference);
}

/// A fitting transform taken from one glyph so several masters land
/// identically on the em square.
///
/// Fitting each master on its own would scale them differently — a thicker
/// stroke has a bigger ink box — which moves the centreline between masters
/// and bends every interpolated width.
class GlyphPlacement {
  const GlyphPlacement({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  /// Uniform scale factor, taken from the reference glyph.
  final double scale;

  /// Horizontal translation applied after scaling.
  final double offsetX;

  /// Vertical translation applied after scaling.
  final double offsetY;

  /// Scales, then translates, [glyph] — reproducing [GlyphFitting.fit]'s
  /// `resize().center()` pipeline exactly when [glyph] is the reference this
  /// placement was derived from.
  GenericGlyph apply(GenericGlyph glyph) => _translate(
    scale == 1 ? glyph : _scale(glyph, scale),
    offsetX,
    offsetY,
  );
}

/// The point-mapping [GlyphTransform.resize] applies when it does not take
/// its early return, lifted so a [GlyphPlacement] can apply a scale it was
/// handed rather than one it computes from the glyph being scaled.
GenericGlyph _scale(GenericGlyph glyph, double scale) => GenericGlyph(
  [
    for (final outline in glyph.outlines)
      outline.copy()
        ..pointList.setAll(
          0,
          [
            for (final point in outline.pointList)
              math.Point<num>(point.x, point.y) * scale,
          ],
        ),
  ],
  math.Rectangle.fromPoints(
    glyph.bounds.bottomLeft.toDoublePoint() * scale,
    glyph.bounds.topRight.toDoublePoint() * scale,
  ),
  glyph.metadata,
);

/// The point-mapping [GlyphTransform.center] applies, lifted so a
/// [GlyphPlacement] can apply an offset computed once from a reference
/// glyph's metrics to a different glyph that shares its topology.
GenericGlyph _translate(GenericGlyph glyph, double dx, double dy) =>
    GenericGlyph(
      [
        for (final outline in glyph.outlines)
          outline.copy()
            ..pointList.setAll(
              0,
              [
                for (final point in outline.pointList)
                  math.Point<num>(point.x + dx, point.y + dy),
              ],
            ),
      ],
      math.Rectangle(
        glyph.bounds.left + dx,
        glyph.bounds.bottom + dy,
        glyph.bounds.width,
        glyph.bounds.height,
      ),
      glyph.metadata,
    );

/// Scales each glyph so its own longest side fills the em band, then centres
/// it.
///
/// Discards how much of its artboard an icon was drawn to occupy, which is
/// design information — a full-bleed circle and a small arrow end up the same
/// size. Only appropriate for icons collected from mismatched sources.
class NormalizedFitting extends GlyphFitting {
  const NormalizedFitting({required this.ascender, required this.descender});

  final int ascender;
  final int descender;

  @override
  GenericGlyph fit(GenericGlyph glyph) => glyph
      .resize(ascender: ascender, descender: descender)
      .center(ascender, descender);

  @override
  GlyphPlacement placementFor(GenericGlyph reference) {
    final metrics = reference.metrics;
    final longestSide = math.max(metrics.height, metrics.width);

    // Same ratio [GlyphTransform.resize] computes for the ascender/descender
    // case — see the note there about summing rather than subtracting.
    final sideRatio = (ascender - descender) / longestSide;

    // Mirrors resize's early return: below the threshold, resize leaves the
    // glyph untouched, so the placement must apply no scaling at all rather
    // than a scale that is merely close to 1.
    final scale = (sideRatio - 1).abs() < _kNegligibleScale ? 1.0 : sideRatio;

    // center()'s offsets come from the metrics of resize()'s output, not the
    // pre-scale glyph — so this must scale first, exactly as resize would,
    // before reading metrics off the result.
    final scaled = scale == 1 ? reference : _scale(reference, scale);
    final scaledMetrics = scaled.metrics;

    return GlyphPlacement(
      scale: scale,
      offsetX: -scaledMetrics.xMin.toDouble(),
      offsetY:
          (ascender + descender) / 2 -
          scaledMetrics.height / 2 -
          scaledMetrics.yMin,
    );
  }
}

/// Maps each glyph's artboard onto the em square.
///
/// The relative sizes the icons were drawn at survive, which is what an icon
/// set almost always wants.
class ArtboardFitting extends GlyphFitting {
  const ArtboardFitting({required this.fontHeight});

  final int fontHeight;

  @override
  GenericGlyph fit(GenericGlyph glyph) => glyph.resize(fontHeight: fontHeight);

  @override
  GlyphPlacement placementFor(GenericGlyph reference) {
    // Same ratio [GlyphTransform.resize] computes for the fontHeight case:
    // against the artboard (bounds), not the ink (metrics).
    final longestSide = reference.bounds.height.toInt();
    final sideRatio = fontHeight / longestSide;

    // Mirrors resize's early return, same as NormalizedFitting.placementFor.
    final scale = (sideRatio - 1).abs() < _kNegligibleScale ? 1.0 : sideRatio;

    // fit() never calls center() for this strategy, so there is nothing to
    // translate by.
    return GlyphPlacement(scale: scale, offsetX: 0, offsetY: 0);
  }
}
