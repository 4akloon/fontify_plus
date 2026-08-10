import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:fontify_plus/src/otf/otf_builder.dart';
import 'package:fontify_plus/src/otf/table/glyf.dart';
import 'package:fontify_plus/src/otf/table/hmtx.dart';
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

/// Drawn away from its artboard's left edge, so its ink's xMin is nonzero
/// once [ArtboardFitting] maps the artboard straight onto the em square
/// without centring — unlike [_triangleGlyph], whose ink touches every edge.
GenericGlyph _offCenterSquareGlyph() {
  return GenericGlyph.fromSvg(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
        '<path d="M6 6 H10 V10 H6 Z"/></svg>',
  );
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

    for (final normalize in [true, false]) {
      test(
        'normalize: $normalize keeps hmtx.lsb equal to glyf.xMin for every glyph',
        () {
          // TrueType requires hmtx.lsb == glyf.xMin: a rasterizer derives a
          // glyph's horizontal origin (phantom point pp1) from lsb, and a
          // mismatch with the outline's own xMin shifts the glyph sideways.
          final font = OpenTypeFontBuilder(
            glyphList: [_offCenterSquareGlyph()],
            useOpenType: false,
            normalize: normalize,
          ).build();

          final glyf = (font.tableMap[kGlyfTag]! as GlyphDataTable).glyphList;
          final hmtx =
              (font.tableMap[kHmtxTag]! as HorizontalMetricsTable).hMetrics;

          expect(hmtx, hasLength(glyf.length));

          for (var i = 0; i < glyf.length; i++) {
            // A glyph with no contours (e.g. the default "space" glyph) has
            // no glyf entry to read an xMin from, so the invariant doesn't
            // apply to it.
            if (glyf[i].isEmpty) {
              continue;
            }

            expect(
              hmtx[i].lsb,
              glyf[i].header.xMin,
              reason: 'glyph $i',
            );
          }
        },
      );
    }
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
