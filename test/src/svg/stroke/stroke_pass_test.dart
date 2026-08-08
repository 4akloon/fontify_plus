import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:test/test.dart';

import 'contour_reader.dart';

void main() {
  group('Svg.parse with outlineStrokes', () {
    // The end-to-end guard: this is the exact shape Figma exports for
    // outline-style icon sets, and the reason such icons used to come out blank.
    const strokedPlus = '<svg viewBox="0 0 16 16" fill="none">'
        '<path d="M8 2.66667V13.3333M13.3333 8H2.66666" stroke="#000" '
        'stroke-width="1.33" stroke-linecap="round"/></svg>';

    test('turns a stroked icon into fillable outlines', () {
      final glyph = GenericGlyph.fromSvg(
        Svg.parse('plus', strokedPlus, outlineStrokes: true),
      );

      expect(glyph.outlines, isNotEmpty);

      final area = glyph.outlines.fold<double>(
        0,
        (sum, o) =>
            sum +
            signedArea([
              for (final p in o.pointList) [p.x.toDouble(), p.y.toDouble()],
            ]).abs(),
      );

      expect(area, greaterThan(1), reason: 'a stroked icon must enclose area');
    });

    test('leaves a zero-area centreline when disabled', () {
      final glyph = GenericGlyph.fromSvg(
        Svg.parse('plus', strokedPlus, outlineStrokes: false),
      );

      final area = glyph.outlines.fold<double>(
        0,
        (sum, o) =>
            sum +
            signedArea([
              for (final p in o.pointList) [p.x.toDouble(), p.y.toDouble()],
            ]).abs(),
      );

      expect(
        area,
        closeTo(0, 0.001),
        reason: 'the unconverted centreline is what made icons render blank',
      );
    });

    test('keeps the fill of a path that is both filled and stroked', () {
      final glyph = GenericGlyph.fromSvg(
        Svg.parse(
          'both',
          '<svg viewBox="0 0 16 16">'
              '<path d="M2 2H10V10H2Z" fill="#000" stroke="#000" '
              'stroke-width="2"/></svg>',
          outlineStrokes: true,
        ),
      );

      // The original filled contour plus the two walls of the stroked ring.
      expect(glyph.outlines.length, greaterThanOrEqualTo(3));
    });
  });
}
