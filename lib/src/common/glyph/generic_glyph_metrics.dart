/// The bounding box of a glyph's ink.
///
/// Distinct from the glyph's bounds, which are its artboard: an icon drawn
/// small inside a 24-unit viewBox has metrics much smaller than its bounds,
/// and that difference is the design information normalization discards.
class GenericGlyphMetrics {
  GenericGlyphMetrics(this.xMin, this.xMax, this.yMin, this.yMax);

  factory GenericGlyphMetrics.empty() => GenericGlyphMetrics(0, 0, 0, 0);

  factory GenericGlyphMetrics.square(int unitsPerEm) =>
      GenericGlyphMetrics(0, unitsPerEm, 0, unitsPerEm);

  final int xMin;
  final int xMax;
  final int yMin;
  final int yMax;

  int get width => xMax - xMin;

  int get height => yMax - yMin;
}
