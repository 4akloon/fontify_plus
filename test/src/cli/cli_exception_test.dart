import 'package:fontify_plus/src/cli/cli_exception.dart';
import 'package:test/test.dart';

void main() {
  group('CliArgumentException', () {
    test('toString returns the given message verbatim', () {
      const exception = CliArgumentException('something went wrong');

      expect(exception.toString(), 'something went wrong');
    });

    test('is an Exception', () {
      expect(const CliArgumentException('x'), isA<Exception>());
    });
  });

  group('CliHelpException', () {
    test('is an Exception', () {
      expect(CliHelpException(), isA<Exception>());
    });
  });
}
