import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/reader.dart';
import 'package:fontify_plus/src/otf/writer.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';

OpenTypeFont _buildFont() {
  final glyph = GenericGlyph.fromSvg(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return OpenTypeFont.createFromGlyphs(
    glyphList: [glyph],
    fontName: 'Test',
  );
}

/// Encodes [font] and returns a mutable copy of the bytes, with every
/// table's entry (offset/length) filled in as a side effect of encoding.
Uint8List _encode(OpenTypeFont font) {
  final bytes = OTFWriter().write(font);
  return Uint8List.fromList(bytes.buffer.asUint8List());
}

void main() {
  group('OTFReader.read', () {
    test('parses a font this package just wrote', () {
      final font = _buildFont();
      final bytes = _encode(font);

      final decoded = OTFReader.fromByteData(
        ByteData.sublistView(bytes),
      ).read();

      expect(decoded.familyName, 'Test');
      expect(decoded.maxp.numGlyphs, font.maxp.numGlyphs);
    });

    test('throws ChecksumException for a corrupted non-head table', () {
      final font = _buildFont();
      final bytes = _encode(font);

      final nameEntry = font.tableMap['name']!.entry!;
      // The last byte, safely inside the string storage area rather than the
      // 2-byte format discriminator at the very start — corrupting that
      // would make the table fail to parse instead of fail its checksum.
      bytes[nameEntry.offset + nameEntry.length - 1] ^= 0xFF;

      expect(
        () => OTFReader.fromByteData(ByteData.sublistView(bytes)).read(),
        throwsA(
          isA<ChecksumException>().having(
            (e) => e.toString(),
            'message',
            contains('name table'),
          ),
        ),
      );
    });

    test('throws ChecksumException for a corrupted font-level checksum', () {
      final font = _buildFont();
      final bytes = _encode(font);

      final headEntry = font.tableMap['head']!.entry!;
      // The checkSumAdjustment field itself, which the reader zeroes out
      // before recomputing per-table checksums — so only the font-level
      // check can catch this corruption.
      bytes[headEntry.offset + 8] ^= 0xFF;

      expect(
        () => OTFReader.fromByteData(ByteData.sublistView(bytes)).read(),
        throwsA(
          isA<ChecksumException>().having(
            (e) => e.toString(),
            'message',
            contains('font'),
          ),
        ),
      );
    });
  });
}
