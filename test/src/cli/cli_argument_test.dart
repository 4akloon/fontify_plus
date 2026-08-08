import 'package:fontify_plus/src/cli/cli_argument.dart';
import 'package:test/test.dart';

void main() {
  group('kArgAllowedTypes', () {
    test('declares an entry for every CliArgument', () {
      expect(kArgAllowedTypes.keys.toSet(), CliArgument.values.toSet());
    });
  });

  group('kOptionNames', () {
    test('every option name is a CLI-style kebab-case flag', () {
      for (final name in kOptionNames.map.values) {
        expect(name, matches(RegExp(r'^[a-z][a-z-]*$')));
      }
    });

    test('svgDir and fontFile are positional, so they have no option name', () {
      expect(kOptionNames.map.containsKey(CliArgument.svgDir), isFalse);
      expect(kOptionNames.map.containsKey(CliArgument.fontFile), isFalse);
    });
  });

  group('kConfigKeys', () {
    test('every config key is snake_case', () {
      for (final key in kConfigKeys.map.values) {
        expect(key, matches(RegExp(r'^[a-z][a-z_]*$')));
      }
    });

    test('help and configFile are CLI-only, so they have no config key', () {
      expect(kConfigKeys.map.containsKey(CliArgument.help), isFalse);
      expect(kConfigKeys.map.containsKey(CliArgument.configFile), isFalse);
    });
  });

  group('argumentNames', () {
    test('resolves every argument to either its config key or option name', () {
      for (final arg in CliArgument.values) {
        expect(argumentNames[arg], isNotNull, reason: '$arg');
      }
    });
  });
}
