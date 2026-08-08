import 'dart:async';

import 'package:fontify_plus/src/cli/cli_argument.dart';
import 'package:fontify_plus/src/cli/config_parser.dart';
import 'package:test/test.dart';

/// Runs [body] with `print` captured instead of written to stdout.
List<String> capturePrints(void Function() body) {
  final lines = <String>[];

  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );

  return lines;
}

void main() {
  group('parseConfig', () {
    test('maps recognized keys under fontify_plus onto their CliArgument', () {
      final config = parseConfig('''
fontify_plus:
  input_svg_dir: ./svg
  class_name: MyIcons
  indent: 4
''');

      expect(config![CliArgument.svgDir], './svg');
      expect(config[CliArgument.className], 'MyIcons');
      expect(config[CliArgument.indent], 4);
    });

    test('returns null when there is no fontify_plus section', () {
      final config = parseConfig('''
some_other_tool:
  input_svg_dir: ./svg
''');

      expect(config, isNull);
    });

    test('returns null for a non-map YAML document', () {
      expect(parseConfig('just a string'), isNull);
      expect(parseConfig('- a\n- b'), isNull);
    });

    test('skips and warns about a key with no matching CliArgument', () {
      Map<CliArgument, dynamic>? config;
      final lines = capturePrints(() {
        config = parseConfig('''
fontify_plus:
  not_a_real_key: 1
  class_name: MyIcons
''');
      });

      expect(config, isNotNull);
      expect(config!.containsKey(CliArgument.className), isTrue);
      expect(config, hasLength(1));
      expect(lines.single, contains('not_a_real_key'));
    });

    test('skips and warns about a non-string key', () {
      final lines = capturePrints(() {
        parseConfig('''
fontify_plus:
  1: value
''');
      });

      expect(lines, isNotEmpty);
    });
  });
}
