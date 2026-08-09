import 'package:fontify_plus/src/otf/cff/char_string_limits.dart';
import 'package:test/test.dart';

void main() {
  group('CharStringInterpreterLimits', () {
    test('CFF1 allows 48 stack arguments', () {
      expect(CharStringInterpreterLimits(true).argumentStackLimit, 48);
    });

    test('CFF2 allows 513 stack arguments', () {
      expect(CharStringInterpreterLimits(false).argumentStackLimit, 513);
    });
  });
}
