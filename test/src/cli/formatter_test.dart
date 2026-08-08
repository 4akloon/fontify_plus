import 'dart:io';

import 'package:fontify_plus/src/cli/cli_argument.dart';
import 'package:fontify_plus/src/cli/cli_exception.dart';
import 'package:fontify_plus/src/cli/formatter.dart';
import 'package:test/test.dart';

void main() {
  group('formatArguments', () {
    test(
      'formats svgDir/fontFile/classFile/configFile paths into File/Directory',
      () {
        final formatted = formatArguments({
          CliArgument.svgDir: './svg',
          CliArgument.fontFile: 'font.otf',
          CliArgument.classFile: 'icons.dart',
          CliArgument.configFile: 'fontify_plus.yaml',
        });

        expect(formatted[CliArgument.svgDir], isA<Directory>());
        expect(formatted[CliArgument.fontFile], isA<File>());
        expect(formatted[CliArgument.classFile], isA<File>());
        expect(formatted[CliArgument.configFile], isA<File>());
      },
    );

    test('leaves an already-int indent as-is', () {
      final formatted = formatArguments({CliArgument.indent: 4});

      expect(formatted[CliArgument.indent], 4);
    });

    test('parses a numeric string indent into an int', () {
      final formatted = formatArguments({CliArgument.indent: '4'});

      expect(formatted[CliArgument.indent], 4);
    });

    test('throws CliArgumentException for a non-numeric string indent', () {
      expect(
        () => formatArguments({CliArgument.indent: 'abc'}),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('throws CliArgumentException for a non-string, non-int indent', () {
      expect(
        () => formatArguments({CliArgument.indent: true}),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('passes arguments with no formatter through unchanged', () {
      final formatted = formatArguments({CliArgument.className: 'MyIcons'});

      expect(formatted[CliArgument.className], 'MyIcons');
    });

    test('passes a null value through without calling its formatter', () {
      final formatted = formatArguments({CliArgument.fontFile: null});

      expect(formatted[CliArgument.fontFile], isNull);
    });
  });
}
