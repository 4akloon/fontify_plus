import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/job/font_job.dart';
import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/job/job_field.dart';
import 'package:fontify_plus/src/job/job_values.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Coerces a single raw [value] as if it were the value of [field], the way
/// [coerceJobValues] does for one merged layer.
Object? _coerce(JobField field, Object? value) =>
    coerceJobValues({field: value})[field];

/// Parses [yamlFragment] as a `fonts.<name>:` body and resolves it into a
/// [FontJob], with a minimal base layer supplying the paths every job
/// requires so the fragment under test can omit them.
FontJob _jobFrom(String yamlFragment) {
  final yamlMap = loadYaml(yamlFragment) as YamlMap;
  final values = jobValuesFromYamlMap(
    yamlMap,
    allowedFields: JobField.values.toSet(),
  );
  return resolveFontJob(
    layers: [
      {JobField.inputSvgDir: 'a/', JobField.outputFontFile: 'b.otf'},
      values,
    ],
  );
}

// Resolving is what raises the conflict errors under test here; `_jobFrom`
// already exercises the exact same path, so this is just a readability
// alias for the tests that only care about the thrown exception.
FontJob _resolve(String yamlFragment) => _jobFrom(yamlFragment);

void main() {
  group('stroke_width_range coercion', () {
    test('a two-element YAML list becomes a range', () {
      final job = _jobFrom('stroke_width_range: [1.33, 2]');

      expect(job.strokeWidthRange!.min, 1.33);
      expect(job.strokeWidthRange!.max, 2);
    });

    test('integers are accepted, not just doubles', () {
      final job = _jobFrom('stroke_width_range: [1, 2]');

      expect(job.strokeWidthRange!.min, 1);
      expect(job.strokeWidthRange!.max, 2);
    });

    test('a CLI string is parsed the same way', () {
      expect(
        _coerce(JobField.strokeWidthRange, '1.33,2'),
        isA<StrokeWidthRange>()
            .having((r) => r.min, 'min', 1.33)
            .having((r) => r.max, 'max', 2),
      );
    });

    test('a CLI string with whitespace around the comma still parses', () {
      expect(
        _coerce(JobField.strokeWidthRange, '1.33, 2'),
        isA<StrokeWidthRange>()
            .having((r) => r.min, 'min', 1.33)
            .having((r) => r.max, 'max', 2),
      );
    });

    test('the wrong number of values names the count it got', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [1.33, 1.5, 2]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('3')),
          ),
        ),
      );
    });

    test('a single value names the count it got', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [1.33]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('1')),
          ),
        ),
      );
    });

    test('a non-list, non-string value names its type', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, 42),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('int')),
          ),
        ),
      );
    });

    test('a non-numeric entry names the value that was not a number', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [1.33, 'wide']),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('wide')),
          ),
        ),
      );
    });

    test('max <= min is rejected and the offending value is named', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [2, 1.33]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('1.33')),
          ),
        ),
      );
    });

    test('min <= 0 is rejected and the offending value is named', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [0, 2]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('0')),
          ),
        ),
      );
    });
  });

  group('stroke_width_range resolution', () {
    test('a range with outline_strokes: false is rejected at resolve time', () {
      expect(
        () => _resolve('''
stroke_width_range: [1.33, 2]
outline_strokes: false
'''),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('outline_strokes')),
          ),
        ),
      );
    });

    test('a range with opentype: false is rejected at resolve time', () {
      expect(
        () => _resolve('''
stroke_width_range: [1.33, 2]
opentype: false
'''),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('opentype')),
          ),
        ),
      );
    });

    test(
      'outline_strokes: false alone (no range) resolves without error',
      () {
        // Guards against the conflict check firing on outline_strokes: false
        // by itself instead of specifically when paired with a range - the
        // conflict is between the two fields, not a property of either one.
        final job = _resolve('outline_strokes: false');

        expect(job.outlineStrokes, isFalse);
        expect(job.strokeWidthRange, isNull);
      },
    );

    test('a range with both outline_strokes and opentype true resolves', () {
      final job = _resolve('''
stroke_width_range: [1.33, 2]
outline_strokes: true
opentype: true
''');

      expect(job.strokeWidthRange!.min, 1.33);
      expect(job.outlineStrokes, isTrue);
      expect(job.useOpenType, isTrue);
    });

    test('no range at all resolves with a null strokeWidthRange', () {
      final job = _resolve('recursive: true');

      expect(job.strokeWidthRange, isNull);
    });

    test('a range is allowed in defaults:', () {
      // Every font set in one config usually shares its icon library, so
      // repeating the range per set would be the common case otherwise.
      expect(kJobDefaultsFields, contains(JobField.strokeWidthRange));
    });

    test('a range has no built-in default', () {
      // The spec is explicit: the range sets both the delta magnitude and
      // how deeply every glyph is subdivided, so guessing one would be
      // guessing both.
      expect(
        kJobBuiltInDefaults.containsKey(JobField.strokeWidthRange),
        isFalse,
      );
    });
  });
}
