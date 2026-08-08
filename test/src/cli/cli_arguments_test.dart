import 'dart:io';

import 'package:fontify_plus/src/cli/cli_argument.dart';
import 'package:fontify_plus/src/cli/cli_arguments.dart';
import 'package:test/test.dart';

void main() {
  group('CliArguments.fromMap', () {
    test('casts every present value to its declared type', () {
      final args = CliArguments.fromMap({
        CliArgument.svgDir: Directory('svg'),
        CliArgument.fontFile: File('font.otf'),
        CliArgument.classFile: File('icons.dart'),
        CliArgument.className: 'MyIcons',
        CliArgument.indent: 4,
        CliArgument.fontPackage: 'my_package',
        CliArgument.fontName: 'My Icons',
        CliArgument.recursive: true,
        CliArgument.ignoreShapes: false,
        CliArgument.outlineStrokes: true,
        CliArgument.normalize: false,
        CliArgument.useOpenType: true,
        CliArgument.verbose: true,
        CliArgument.configFile: File('fontify_plus.yaml'),
      });

      expect(args.svgDir.path, 'svg');
      expect(args.fontFile.path, 'font.otf');
      expect(args.classFile?.path, 'icons.dart');
      expect(args.className, 'MyIcons');
      expect(args.indent, 4);
      expect(args.fontPackage, 'my_package');
      expect(args.fontName, 'My Icons');
      expect(args.recursive, isTrue);
      expect(args.ignoreShapes, isFalse);
      expect(args.outlineStrokes, isTrue);
      expect(args.normalize, isFalse);
      expect(args.useOpenType, isTrue);
      expect(args.verbose, isTrue);
      expect(args.configFile?.path, 'fontify_plus.yaml');
    });

    test('leaves every optional field null when absent from the map', () {
      final args = CliArguments.fromMap({
        CliArgument.svgDir: Directory('svg'),
        CliArgument.fontFile: File('font.otf'),
      });

      expect(args.classFile, isNull);
      expect(args.className, isNull);
      expect(args.indent, isNull);
      expect(args.fontPackage, isNull);
      expect(args.fontName, isNull);
      expect(args.recursive, isNull);
      expect(args.ignoreShapes, isNull);
      expect(args.outlineStrokes, isNull);
      expect(args.normalize, isNull);
      expect(args.useOpenType, isNull);
      expect(args.verbose, isNull);
      expect(args.configFile, isNull);
    });
  });
}
