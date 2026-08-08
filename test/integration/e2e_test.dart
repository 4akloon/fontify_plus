import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/reader.dart';
import 'package:fontify_plus/src/otf/table/cmap.dart';
import 'package:fontify_plus/src/otf/writer.dart';
import 'package:test/test.dart';

/// A stroked icon: two crossing open subpaths, `fill="none"`.
/// Mirrors how Figma exports outline-style icon sets.
const _strokedPlus = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">
<path d="M8 2.66667V13.3333M13.3333 8H2.66666" stroke="#000" stroke-width="1.33"
      stroke-linecap="round" stroke-linejoin="round" />
</svg>
''';

/// A filled icon: a closed, non-zero-area contour.
const _filledSquare = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
<path d="M3 3 H13 V13 H3 Z" fill="#000" />
</svg>
''';

OpenTypeFont _buildFont(Map<String, String> svgMap) {
  final glyphList = [
    for (final e in svgMap.entries) GenericGlyph.fromSvg(e.key, e.value),
  ];

  return OpenTypeFont.createFromGlyphs(
    glyphList: glyphList,
    fontName: 'E2ETest',
    normalize: true,
    useOpenType: true,
    usePostV2: false,
  );
}

/// Writes the font and parses the bytes back with the package's own reader.
OpenTypeFont _roundTrip(OpenTypeFont font) {
  final bytes = OTFWriter().write(font);
  return OTFReader.fromByteData(
    ByteData.sublistView(bytes.buffer.asUint8List()),
  ).read();
}

void main() {
  // Regression guard for the bug that made every 0.4.x release unusable:
  // CFFIndexWithData memoized its INDEX while the Top DICT still held 1-byte
  // placeholder offset operands, then encodeToBinary sized its sub-view from
  // that stale index while writing the grown DICT. Nothing in the suite wrote a
  // font end to end, so a total failure shipped with a green build.
  //
  // These tests must exercise the full write path — building an OpenTypeFont in
  // memory is not enough to reproduce it.
  group('SVG to OTF', () {
    test('writes a font whose bytes parse back', () {
      final font = _buildFont({
        'filled_square': _filledSquare,
        'stroked_plus': _strokedPlus,
      });

      final bytes = OTFWriter().write(font);
      expect(bytes.lengthInBytes, greaterThan(0));

      final reread = _roundTrip(font);

      // .notdef + space + the two glyphs above.
      expect(reread.maxp.numGlyphs, font.maxp.numGlyphs);
      expect(reread.maxp.numGlyphs, greaterThanOrEqualTo(3));
      expect(reread.isOpenType, isTrue);
      expect(reread.cff, isNotNull);
    });

    test('encodes every glyph into the character map', () {
      final names = ['filled_square', 'stroked_plus', 'another_square'];
      final font = _buildFont({
        names[0]: _filledSquare,
        names[1]: _strokedPlus,
        names[2]: _filledSquare,
      });

      final reread = _roundTrip(font);

      final segmentTables = reread.cmap.data
          .whereType<CmapSegmentMappingToDeltaValuesTable>();
      expect(segmentTables, isNotEmpty, reason: 'expected a format 4 subtable');

      // Every mapped character code across the format 4 segments.
      final charCodes = <int>{};
      for (final table in segmentTables) {
        for (var i = 0; i < table.startCode.length; i++) {
          for (var c = table.startCode[i]; c <= table.endCode[i]; c++) {
            charCodes.add(c);
          }
        }
      }

      // Each glyph gets its own code point, plus the 0xFFFF terminator segment.
      expect(charCodes.length, greaterThan(names.length));
    });

    test('is stable when written twice', () {
      // The stale-index bug survived repeated recalculateOffsets() calls, so a
      // second write is a direct probe for cached layout state.
      final font = _buildFont({'filled_square': _filledSquare});

      final first = OTFWriter().write(font);
      final second = OTFWriter().write(font);

      expect(
        second.buffer.asUint8List(),
        orderedEquals(first.buffer.asUint8List()),
        reason: 'Writing the same font twice must be deterministic',
      );
    });

    test('handles a glyph count that widens INDEX offsets', () {
      // Enough glyphs to push INDEX offsets past one byte, exercising the
      // offSize negotiation that the stale cache used to freeze.
      final svgMap = {
        for (var i = 0; i < 40; i++) 'glyph_$i': _filledSquare,
      };

      final font = _buildFont(svgMap);
      final reread = _roundTrip(font);

      expect(reread.maxp.numGlyphs, font.maxp.numGlyphs);
      expect(reread.maxp.numGlyphs, greaterThanOrEqualTo(40));
    });

    test('writes a round-capped stroked icon through the CFF path', () {
      // Round caps and joins close a contour with a curve, so its end point
      // cannot be left implicit. Getting that wrong made the default
      // useOpenType path throw RangeError while every other test stayed green,
      // because no fixture in the suite was stroked.
      final font = _buildFont({'round_plus': _strokedPlus});

      final reread = _roundTrip(font);

      expect(reread.isOpenType, isTrue);
      expect(reread.cff, isNotNull);
      expect(reread.maxp.numGlyphs, font.maxp.numGlyphs);
    });
  });
}
