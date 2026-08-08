import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/feature/feature_record.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureRecord', () {
    test('size is fixed at 6 bytes', () {
      final record = FeatureRecord('liga', 0);

      expect(record.size, 6);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final record = FeatureRecord('liga', 12);
      final bytes = ByteData(record.size);

      record.encodeToBinary(bytes);
      final decoded = FeatureRecord.fromByteData(bytes, 0);

      expect(decoded.featureTag, 'liga');
      expect(decoded.featureOffset, 12);
    });
  });
}
