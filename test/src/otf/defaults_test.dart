import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:test/test.dart';

void main() {
  group('generateDefaultGlyphList', () {
    test('returns exactly the .notdef and space glyphs, in that order', () {
      final glyphs = generateDefaultGlyphList(1000);

      expect(glyphs, hasLength(2));
    });

    test(
      '.notdef has no char code, but two outlines (an outer and inner box)',
      () {
        final glyphs = generateDefaultGlyphList(1000);

        expect(glyphs[0].metadata.charCode, isNull);
        expect(glyphs[0].outlines, hasLength(2));
      },
    );

    test('.notdef spans from x=0 to the ascender height', () {
      final glyphs = generateDefaultGlyphList(1000);

      expect(glyphs[0].bounds.left, 0);
      expect(glyphs[0].bounds.height, 1000);
    });

    test('space has the Unicode space char code and no outlines', () {
      final glyphs = generateDefaultGlyphList(1000);

      expect(glyphs[1].metadata.charCode, 0x20);
      expect(glyphs[1].outlines, isEmpty);
    });
  });

  group('kDefaultGlyphIndex', () {
    test('reserves index 0 for .notdef and 3 for space', () {
      expect(kDefaultGlyphIndex, [0, 3]);
    });
  });
}
