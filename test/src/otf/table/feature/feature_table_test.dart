import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/feature/feature_record.dart';
import 'package:fontify_plus/src/otf/table/feature/feature_table.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureTable.size', () {
    test('is 4 bytes plus 2 per lookup index', () {
      const table = FeatureTable(0, 2, [0, 1]);

      expect(table.size, 8);
    });
  });

  group('FeatureTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      const table = FeatureTable(0, 1, [3]);
      final record = FeatureRecord('liga', 0);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = FeatureTable.fromByteData(bytes, 0, record);

      expect(decoded.featureParams, 0);
      expect(decoded.lookupIndexCount, 1);
      expect(decoded.lookupListIndices, [3]);
    });

    test('reads the table at the record\'s featureOffset', () {
      const table = FeatureTable(0, 1, [3]);
      final record = FeatureRecord('liga', 10);
      final bytes = ByteData(10 + table.size);

      table.encodeToBinary(bytes.sublistView(10, table.size));
      final decoded = FeatureTable.fromByteData(bytes, 0, record);

      expect(decoded.lookupListIndices, [3]);
    });
  });
}
