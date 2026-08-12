import 'package:fontify_plus/src/otf/otf.dart' show OpenTypeFont;
import 'package:fontify_plus/src/otf/stub.dart';
import 'package:test/test.dart';

void main() {
  group('readFromFile / writeToFile (web stub)', () {
    test('readFromFile throws UnsupportedError', () {
      expect(() => readFromFile('anything.otf'), throwsUnsupportedError);
    });

    test('tryReadHeadTimestamps throws UnsupportedError', () {
      expect(
        () => tryReadHeadTimestamps('anything.otf'),
        throwsUnsupportedError,
      );
    });

    test('writeToFile throws UnsupportedError', () {
      expect(
        () => writeToFile(
          'anything.otf',
          OpenTypeFont.createFromGlyphs(glyphList: []),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
