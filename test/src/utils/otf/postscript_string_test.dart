import 'package:fontify_plus/src/utils/otf/postscript_string.dart';
import 'package:test/test.dart';

void main() {
  group('getAsciiPrintable', () {
    test('leaves plain ASCII letters and digits untouched', () {
      expect('Icons123'.getAsciiPrintable(), 'Icons123');
    });

    test('strips non-ASCII characters', () {
      expect('Ícons'.getAsciiPrintable(), 'cons');
    });

    test('strips characters PostScript names may not contain', () {
      expect('a(b)c[d]e{f}g<h>i/j%k'.getAsciiPrintable(), 'abcdefghijk');
    });

    test('keeps ASCII punctuation not on the exclusion list', () {
      expect('a-b_c.d'.getAsciiPrintable(), 'a-b_c.d');
    });
  });

  group('getPostScriptString', () {
    test('drops the space character on top of getAsciiPrintable\'s rules', () {
      expect('My Icons'.getPostScriptString(), 'MyIcons');
    });

    test('drops control characters', () {
      expect('My\nIcons'.getPostScriptString(), 'MyIcons');
    });

    test('is idempotent', () {
      const name = 'MyIcons123';

      expect(name.getPostScriptString().getPostScriptString(), name);
    });
  });
}
