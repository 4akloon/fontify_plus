/// The bounding box of a glyph's ink.
///
/// Distinct from the glyph's bounds, which are its artboard: an icon drawn
/// small inside a 24-unit viewBox has metrics much smaller than its bounds,
/// and that difference is the design information normalization discards.
class GenericGlyphMetrics {
  const GenericGlyphMetrics({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  factory GenericGlyphMetrics.empty() =>
      const GenericGlyphMetrics(xMin: 0, xMax: 0, yMin: 0, yMax: 0);

  factory GenericGlyphMetrics.square(int unitsPerEm) =>
      GenericGlyphMetrics(xMin: 0, xMax: unitsPerEm, yMin: 0, yMax: unitsPerEm);

  final int xMin;
  final int xMax;
  final int yMin;
  final int yMax;

  int get width => xMax - xMin;

  int get height => yMax - yMin;
}
