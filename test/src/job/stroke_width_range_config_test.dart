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

    // NaN and Infinity both parse as `num` (from YAML's .nan/.inf, or from
    // num.tryParse("NaN") / num.tryParse("Infinity") on a CLI string), so
    // neither is caught by the "must be a number" check. StrokeWidthRange's
    // own min <= 0 / max <= min guards do not catch every case either
    // (NaN <= 0 is false, and Infinity as the low endpoint is not <= a
    // finite max), so without an explicit finiteness check a non-finite
    // range would reach font generation instead of failing here as a
    // config error.
    test('a NaN low endpoint is rejected as non-finite', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [double.nan, 2]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('NaN')),
          ),
        ),
      );
    });

    test('a NaN high endpoint is rejected as non-finite', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [1.33, double.nan]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('NaN')),
          ),
        ),
      );
    });

    test('an infinite low endpoint is rejected as non-finite', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [double.infinity, 2]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('Infinity')),
          ),
        ),
      );
    });

    test('an infinite high endpoint is rejected as non-finite', () {
      expect(
        () => _coerce(JobField.strokeWidthRange, [1.33, double.infinity]),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('stroke_width_range'), contains('Infinity')),
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

  group('default_stroke_width coercion', () {
    test('a scalar YAML value becomes a double', () {
      expect(_coerce(JobField.defaultStrokeWidth, 1.5), 1.5);
    });

    test('an integer YAML value becomes a double', () {
      // YAML gives `default_stroke_width: 2` as an int, and readDouble reads
      // it back as a double - so the coercion has to widen it, or the read
      // would fail on a perfectly ordinary config.
      expect(_coerce(JobField.defaultStrokeWidth, 2), 2.0);
      expect(_coerce(JobField.defaultStrokeWidth, 2), isA<double>());
    });

    test('a CLI string is parsed the same way', () {
      expect(_coerce(JobField.defaultStrokeWidth, '1.5'), 1.5);
    });

    test('a non-numeric value names the value that was not a number', () {
      expect(
        () => _coerce(JobField.defaultStrokeWidth, 'wide'),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('default_stroke_width'), contains('wide')),
          ),
        ),
      );
    });

    // num.tryParse accepts "Infinity" and "NaN", and YAML's .inf/.nan arrive
    // as non-finite doubles directly. Neither is caught by the pairing checks
    // below - NaN loses every ordering test, and Infinity only fails the
    // upper one - so the coercion has to reject them first, exactly as it
    // does for the range's own endpoints.
    test('an infinite value is rejected before reaching validation', () {
      expect(
        () => _coerce(JobField.defaultStrokeWidth, 'Infinity'),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('default_stroke_width'), contains('Infinity')),
          ),
        ),
      );
    });

    test('a NaN value is rejected before reaching validation', () {
      expect(
        () => _coerce(JobField.defaultStrokeWidth, double.nan),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('default_stroke_width'), contains('NaN')),
          ),
        ),
      );
    });
  });

  group('default_stroke_width resolution', () {
    test('a default inside the range survives to the resolved job', () {
      final job = _jobFrom('''
stroke_width_range: [1.33, 2]
default_stroke_width: 1.5
''');

      expect(job.strokeWidthRange!.min, 1.33);
      expect(job.strokeWidthRange!.max, 2);
      expect(job.defaultStrokeWidth, 1.5);
    });

    test('an integral default written in YAML survives as a double', () {
      // The whole point of resolving through YAML rather than coercing in
      // isolation: an int here has to survive coercion, the typed read, and
      // the strictly-inside check before it reaches the job.
      final job = _jobFrom('''
stroke_width_range: [1, 3]
default_stroke_width: 2
''');

      expect(job.defaultStrokeWidth, 2.0);
    });

    test('no default at all resolves with a null defaultStrokeWidth', () {
      final job = _jobFrom('stroke_width_range: [1.33, 2]');

      expect(job.defaultStrokeWidth, isNull);
    });

    test('a default without a range is a config error naming both keys', () {
      expect(
        () => _resolve('default_stroke_width: 1.5'),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('default_stroke_width'),
              contains('stroke_width_range'),
            ),
          ),
        ),
      );
    });

    test('a default equal to the range maximum is a config error', () {
      expect(
        () => _resolve('''
stroke_width_range: [1.33, 2]
default_stroke_width: 2
'''),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('default_stroke_width'), contains('2')),
          ),
        ),
      );
    });

    test('a default equal to the range minimum is a config error', () {
      expect(
        () => _resolve('''
stroke_width_range: [1.33, 2]
default_stroke_width: 1.33
'''),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('default_stroke_width'), contains('1.33')),
          ),
        ),
      );
    });

    test('a default outside the range is a config error', () {
      expect(
        () => _resolve('''
stroke_width_range: [1.33, 2]
default_stroke_width: 2.5
'''),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(contains('default_stroke_width'), contains('2.5')),
          ),
        ),
      );
    });

    test('default_stroke_width is allowed in defaults:', () {
      // Font sets sharing one icon library share the width they open at just
      // as much as they share the range it sits in.
      expect(kJobDefaultsFields, contains(JobField.defaultStrokeWidth));
    });

    test('default_stroke_width has no built-in default', () {
      // Omitting it means "leave the default instance at the range maximum",
      // not "fall back to some number this package picked".
      expect(
        kJobBuiltInDefaults.containsKey(JobField.defaultStrokeWidth),
        isFalse,
      );
    });
  });
}
