/// How the ends of an open stroked subpath are drawn.
enum LineCap {
  /// The stroke stops squarely at the endpoint.
  butt,

  /// The stroke is capped with a semicircle of radius `stroke-width / 2`.
  round,

  /// The stroke is extended by `stroke-width / 2` and capped squarely.
  square,
}

/// How the corner between two segments of a stroked path is drawn.
enum LineJoin {
  /// The outer edges are extended until they meet, unless that would exceed
  /// `stroke-miterlimit`, in which case the corner falls back to [bevel].
  miter,

  /// The corner is rounded with an arc of radius `stroke-width / 2`.
  round,

  /// The outer edges are joined with a straight line.
  bevel,
}

/// The subset of SVG stroke presentation attributes that affects geometry.
///
/// Font glyphs are filled outlines with no notion of stroking, so a stroked
/// path has to be converted into the region it covers before it can become a
/// glyph. These are the inputs that conversion needs.
///
/// Reading them off a parsed SVG is a separate concern, handled by
/// `strokePropertiesOf` in `stroke_attributes.dart`.
class StrokeProperties {
  const StrokeProperties({
    required this.width,
    this.cap = LineCap.butt,
    this.join = LineJoin.miter,
    this.miterLimit = 4,
  });

  /// Stroke width in user units, as authored in the SVG's viewBox space.
  final double width;

  final LineCap cap;
  final LineJoin join;
  final double miterLimit;

  /// Half the stroke width — the distance the outline sits from the
  /// centreline.
  double get radius => width / 2;

  @override
  String toString() =>
      'StrokeProperties(width: $width, cap: $cap, join: $join, '
      'miterLimit: $miterLimit)';
}
