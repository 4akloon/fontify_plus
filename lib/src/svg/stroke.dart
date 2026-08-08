import 'element.dart';

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
class StrokeProperties {
  const StrokeProperties({
    required this.width,
    this.cap = LineCap.butt,
    this.join = LineJoin.miter,
    this.miterLimit = 4,
  });

  /// Resolves the stroke of [element], inheriting from ancestors as SVG
  /// presentation attributes do.
  ///
  /// Returns null when the element is not stroked — no `stroke`, an explicit
  /// `stroke="none"`, or a non-positive `stroke-width`. Such an element needs
  /// no conversion and must be left alone.
  static StrokeProperties? resolve(SvgElement element) {
    final stroke = _inherited(element, 'stroke');

    if (stroke == null || stroke == 'none' || stroke.isEmpty) {
      return null;
    }

    // SVG's initial stroke-width is 1.
    final width = _parseLength(_inherited(element, 'stroke-width')) ?? 1;

    if (width <= 0) {
      return null;
    }

    return StrokeProperties(
      width: width,
      cap: _parseCap(_inherited(element, 'stroke-linecap')),
      join: _parseJoin(_inherited(element, 'stroke-linejoin')),
      miterLimit: _parseLength(_inherited(element, 'stroke-miterlimit')) ?? 4,
    );
  }

  /// Stroke width in user units, as authored in the SVG's viewBox space.
  final double width;

  final LineCap cap;
  final LineJoin join;
  final double miterLimit;

  /// Half the stroke width — the distance the outline sits from the centreline.
  double get radius => width / 2;

  /// Walks up the element tree for a presentation attribute.
  static String? _inherited(SvgElement element, String name) {
    SvgElement? current = element;

    while (current != null) {
      final value = current.xmlElement?.getAttribute(name);

      if (value != null) {
        return value.trim();
      }

      current = current.parent;
    }

    return null;
  }

  /// Parses a length, tolerating a CSS unit suffix.
  ///
  /// Only absolute units make sense inside a viewBox, and icon exporters emit
  /// bare numbers or `px`, so anything else is treated as unitless rather than
  /// failing the whole conversion.
  static double? _parseLength(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final match = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?').stringMatch(
      value,
    );

    return match == null ? null : double.tryParse(match);
  }

  static LineCap _parseCap(String? value) {
    switch (value) {
      case 'round':
        return LineCap.round;
      case 'square':
        return LineCap.square;
      case 'butt':
      default:
        return LineCap.butt;
    }
  }

  static LineJoin _parseJoin(String? value) {
    switch (value) {
      case 'round':
        return LineJoin.round;
      case 'bevel':
        return LineJoin.bevel;
      case 'miter':
      case 'miter-clip':
      default:
        return LineJoin.miter;
    }
  }

  @override
  String toString() =>
      'StrokeProperties(width: $width, cap: $cap, join: $join, '
      'miterLimit: $miterLimit)';
}
