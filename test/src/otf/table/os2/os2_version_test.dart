import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:test/test.dart';

void main() {
  group('kOS2VersionDataSize', () {
    test('sums to the full version-5 table size', () {
      final total = kOS2VersionDataSize.values.fold<int>(0, (p, v) => p + v);

      expect(total, 100);
    });

    test('is keyed by version, in ascending order', () {
      expect(kOS2VersionDataSize.keys.toList(), [
        kOS2Version0,
        kOS2Version1,
        kOS2Version4,
        kOS2Version5,
      ]);
    });
  });
}
