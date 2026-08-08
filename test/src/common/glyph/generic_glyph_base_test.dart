import 'dart:math';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:fontify_plus/src/otf/table/glyph/header.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple.dart';
import 'package:test/test.dart';

/// A single triangular contour, all on-curve.
SimpleGlyph triangleGlyph() => SimpleGlyph(
  GlyphHeader(1, 0, 0, 10, 10),
  [2],
  [],
  [
    SimpleGlyphFlag.createForPoint(0, 0, true),
    SimpleGlyphFlag.createForPoint(10, 0, true),
    SimpleGlyphFlag.createForPoint(10, 10, true),
  ],
  [const Point(0, 0), const Point(10, 0), const Point(10, 10)],
);

void main() {
  group('GenericGlyph constructors', () {
    test('the default metadata is empty when none is given', () {
      final glyph = GenericGlyph([], const Rectangle(0, 0, 0, 0));

      expect(glyph.metadata.charCode, isNull);
      expect(glyph.metadata.name, isNull);
    });

    test('.empty has no outlines and zero bounds', () {
      final glyph = GenericGlyph.empty();

      expect(glyph.outlines, isEmpty);
      expect(glyph.bounds, const Rectangle(0, 0, 0, 0));
    });
  });

  group('GenericGlyph.fromSimpleTrueTypeGlyph', () {
    test('carries over the point list as one outline', () {
      final glyph = GenericGlyph.fromSimpleTrueTypeGlyph(triangleGlyph());

      expect(glyph.outlines, hasLength(1));
      expect(glyph.outlines.single.pointList, hasLength(3));
      expect(glyph.outlines.single.isOnCurveList, everyElement(isTrue));
    });

    test('takes its bounds from the glyph header', () {
      final glyph = GenericGlyph.fromSimpleTrueTypeGlyph(triangleGlyph());

      expect(glyph.bounds.width, 10);
      expect(glyph.bounds.height, 10);
    });

    test('splits multiple contours at their end points', () {
      final glyph = SimpleGlyph(
        GlyphHeader(2, 0, 0, 10, 10),
        [1, 3],
        [],
        List.filled(4, SimpleGlyphFlag.createForPoint(0, 0, true)),
        [
          const Point(0, 0),
          const Point(1, 0),
          const Point(5, 5),
          const Point(6, 5),
        ],
      );

      final result = GenericGlyph.fromSimpleTrueTypeGlyph(glyph);

      expect(result.outlines, hasLength(2));
      expect(result.outlines[0].pointList, hasLength(2));
      expect(result.outlines[1].pointList, hasLength(2));
    });
  });

  group('GenericGlyph.fromSvg', () {
    // The exact shape Figma exports for outline-style icon sets, and the
    // reason such icons used to come out blank.
    const strokedPlus =
        '<svg viewBox="0 0 16 16" fill="none">'
        '<path d="M8 2.66667V13.3333M13.3333 8H2.66666" stroke="#000" '
        'stroke-width="1.33" stroke-linecap="round"/></svg>';

    double areaOf(GenericGlyph glyph) {
      var total = 0.0;

      for (final outline in glyph.outlines) {
        final points = outline.pointList;
        var acc = 0.0;

        for (var i = 0; i < points.length; i++) {
          final a = points[i];
          final b = points[(i + 1) % points.length];
          acc += a.x * b.y - b.x * a.y;
        }

        total += (acc / 2).abs();
      }

      return total;
    }

    test('turns a stroked icon into fillable outlines', () {
      final glyph = GenericGlyph.fromSvg('plus', strokedPlus);

      expect(glyph.outlines, isNotEmpty);
      expect(
        areaOf(glyph),
        greaterThan(1),
        reason: 'a stroked icon must enclose area',
      );
    });

    test('leaves a zero-area centreline when outlineStrokes is false', () {
      final glyph = GenericGlyph.fromSvg(
        'plus',
        strokedPlus,
        outlineStrokes: false,
      );

      expect(
        areaOf(glyph),
        closeTo(0, 0.001),
        reason: 'the unconverted centreline is what made icons render blank',
      );
    });

    test('keeps the fill of a path that is both filled and stroked', () {
      final glyph = GenericGlyph.fromSvg(
        'both',
        '<svg viewBox="0 0 16 16">'
            '<path d="M2 2H10V10H2Z" fill="#000" stroke="#000" '
            'stroke-width="2"/></svg>',
      );

      // The original filled contour plus the two walls of the stroked ring.
      expect(glyph.outlines.length, greaterThanOrEqualTo(3));
    });

    test('takes its bounds from the viewport', () {
      final glyph = GenericGlyph.fromSvg(
        'box',
        '<svg viewBox="0 0 16 32"><path d="M0 0H16V32H0Z" fill="#000"/></svg>',
      );

      expect(glyph.bounds.left, 0);
      expect(glyph.bounds.top, 0);
      expect(glyph.bounds.width, 16);
      expect(glyph.bounds.height, 32);
    });

    test('records the name in its metadata', () {
      final glyph = GenericGlyph.fromSvg(
        'arrow_up',
        '<svg viewBox="0 0 16 16"><path d="M0 0H16V16H0Z"/></svg>',
      );

      expect(glyph.metadata.name, 'arrow_up');
    });
  });

  group('GenericGlyph point accessors', () {
    test('pointList flattens every outline in order', () {
      final glyph = GenericGlyph.fromSimpleTrueTypeGlyph(triangleGlyph());

      expect(glyph.pointList, [
        const Point(0, 0),
        const Point(10, 0),
        const Point(10, 10),
      ]);
    });

    test('isOnCurveList is aligned with pointList', () {
      final glyph = GenericGlyph.fromSimpleTrueTypeGlyph(triangleGlyph());

      expect(glyph.isOnCurveList, hasLength(glyph.pointList.length));
    });

    test('endPoints marks the last index of each contour', () {
      final glyph = SimpleGlyph(
        GlyphHeader(2, 0, 0, 10, 10),
        [1, 3],
        [],
        List.filled(4, SimpleGlyphFlag.createForPoint(0, 0, true)),
        [
          const Point(0, 0),
          const Point(1, 0),
          const Point(5, 5),
          const Point(6, 5),
        ],
      );

      final result = GenericGlyph.fromSimpleTrueTypeGlyph(glyph);

      expect(result.endPoints, [1, 3]);
    });
  });

  group('GenericGlyph.metrics', () {
    test('is the empty box for a glyph with no points', () {
      expect(GenericGlyph.empty().metrics.width, 0);
    });

    test('is the bounding box of the ink, not the artboard', () {
      // A small triangle in a much larger nominal bounds rectangle: metrics
      // reports the ink's own extent, independent of [bounds].
      final glyph = GenericGlyph(
        [
          Outline(
            [const Point(2, 2), const Point(4, 2), const Point(4, 4)],
            [true, true, true],
            false,
            false,
            FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 100, 100),
      );

      final metrics = glyph.metrics;

      expect(metrics.xMin, 2);
      expect(metrics.xMax, 4);
      expect(metrics.yMin, 2);
      expect(metrics.yMax, 4);
    });
  });

  group('GenericGlyph.copy', () {
    test('produces independent outlines', () {
      final original = GenericGlyph.fromSimpleTrueTypeGlyph(triangleGlyph());
      final copy = original.copy();

      copy.outlines.single.pointList[0] = const Point(99, 99);

      expect(original.outlines.single.pointList[0], const Point(0, 0));
    });

    test('produces an independent metadata object', () {
      final original = GenericGlyph(
        [],
        const Rectangle(0, 0, 0, 0),
        GenericGlyphMetadata(name: 'a'),
      );
      final copy = original.copy();

      copy.metadata.name = 'b';

      expect(original.metadata.name, 'a');
    });
  });
}
