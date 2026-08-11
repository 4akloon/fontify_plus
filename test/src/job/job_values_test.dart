import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/job/job_field.dart';
import 'package:fontify_plus/src/job/job_values.dart';
import 'package:test/test.dart';

Matcher _throwsFontifyExceptionSaying(Matcher messageMatcher) => throwsA(
  isA<FontifyException>().having((e) => e.message, 'message', messageMatcher),
);

void main() {
  group('JobValueReaders.readString', () {
    test('returns the value when it is a string', () {
      final values = <JobField, Object?>{JobField.className: 'Icons'};

      expect(values.readString(JobField.className), 'Icons');
    });

    test('returns null when the field is absent or explicitly null', () {
      final values = <JobField, Object?>{JobField.className: null};

      expect(values.readString(JobField.className), isNull);
      expect(values.readString(JobField.package), isNull);
    });

    test('throws naming the config key when the value is another type', () {
      final values = <JobField, Object?>{JobField.className: 42};

      expect(
        () => values.readString(JobField.className),
        _throwsFontifyExceptionSaying(
          allOf(contains('class_name'), contains('string')),
        ),
      );
    });
  });

  group('JobValueReaders.readBool', () {
    test('returns the value when it is a boolean', () {
      final values = <JobField, Object?>{JobField.recursive: true};

      expect(values.readBool(JobField.recursive), isTrue);
    });

    test('returns null when the field is absent', () {
      expect(<JobField, Object?>{}.readBool(JobField.recursive), isNull);
    });

    test('throws naming the config key when the value is another type', () {
      final values = <JobField, Object?>{JobField.recursive: 'yes'};

      expect(
        () => values.readBool(JobField.recursive),
        _throwsFontifyExceptionSaying(
          allOf(contains('recursive'), contains('boolean')),
        ),
      );
    });
  });

  group('JobValueReaders.readInt', () {
    test('returns the value when it is an integer', () {
      final values = <JobField, Object?>{JobField.indent: 4};

      expect(values.readInt(JobField.indent), 4);
    });

    test('returns null when the field is absent', () {
      expect(<JobField, Object?>{}.readInt(JobField.indent), isNull);
    });

    test('throws naming the config key when the value is another type', () {
      // An uncoerced string reaching a reader is the exact case the old
      // `merged[field] as int?` turned into a bare _TypeError.
      final values = <JobField, Object?>{JobField.indent: '4'};

      expect(
        () => values.readInt(JobField.indent),
        _throwsFontifyExceptionSaying(
          allOf(contains('indent'), contains('integer')),
        ),
      );
    });
  });

  group('JobValueReaders.require*', () {
    test('returns the value when present and of the right type', () {
      final values = <JobField, Object?>{
        JobField.inputSvgDir: 'a/',
        JobField.indent: 2,
        JobField.recursive: false,
      };

      expect(values.requireString(JobField.inputSvgDir), 'a/');
      expect(values.requireInt(JobField.indent), 2);
      expect(values.requireBool(JobField.recursive), isFalse);
    });

    test('throws naming the config key when the value is missing', () {
      const values = <JobField, Object?>{};

      expect(
        () => values.requireString(JobField.inputSvgDir),
        _throwsFontifyExceptionSaying(
          allOf(contains('input_svg_dir'), contains('required')),
        ),
      );
      expect(
        () => values.requireInt(JobField.indent),
        _throwsFontifyExceptionSaying(contains('indent')),
      );
      expect(
        () => values.requireBool(JobField.recursive),
        _throwsFontifyExceptionSaying(contains('recursive')),
      );
    });
  });

  group('resolveFontJob', () {
    test('reports an uncoercible value as a config error, not a TypeError', () {
      expect(
        () => resolveFontJob(
          layers: [
            {
              JobField.inputSvgDir: 'a/',
              JobField.outputFontFile: 'b.otf',
              JobField.className: 42,
            },
          ],
        ),
        _throwsFontifyExceptionSaying(contains('class_name')),
      );
    });

    test('falls back to the built-in defaults for absent fields', () {
      final job = resolveFontJob(
        layers: [
          {JobField.inputSvgDir: 'a/', JobField.outputFontFile: 'b.otf'},
        ],
      );

      expect(job.indent, kJobBuiltInDefaults.requireInt(JobField.indent));
      expect(
        job.recursive,
        kJobBuiltInDefaults.requireBool(JobField.recursive),
      );
      expect(
        job.normalize,
        kJobBuiltInDefaults.requireBool(JobField.normalize),
      );
      expect(
        job.outlineStrokes,
        kJobBuiltInDefaults.requireBool(JobField.outlineStrokes),
      );
      expect(
        job.useOpenType,
        kJobBuiltInDefaults.requireBool(JobField.useOpenType),
      );
    });
  });

  group('resolveVerboseFromLayers', () {
    test('reads the merged verbose flag', () {
      expect(
        resolveVerboseFromLayers([
          {JobField.verbose: false},
          {JobField.verbose: true},
        ]),
        isTrue,
      );
    });

    test('falls back to the built-in default', () {
      expect(
        resolveVerboseFromLayers([]),
        kJobBuiltInDefaults.requireBool(JobField.verbose),
      );
    });
  });
}
