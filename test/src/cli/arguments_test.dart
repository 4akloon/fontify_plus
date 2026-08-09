import 'dart:io';

import 'package:args/args.dart';
import 'package:fontify_plus/src/cli/arguments.dart';
import 'package:test/test.dart';

void main() {
  final argParser = ArgParser(allowTrailingOptions: true);

  group('parseArgsAndConfig', () {
    defineOptions(argParser);

    void expectCliArgumentException(List<String> args) {
      expect(
        () => parseArgsAndConfig(argParser, args),
        throwsA(const TypeMatcher<CliArgumentException>()),
      );
    }

    test('ad-hoc run with flags', () {
      const args = [
        './',
        'test/fonts/my_font.otf',
        '--output-class-file=test/a/df.dart',
        '--indent=4',
        '--class-name=MyIcons',
        '--font-name=My Icons',
        '--no-normalize',
        '--recursive',
        '--verbose',
        '--package=test_package',
      ];

      final request = parseArgsAndConfig(argParser, args);

      expect(request.jobs, hasLength(1));
      final job = request.jobs.single;
      expect(job.inputSvgDir, './');
      expect(job.outputFontFile, 'test/fonts/my_font.otf');
      expect(job.outputClassFile, 'test/a/df.dart');
      expect(job.indent, 4);
      expect(job.className, 'MyIcons');
      expect(job.fontName, 'My Icons');
      expect(job.normalize, isFalse);
      expect(job.recursive, isTrue);
      expect(job.package, 'test_package');
      expect(request.verbose, isTrue);
    });

    test('ad-hoc defaults when flags omitted', () {
      const args = ['./', 'test/fonts/my_font.otf'];

      final job = parseArgsAndConfig(argParser, args).jobs.single;

      expect(job.outputClassFile, isNull);
      expect(job.indent, 2);
      expect(job.normalize, isTrue);
      expect(job.recursive, isFalse);
      expect(job.outlineStrokes, isTrue);
      expect(job.preview, isTrue);
    });

    test('--no-preview disables dartdoc previews', () {
      const args = ['./', 'test/fonts/my_font.otf', '--no-preview'];

      final job = parseArgsAndConfig(argParser, args).jobs.single;

      expect(job.preview, isFalse);
    });

    test('missing positionals without config errors', () {
      expectCliArgumentException([]);
    });

    test('one positional without config errors', () {
      expectCliArgumentException(['./']);
    });

    test('non-existent input directory errors at run time, not parse', () {
      final request = parseArgsAndConfig(argParser, [
        './does_not_exist',
        'out.otf',
      ]);
      expect(request.jobs.single.inputSvgDir, './does_not_exist');
    });

    test('invalid indent errors', () {
      expectCliArgumentException(['./', 'out.otf', '--indent=-1']);
      expectCliArgumentException(['./', 'out.otf', '--indent=asdasd']);
    });

    test('help throws CliHelpException', () {
      expect(
        () => parseArgsAndConfig(argParser, ['-h']),
        throwsA(const TypeMatcher<CliHelpException>()),
      );
    });

    test('config-only run', () {
      final request = parseArgsAndConfig(argParser, [
        '--config-file=test/assets/test_config.yaml',
      ]);

      expect(request.jobs, hasLength(1));
      final job = request.jobs.single;
      expect(job.name, 'main');
      expect(job.inputSvgDir, './');
      expect(job.outputFontFile, 'generated_font.otf');
      expect(job.outputClassFile, 'lib/test_font.dart');
      expect(job.className, 'MyIcons');
      expect(job.fontName, 'My Icons');
      expect(job.normalize, isFalse);
      expect(job.recursive, isFalse);
      expect(request.verbose, isFalse);
      expect(job.package, 'test_package');
    });

    test('ad-hoc and config conflict', () {
      expectCliArgumentException([
        './',
        'no.otf',
        '--config-file=test/assets/test_config.yaml',
      ]);
    });

    test('--font cannot be used with positionals', () {
      expectCliArgumentException([
        './',
        'no.otf',
        '--font=main',
      ]);
    });

    test('--font selects one named set', () {
      final configFile = File('fontify_plus.yaml');
      configFile.writeAsStringSync('''
fontify_plus:
  fonts:
    icons:
      input_svg_dir: ./
      output_font_file: icons.otf
    brand:
      input_svg_dir: ./
      output_font_file: brand.otf
''');
      addTearDown(configFile.deleteSync);

      final request = parseArgsAndConfig(argParser, [
        '--config-file=fontify_plus.yaml',
        '--font=brand',
      ]);

      expect(request.jobs, hasLength(1));
      expect(request.jobs.single.name, 'brand');
      expect(request.jobs.single.outputFontFile, 'brand.otf');
    });

    test('unknown --font errors', () {
      expectCliArgumentException([
        '--config-file=test/assets/test_config.yaml',
        '--font=missing',
      ]);
    });
  });
}
