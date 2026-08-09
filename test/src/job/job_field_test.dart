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

  group('jobFieldForConfigKey', () {
    test('resolves known keys', () {
      expect(jobFieldForConfigKey('input_svg_dir'), JobField.inputSvgDir);
      expect(jobFieldForConfigKey('opentype'), JobField.useOpenType);
    });

    test('returns null for unknown keys', () {
      expect(jobFieldForConfigKey('testing'), isNull);
    });
  });
}
