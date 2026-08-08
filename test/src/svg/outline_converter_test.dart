import 'dart:math';

import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/svg/outline_converter.dart';
import 'package:fontify_plus/src/svg/path.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:test/test.dart';

/// A 10x10 viewBox, so the y-flip below is easy to check by hand.
Svg svgWith(String pathData, {String? fillRule, String? transform}) {
  final attrs = [
    if (fillRule != null) 'fill-rule="$fillRule"',
    if (transform != null) 'transform="$transform"',
  ].join(' ');

  return Svg.parse(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="$pathData" $attrs/></svg>',
    outlineStrokes: false,
  );
}

List<Outline> convert(Svg svg) => PathToOutlineConverter(
      svg,
      svg.elementList.whereType<PathElement>().single,
    ).convert();

void main() {
  group('PathToOutlineConverter', () {
    test('flips y against the viewBox height', () {
      final outlines = convert(svgWith('M0 0 L1 0 L1 1 L0 1 Z'));

      // (0,0) sits at the top-left in SVG space, which is the bottom-left of
      // a 10-tall viewBox once flipped.
      expect(outlines.single.pointList.first, const Point<num>(0, 10));
    });

    test('marks every point as on-curve for straight segments', () {
      final outline = convert(svgWith('M0 0 L1 0 L1 1 L0 1 Z')).single;

      expect(outline.isOnCurveList, everyElement(isTrue));
    });

    test('marks a cubic\'s two control points as off-curve', () {
      final outline = convert(svgWith('M0 0 C1 1 2 2 3 0')).single;

      expect(outline.isOnCurveList, [true, false, false, true]);
    });

    test('defaults to the nonzero fill rule', () {
      final outline = convert(svgWith('M0 0 L1 0 L1 1 Z')).single;

      expect(outline.fillRule, FillRule.nonzero);
    });

    test('reads an explicit evenodd fill rule', () {
      final outline =
          convert(svgWith('M0 0 L1 0 L1 1 Z', fillRule: 'evenodd')).single;

      expect(outline.fillRule, FillRule.evenodd);
    });

    test('applies the path\'s transform after the y-flip', () {
      final outlines = convert(
        svgWith('M0 0 L1 0 L1 1 L0 1 Z', transform: 'translate(5, 0)'),
      );

      expect(outlines.single.pointList.first, const Point<num>(5, 10));
    });

    test('starts a fresh contour at every moveTo', () {
      // Two separate open strokes, no Z between them.
      final outlines = convert(svgWith('M0 0 L1 0 M5 5 L6 5'));

      expect(outlines, hasLength(2));
    });

    test('flushes the last contour even with no trailing Z', () {
      final outlines = convert(svgWith('M0 0 L1 0 L1 1'));

      expect(outlines, hasLength(1));
      expect(outlines.single.pointList, hasLength(3));
    });

    test('returns nothing for empty path data', () {
      expect(convert(svgWith('')), isEmpty);
    });

    test('produces neither compact nor already-quadratic outlines', () {
      // outlineStrokes:false paths reach the converter with their raw cubic
      // control points, not the implicit-midpoint form quadratics use.
      final outline = convert(svgWith('M0 0 C1 1 2 2 3 0')).single;

      expect(outline.hasCompactCurves, isFalse);
      expect(outline.hasQuadCurves, isFalse);
    });
  });
}
