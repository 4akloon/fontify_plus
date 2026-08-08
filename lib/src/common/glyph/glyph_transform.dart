import 'dart:math' as math;

import '../../utils/misc.dart';
import '../outline.dart';
import 'generic_glyph_base.dart';

/// Scale changes closer to identity than this are not worth applying.
const _kNegligibleScale = .02;

/// Fitting a glyph to the em square.
extension GlyphTransform on GenericGlyph {
  /// Resizes according to ascender/descender or a font height.
  GenericGlyph resize({int? ascender, int? descender, int? fontHeight}) {
    final int longestSide;
    final double sideRatio;

    if (ascender != null && descender != null) {
      final metrics = this.metrics;
      longestSide = math.max(metrics.height, metrics.width);

      // The band runs from the descender — which is negative — up to the
      // ascender, so its height is the difference between them. Summing gives
      // ascender minus the descender's depth, which for the defaults is 700
      // rather than 1000: every glyph came out at 70% of the em square.
      //
      // NOTE: [center] sums these same two values, and is correct to do so —
      // there it is computing the band's midpoint, not its height.
      sideRatio = (ascender - descender) / longestSide;
    } else if (fontHeight != null) {
      longestSide = bounds.height.toInt();
      sideRatio = fontHeight / longestSide;
    } else {
      throw ArgumentError('Wrong parameters for resizing');
    }

    // No need to resize
    if ((sideRatio - 1).abs() < _kNegligibleScale) {
      return this;
    }

    return GenericGlyph(
      _mapPoints((p) => math.Point<num>(p.x, p.y) * sideRatio),
      math.Rectangle.fromPoints(
        bounds.bottomLeft.toDoublePoint() * sideRatio,
        bounds.topRight.toDoublePoint() * sideRatio,
      ),
      metadata,
    );
  }

  /// Centres the glyph's ink horizontally and within the em band.
  GenericGlyph center(int ascender, int descender) {
    final metrics = this.metrics;

    final offsetX = -metrics.xMin;

    // Sum, not difference: this is the midpoint of the band between the
    // descender and the ascender. See the note in [resize], which needs the
    // band's height and so subtracts instead.
    final offsetY =
        (ascender + descender) / 2 - metrics.height / 2 - metrics.yMin;

    return GenericGlyph(
      _mapPoints((p) => math.Point<num>(p.x + offsetX, p.y + offsetY)),
      math.Rectangle(
        bounds.left + offsetX,
        bounds.bottom + offsetY,
        bounds.width,
        bounds.height,
      ),
      metadata,
    );
  }

  /// Copies the outlines with every point put through [transform].
  List<Outline> _mapPoints(
      math.Point<num> Function(math.Point<num>) transform) {
    return [
      for (final outline in outlines)
        outline.copy()
          ..pointList.setAll(
            0,
            [for (final point in outline.pointList) transform(point)],
          ),
    ];
  }
}
