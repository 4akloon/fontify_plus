import '../element.dart';
import 'stroke_properties.dart';

final _leadingNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?');

/// Resolves the stroke of [element], inheriting from ancestors as SVG
/// presentation attributes do.
///
/// Returns null when the element is not stroked — no `stroke`, an explicit
/// `stroke="none"`, or a non-positive `stroke-width`. Such an element needs no
/// conversion and must be left alone.
StrokeProperties? resolveStroke(SvgElement element) {
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

/// Walks up the element tree for a presentation attribute.
String? _inherited(SvgElement element, String name) {
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
double? _parseLength(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final match = _leadingNumber.stringMatch(value);

  return match == null ? null : double.tryParse(match);
}

/// Anything unrecognised falls back to SVG's initial value, `butt`.
LineCap _parseCap(String? value) => switch (value) {
      'round' => LineCap.round,
      'square' => LineCap.square,
      _ => LineCap.butt,
    };

/// `miter-clip` is treated as `miter`: the two differ only past the miter
/// limit, which this converter bevels either way.
LineJoin _parseJoin(String? value) => switch (value) {
      'round' => LineJoin.round,
      'bevel' => LineJoin.bevel,
      _ => LineJoin.miter,
    };
