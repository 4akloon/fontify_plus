import 'dart:io';

import 'package:fontify_plus/src/cli/argument_validation.dart';
import 'package:fontify_plus/src/cli/cli_argument.dart';
import 'package:fontify_plus/src/cli/cli_exception.dart';
import 'package:test/test.dart';

void main() {
  group('validateAndFormat type checking', () {
    test('throws when an argument\'s raw type is not among its allowed types',
        () {
      expect(
        () => {CliArgument.normalize: 'not a bool'}.validateAndFormat(),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('allows a null value for a non-required argument', () {
      expect(
        () => {
          CliArgument.svgDir: '.',
          CliArgument.fontFile: 'font.otf',
          CliArgument.normalize: null,
        }.validateAndFormat(),
        returnsNormally,
      );
    });
  });

  group('validateAndFormat required fields', () {
    test('throws when svgDir is missing', () {
      expect(
        () => {CliArgument.fontFile: 'font.otf'}.validateAndFormat(),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('throws when fontFile is missing', () {
      expect(
        () => {CliArgument.svgDir: '.'}.validateAndFormat(),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('throws when svgDir does not exist', () {
      expect(
        () => {
          CliArgument.svgDir: './this/path/should/not/exist',
          CliArgument.fontFile: 'font.otf',
        }.validateAndFormat(),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('throws when indent is negative', () {
      expect(
        () => {
          CliArgument.svgDir: '.',
          CliArgument.fontFile: 'font.otf',
          CliArgument.indent: -1,
        }.validateAndFormat(),
        throwsA(isA<CliArgumentException>()),
      );
    });

    test('passes for a valid, existing directory and a non-negative indent',
        () {
      final formatted = {
        CliArgument.svgDir: '.',
        CliArgument.fontFile: 'font.otf',
        CliArgument.indent: 2,
      }.validateAndFormat();

      expect(formatted[CliArgument.svgDir], isA<Directory>());
      expect(formatted[CliArgument.fontFile], isA<File>());
    });
  });
}
