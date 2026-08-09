import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import 'stroke/stroke_properties.dart';

/// SVG's initial `stroke-width`.
const _kInitialWidth = 1.0;

/// SVG's initial `stroke-miterlimit`.
const _kInitialMiterLimit = 4.0;

/// [stroke] as the geometry inputs the outliner needs, or null when it
/// describes nothing strokeable.
///
/// `vector_graphics_compiler` reports each field as null when the SVG
/// attribute is absent rather than substituting a default, so SVG's initial
/// values are applied here — once — instead of being assumed at each use.
StrokeProperties? strokePropertiesOf(vg.Stroke? stroke) {
  if (stroke == null) {
    return null;
  }

  // A fully transparent stroke paints nothing. vgc reports it as a Stroke with
  // zero alpha rather than as no stroke, so `stroke-opacity="0"` arrives here
  // looking perfectly strokeable.
  if (stroke.shader == null && stroke.color.value >> 24 & 0xFF == 0) {
    return null;
  }

  final width = stroke.width ?? _kInitialWidth;

  // A non-positive width paints nothing. Offsetting by it would fold the two
  // walls onto the centreline instead of producing no contour at all.
  if (width <= 0) {
    return null;
  }

  return StrokeProperties(
    width: width,
    cap: _cap(stroke.cap),
    join: _join(stroke.join),
    miterLimit: stroke.miterLimit ?? _kInitialMiterLimit,
  );
}

/// Anything unrecognised falls back to SVG's initial value, `butt`.
LineCap _cap(vg.StrokeCap? cap) => switch (cap) {
  vg.StrokeCap.round => LineCap.round,
  vg.StrokeCap.square => LineCap.square,
  _ => LineCap.butt,
};

/// Anything unrecognised falls back to SVG's initial value, `miter`.
LineJoin _join(vg.StrokeJoin? join) => switch (join) {
  vg.StrokeJoin.round => LineJoin.round,
  vg.StrokeJoin.bevel => LineJoin.bevel,
  _ => LineJoin.miter,
};
