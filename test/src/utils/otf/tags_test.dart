import 'dart:typed_data';

import 'package:fontify_plus/src/utils/otf/tags.dart';
import 'package:test/test.dart';

void main() {
  group('convertTagToString / convertStringToTag', () {
    test('round-trips a four-character tag', () {
      expect(convertTagToString(convertStringToTag('glyf')), 'glyf');
    });

    test('preserves a trailing space, as CFF\'s tag needs', () {
      expect(convertTagToString(convertStringToTag('CFF ')), 'CFF ');
    });

    test('produces exactly four bytes', () {
      expect(convertStringToTag('name'), hasLength(4));
    });

    test('asserts on a tag that is not four characters', () {
      expect(() => convertStringToTag('abc'), throwsA(isA<AssertionError>()));
    });

    test('convertTagToString reads exactly the bytes given', () {
      expect(
        convertTagToString(Uint8List.fromList('post'.codeUnits)),
        'post',
      );
    });
  });

  group('platform constants', () {
    test('are distinct', () {
      expect({
        kPlatformUnicode,
        kPlatformMacintosh,
        kPlatformWindows,
      }, hasLength(3));
    });
  });

  group('table tag constants', () {
    test('are all exactly four characters', () {
      for (final tag in [
        kHeadTag,
        kGSUBTag,
        kOS2Tag,
        kCmapTag,
        kGlyfTag,
        kHheaTag,
        kHmtxTag,
        kLocaTag,
        kMaxpTag,
        kNameTag,
        kPostTag,
        kCFFTag,
        kCFF2Tag,
      ]) {
        expect(tag, hasLength(4));
      }
    });

    test('are pairwise distinct', () {
      final tags = {
        kHeadTag,
        kGSUBTag,
        kOS2Tag,
        kCmapTag,
        kGlyfTag,
        kHheaTag,
        kHmtxTag,
        kLocaTag,
        kMaxpTag,
        kNameTag,
        kPostTag,
        kCFFTag,
        kCFF2Tag,
      };

      expect(tags, hasLength(13));
    });
  });
}
