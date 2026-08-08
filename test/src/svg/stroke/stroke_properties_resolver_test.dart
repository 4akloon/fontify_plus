import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties_resolver.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:test/test.dart';

void main() {
  group('StrokeProperties', () {
    StrokeProperties? resolveFrom(String svg) {
      final parsed = Svg.parse('t', svg, outlineStrokes: false);
      return resolveStroke(parsed.elementList.first);
    }

    test('reads stroke geometry from the element', () {
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16"><path d="M0 0H8" stroke="#000" '
        'stroke-width="3" stroke-linecap="round" stroke-linejoin="bevel" '
        'stroke-miterlimit="8"/></svg>',
      );

      expect(props, isNotNull);
      expect(props!.width, 3);
      expect(props.radius, 1.5);
      expect(props.cap, LineCap.round);
      expect(props.join, LineJoin.bevel);
      expect(props.miterLimit, 8);
    });

    test('inherits stroke attributes from an ancestor group', () {
      // Figma nests icon paths inside <g>, so inheritance is the common case,
      // not an edge case.
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16"><g stroke="#000" stroke-width="4" '
        'stroke-linecap="square"><path d="M0 0H8"/></g></svg>',
      );

      expect(props, isNotNull);
      expect(props!.width, 4);
      expect(props.cap, LineCap.square);
    });

    test('defaults stroke-width to 1 when only stroke is set', () {
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16"><path d="M0 0H8" stroke="#000"/></svg>',
      );

      expect(props?.width, 1);
    });

    test('tolerates a unit suffix on stroke-width', () {
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16">'
        '<path d="M0 0H8" stroke="#000" stroke-width="2px"/></svg>',
      );

      expect(props?.width, 2);
    });

    test('reports no stroke for an unstroked path', () {
      expect(
        resolveFrom('<svg viewBox="0 0 16 16"><path d="M0 0H8"/></svg>'),
        isNull,
      );
    });

    test('reports no stroke for stroke="none"', () {
      expect(
        resolveFrom(
          '<svg viewBox="0 0 16 16">'
          '<path d="M0 0H8" stroke="none" stroke-width="2"/></svg>',
        ),
        isNull,
      );
    });
  });
}
