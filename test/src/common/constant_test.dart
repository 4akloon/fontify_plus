import 'package:fontify_plus/src/common/constant.dart';
import 'package:test/test.dart';

void main() {
  group('vendor constants', () {
    test('kVendorName is non-empty', () {
      expect(kVendorName, isNotEmpty);
    });

    test('kVendorUrl is a URL pointing at the vendor', () {
      expect(kVendorUrl, startsWith('https://'));
    });
  });
}
