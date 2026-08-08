import 'package:args/args.dart';
import 'package:fontify_plus/src/cli/cli_argument.dart';
import 'package:fontify_plus/src/cli/options.dart';
import 'package:test/test.dart';

void main() {
  group('defineOptions', () {
    test('defines every non-positional CliArgument as an option', () {
      final argParser = ArgParser();
      defineOptions(argParser);

      for (final entry in kOptionNames.map.entries) {
        expect(
          argParser.options.containsKey(entry.value),
          isTrue,
          reason: entry.value,
        );
      }
    });

    test('outline-strokes and opentype default to true', () {
      final argParser = ArgParser();
      defineOptions(argParser);

      final results = argParser.parse([]);

      expect(results['outline-strokes'], isTrue);
      expect(results['opentype'], isTrue);
    });

    test('normalize and ignore-shapes default to false', () {
      final argParser = ArgParser();
      defineOptions(argParser);

      final results = argParser.parse([]);

      expect(results['normalize'], isFalse);
      expect(results['ignore-shapes'], isFalse);
    });

    test('indent defaults to "2"', () {
      final argParser = ArgParser();
      defineOptions(argParser);

      final results = argParser.parse([]);

      expect(results['indent'], '2');
    });

    test('recursive, verbose, and help are not negatable', () {
      final argParser = ArgParser();
      defineOptions(argParser);

      expect(
        () => argParser.parse(['--no-recursive']),
        throwsFormatException,
      );
    });
  });
}
