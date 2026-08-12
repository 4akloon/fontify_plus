/// The stroke widths a variable font's `wght` axis spans.
///
/// Only the two endpoints exist as masters. Every width between them is
/// reproduced exactly by interpolation, because the offsetter's control points
/// are affine in the stroke width — so listing intermediate stops would add
/// data without adding reachable widths.
///
/// The range is not free and has no wide default: it sets the magnitude of the
/// variation deltas, and — because outlining is planned at [max] — how deeply
/// every glyph is subdivided, for every icon in the font.
class StrokeWidthRange {
  StrokeWidthRange(this.min, this.max) {
    if (min <= 0) {
      throw ArgumentError.value(min, 'min', 'Stroke width must be positive');
    }

    if (max <= min) {
      throw ArgumentError.value(max, 'max', 'Must be greater than min ($min)');
    }
  }

  final double min;
  final double max;

  @override
  String toString() => 'StrokeWidthRange($min, $max)';
}
