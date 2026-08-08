import 'package:fontify_plus/src/utils/ucs2.dart';
import 'package:test/test.dart';

void main() {
  group('toUCS2byteList', () {
    test('splits each code unit into two big-endian bytes', () {
      expect(toUCS2byteList('A'), [0x00, 0x41]);
    });

    test('handles multiple characters in order', () {
      expect(toUCS2byteList('AB'), [0x00, 0x41, 0x00, 0x42]);
    });

    test('handles a code point above the Latin range', () {
      // U+00E9 (é)
      expect(toUCS2byteList('é'), [0x00, 0xE9]);
    });

    test('returns nothing for an empty string', () {
      expect(toUCS2byteList(''), isEmpty);
    });
  });

  group('fromUCS2byteList', () {
    test('is the inverse of toUCS2byteList', () {
      const text = 'Hello';

      expect(fromUCS2byteList(toUCS2byteList(text)), text);
    });

    test('combines big-endian byte pairs into code units', () {
      expect(fromUCS2byteList([0x00, 0x41]), 'A');
    });

    test('returns an empty string for an empty list', () {
      expect(fromUCS2byteList([]), '');
    });
  });
}
