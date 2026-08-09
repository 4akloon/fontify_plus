import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:fontify_plus/src/otf/otf_builder.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_data.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_version_20.dart';
import 'package:fontify_plus/src/utils/misc.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

GenericGlyph _triangleGlyph() {
  final glyph = GenericGlyph.fromSvg(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return glyph;
}

void main() {
  group('OpenTypeFontBuilder defaults', () {
    test('fontName falls back to kDefaultFontFamily when omitted', () {
      final font = OpenTypeFontBuilder(glyphList: [_triangleGlyph()]).build();

      expect(font.familyName, kDefaultFontFamily);
    });

    test('fontName falls back to kDefaultFontFamily when given empty', () {
      final font = OpenTypeFontBuilder(
        glyphList: [_triangleGlyph()],
        fontName: '',
      ).build();

      expect(font.familyName, kDefaultFontFamily);
    });

    test('a given fontName is used as-is', () {
      final font = OpenTypeFontBuilder(
        glyphList: [_triangleGlyph()],
        fontName: 'My Icons',
      ).build();

      expect(font.familyName, 'My Icons');
    });
  });

  group('OpenTypeFontBuilder outline format', () {
    test('useOpenType defaults to true, producing CFF and no glyf/loca', () {
      final font = OpenTypeFontBuilder(glyphList: [_triangleGlyph()]).build();

      expect(font.tableMap.containsKey(kCFFTag), isTrue);
      expect(font.tableMap.containsKey(kGlyfTag), isFalse);
      expect(font.head.unitsPerEm, kDefaultOpenTypeUnitsPerEm);
    });

    test('useOpenType: false produces glyf/loca and no CFF', () {
      final font = OpenTypeFontBuilder(
        glyphList: [_triangleGlyph()],
        useOpenType: false,
      ).build();

      expect(font.tableMap.containsKey(kGlyfTag), isTrue);
      expect(font.tableMap.containsKey(kLocaTag), isTrue);
      expect(font.tableMap.containsKey(kCFFTag), isFalse);
      expect(font.head.unitsPerEm, kDefaultTrueTypeUnitsPerEm);
    });
  });

  group('OpenTypeFontBuilder char code generation', () {
    test('assigns each input glyph a private-use-area char code in order', () {
      final glyphList = [_triangleGlyph(), _triangleGlyph()];

      OpenTypeFontBuilder(glyphList: glyphList).build();

      expect(glyphList[0].metadata.charCode, kUnicodePrivateUseAreaStart);
      expect(glyphList[1].metadata.charCode, kUnicodePrivateUseAreaStart + 1);
    });
  });

  group('OpenTypeFontBuilder normalize', () {
    test(
      'normalize: false sizes every custom glyph as a unitsPerEm square',
      () {
        final font = OpenTypeFontBuilder(
          glyphList: [_triangleGlyph()],
          normalize: false,
        ).build();

        // Index 0/1 are the default .notdef/space glyphs; index 2 is the icon.
        expect(font.hmtx.hMetrics[2].advanceWidth, kDefaultOpenTypeUnitsPerEm);
      },
    );

    test(
      'normalize: true (default) fits the ascender/descender band inside the baseline extension',
      () {
        final font = OpenTypeFontBuilder(glyphList: [_triangleGlyph()]).build();

        expect(
          font.hhea.ascender,
          kDefaultOpenTypeUnitsPerEm - kDefaultBaselineExtension,
        );
        expect(font.hhea.descender, -kDefaultBaselineExtension);
      },
    );

    test(
      'normalize: false uses the full unitsPerEm as the ascender, zero descender',
      () {
        final font = OpenTypeFontBuilder(
          glyphList: [_triangleGlyph()],
          normalize: false,
        ).build();

        expect(font.hhea.ascender, kDefaultOpenTypeUnitsPerEm);
        expect(font.hhea.descender, 0);
      },
    );
  });

  group('OpenTypeFontBuilder post table version', () {
    test('usePostV2: false (default) omits glyph names', () {
      final font = OpenTypeFontBuilder(glyphList: [_triangleGlyph()]).build();

      expect(font.post.data, isA<PostScriptVersion30>());
    });

    test('usePostV2: true includes glyph names', () {
      final font = OpenTypeFontBuilder(
        glyphList: [_triangleGlyph()],
        usePostV2: true,
      ).build();

      expect(font.post.data, isA<PostScriptVersion20>());
    });
  });
}
