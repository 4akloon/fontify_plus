import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/post/post_script_version_20.dart';
import 'package:test/test.dart';

void main() {
  group('PostScriptVersion20.create', () {
    test('indexes the default glyphs before any custom names', () {
      final data = PostScriptVersion20.create(['glyph_one']);

      expect(data.glyphNameIndex, [0, 3, 258]);
    });

    test('numberOfGlyphs is the default count plus the given names', () {
      final data = PostScriptVersion20.create(['a', 'b']);

      expect(data.numberOfGlyphs, 4);
    });

    test('size accounts for the index table and the Pascal-string names', () {
      final data = PostScriptVersion20.create(['ab']);

      // 2 (count) + 3 * 2 (index) + (1 length byte + 2 chars).
      expect(data.size, 2 + 3 * 2 + 3);
    });
  });

  group('PostScriptVersion20 round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final data = PostScriptVersion20.create(['custom_glyph']);
      final bytes = ByteData(data.size);

      data.encodeToBinary(bytes);
      final decoded = PostScriptVersion20.fromByteData(bytes, 0);

      expect(decoded.numberOfGlyphs, data.numberOfGlyphs);
      expect(decoded.glyphNameIndex, data.glyphNameIndex);
      expect(decoded.glyphNames.single.string, 'custom_glyph');
    });

    test('skips standard-name indices when decoding names', () {
      final data = PostScriptVersion20.create(['custom_glyph']);
      final bytes = ByteData(data.size);
      data.encodeToBinary(bytes);

      final decoded = PostScriptVersion20.fromByteData(bytes, 0);

      // Only the one non-standard name should have been read back.
      expect(decoded.glyphNames, hasLength(1));
    });
  });
}
