import 'package:fontify_plus/src/job/job_field.dart';
import 'package:test/test.dart';

void main() {
  group('kJobConfigKeys', () {
    test('every config key is snake_case', () {
      for (final key in kJobConfigKeys.values) {
        expect(key, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
      }
    });
  });

  group('JobField.preview', () {
    test('maps to yaml, cli, and built-in default', () {
      expect(kJobConfigKeys[JobField.preview], 'preview');
      expect(kJobCliOptions[JobField.preview], 'preview');
      expect(kJobBuiltInDefaults.containsKey(JobField.preview), isFalse);
      expect(kJobDefaultsFields, contains(JobField.preview));
    });
  });

  group('jobFieldForConfigKey', () {
    test('resolves known keys', () {
      expect(jobFieldForConfigKey('input_svg_dir'), JobField.inputSvgDir);
      expect(jobFieldForConfigKey('opentype'), JobField.useOpenType);
      expect(jobFieldForConfigKey('preview'), JobField.preview);
    });

    test('returns null for unknown keys', () {
      expect(jobFieldForConfigKey('testing'), isNull);
    });
  });
}
