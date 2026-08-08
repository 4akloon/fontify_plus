import 'package:fontify_plus/src/otf/table/post/mac_standard_glyph_names.dart';
import 'package:test/test.dart';

void main() {
  group('kMacStandardGlyphNames', () {
    test('has exactly 258 entries', () {
      expect(kMacStandardGlyphNames, hasLength(258));
    });

    test('starts with .notdef', () {
      expect(kMacStandardGlyphNames.first, '.notdef');
    });
  });

  group('isGlyphNameStandard', () {
    test('is true for an index within the standard list', () {
      expect(isGlyphNameStandard(0), isTrue);
      expect(isGlyphNameStandard(kMacStandardGlyphNames.length - 1), isTrue);
    });

    test('is false for an index past the standard list', () {
      expect(isGlyphNameStandard(kMacStandardGlyphNames.length), isFalse);
    });
  });
}
