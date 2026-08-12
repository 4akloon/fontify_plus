import 'package:args/args.dart';
import 'package:fontify_plus/src/cli/options.dart';
import 'package:fontify_plus/src/job/job_field.dart';
import 'package:test/test.dart';

void main() {
  group('defineOptions', () {
    test('registers expected options', () {
      final argParser = ArgParser(allowTrailingOptions: true);
      defineOptions(argParser);

      expect(
        argParser.options,
        contains(kJobCliOptions[JobField.outputClassFile]),
      );
      expect(argParser.options, contains('font'));
      expect(argParser.options, contains('config-file'));
      expect(argParser.options, contains(kCliWatchOption));
    });
  });
}
