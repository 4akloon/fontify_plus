import 'package:fontify_plus/src/job/fontify_config.dart';
import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/job/job_field.dart';
import 'package:fontify_plus/src/job/job_values.dart';
import 'package:test/test.dart';

void main() {
  group('parseFontifyConfig', () {
    test('parses defaults and multiple fonts', () {
      final config = parseFontifyConfig('''
fontify_plus:
  defaults:
    recursive: true
    normalize: false
  fonts:
    icons:
      input_svg_dir: assets/icons/
      output_font_file: fonts/icons.otf
    brand:
      input_svg_dir: assets/brand/
      output_font_file: fonts/brand.otf
      class_name: BrandIcons
''');

      expect(config.fonts.keys, containsAll(['icons', 'brand']));
      final jobs = config.resolve();
      expect(jobs, hasLength(2));
      expect(jobs[0].name, 'icons');
      expect(jobs[0].recursive, isTrue);
      expect(jobs[0].normalize, isFalse);
      expect(jobs[1].className, 'BrandIcons');
    });

    test('rejects legacy flat config', () {
      expect(
        () => parseFontifyConfig('''
fontify_plus:
  input_svg_dir: ./
  output_font_file: out.otf
'''),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            contains('Legacy flat'),
          ),
        ),
      );
    });

    test('rejects empty fonts', () {
      expect(
        () => parseFontifyConfig('''
fontify_plus:
  fonts: {}
'''),
        throwsA(isA<FontifyException>()),
      );
    });

    test('unknown font filter errors with known names', () {
      final config = parseFontifyConfig('''
fontify_plus:
  fonts:
    icons:
      input_svg_dir: a/
      output_font_file: b.otf
''');

      expect(
        () => config.resolve(fontFilter: 'missing'),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('missing'), contains('icons')),
          ),
        ),
      );
    });
  });

  group('resolveFontJob', () {
    test('merges defaults, per-font, and cli overrides', () {
      final job = resolveFontJob(
        name: 'icons',
        layers: [
          {JobField.normalize: false},
          {JobField.inputSvgDir: 'a/', JobField.outputFontFile: 'b.otf'},
          {JobField.normalize: true},
        ],
      );

      expect(job.normalize, isTrue);
      expect(job.inputSvgDir, 'a/');
    });

    test('requires paths per font', () {
      expect(
        () => resolveFontJob(
          layers: [
            {JobField.outputFontFile: 'b.otf'},
          ],
        ),
        throwsA(isA<FontifyException>()),
      );
    });
  });
}
