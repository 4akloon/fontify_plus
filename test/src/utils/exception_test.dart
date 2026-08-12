import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';

void main() {
  group('TableDataFormatException', () {
    test('implements Exception and reports its message', () {
      const exception = TableDataFormatException('bad offset');

      expect(exception, isA<Exception>());
      expect(exception.toString(), contains('bad offset'));
    });
  });

  group('ChecksumException', () {
    test('.font names the whole font', () {
      expect(const ChecksumException.font().toString(), contains('font'));
    });

    test('.table names the specific table', () {
      expect(const ChecksumException.table('CFF ').toString(), contains('CFF'));
    });
  });

  group('SvgParserException', () {
    test('reports the message it was given', () {
      expect(
        const SvgParserException('missing viewBox').toString(),
        contains('missing viewBox'),
      );
    });

    test('is constructible with no message', () {
      expect(() => const SvgParserException(), returnsNormally);
    });
  });
}
