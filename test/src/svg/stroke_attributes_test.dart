import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:fontify_plus/src/svg/stroke_attributes.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

void main() {
  group('strokePropertiesOf', () {
    test('returns null for an unstroked paint', () {
      expect(strokePropertiesOf(null), isNull);
    });

    test('applies SVG initial values when vgc reports null', () {
      // `<path stroke="#000" d="..."/>` yields exactly this: a Stroke whose
      // geometry fields are all null.
      final result = strokePropertiesOf(const vg.Stroke())!;

      expect(result.width, 1);
      expect(result.cap, LineCap.butt);
      expect(result.join, LineJoin.miter);
      expect(result.miterLimit, 4);
    });

    test('carries explicit values through', () {
      final result = strokePropertiesOf(
        const vg.Stroke(
          width: 1.33,
          cap: vg.StrokeCap.round,
          join: vg.StrokeJoin.round,
          miterLimit: 10,
        ),
      )!;

      expect(result.width, 1.33);
      expect(result.cap, LineCap.round);
      expect(result.join, LineJoin.round);
      expect(result.miterLimit, 10);
    });

    test('maps square caps and bevel joins', () {
      final result = strokePropertiesOf(
        const vg.Stroke(cap: vg.StrokeCap.square, join: vg.StrokeJoin.bevel),
      )!;

      expect(result.cap, LineCap.square);
      expect(result.join, LineJoin.bevel);
    });

    test('returns null for a fully transparent stroke', () {
      // vgc reports `stroke-opacity="0"` as a Stroke with zero alpha, not as
      // no stroke at all.
      expect(
        strokePropertiesOf(const vg.Stroke(color: vg.Color(0x00000000))),
        isNull,
      );
    });

    test('returns null for a non-positive width', () {
      // A zero-width stroke paints nothing. Offsetting by it would fold the
      // two walls onto the centreline rather than produce no contour at all.
      expect(strokePropertiesOf(const vg.Stroke(width: 0)), isNull);
      expect(strokePropertiesOf(const vg.Stroke(width: -2)), isNull);
    });
  });
}
