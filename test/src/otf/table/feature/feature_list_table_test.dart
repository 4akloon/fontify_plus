import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/feature/feature_list_table.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureListTable.create', () {
    test('declares a single ligature feature', () {
      final table = FeatureListTable.create();

      expect(table.featureCount, 1);
      expect(table.featureRecords.single.featureTag, 'liga');
    });

    test('points the ligature feature at lookup index 0', () {
      final table = FeatureListTable.create();

      expect(table.featureTables.single.lookupListIndices, [0]);
    });
  });

  group('FeatureListTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = FeatureListTable.create();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = FeatureListTable.fromByteData(bytes, 0);

      expect(decoded.featureCount, 1);
      expect(decoded.featureRecords.single.featureTag, 'liga');
      expect(decoded.featureTables.single.lookupListIndices, [0]);
    });
  });
}
