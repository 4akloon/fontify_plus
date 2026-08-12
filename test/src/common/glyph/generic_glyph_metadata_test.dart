import 'package:fontify_plus/src/common/glyph/generic_glyph_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('GenericGlyphMetadata', () {
    test('defaults charCode and name to null', () {
      final metadata = GenericGlyphMetadata();

      expect(metadata.charCode, isNull);
      expect(metadata.name, isNull);
      expect(metadata.preview, isNull);
    });

    test('keeps the values it was constructed with', () {
      final metadata = GenericGlyphMetadata(charCode: 0x41, name: 'A');

      expect(metadata.charCode, 0x41);
      expect(metadata.name, 'A');
    });

    test('copy produces an independent instance with the same values', () {
      final metadata = GenericGlyphMetadata(
        charCode: 1,
        name: 'a',
        preview: 'cHJldmlldw==',
      );
      final copy = metadata.copy();

      copy.charCode = 2;
      copy.name = 'b';
      copy.preview = 'b3RoZXI=';

      expect(metadata.charCode, 1);
      expect(metadata.name, 'a');
      expect(metadata.preview, 'cHJldmlldw==');
      expect(copy.charCode, 2);
      expect(copy.name, 'b');
      expect(copy.preview, 'b3RoZXI=');
    });
  });
}
