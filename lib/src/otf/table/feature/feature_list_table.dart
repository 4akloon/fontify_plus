import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import 'feature_record.dart';
import 'feature_table.dart';

const _kDefaultFeatureTableList = [
  FeatureTable(0, 1, [0]),
];

List<FeatureRecord> _createDefaultFeatureRecordList() => [
  FeatureRecord('liga', null),
];

/// Every layout feature the font declares.
class FeatureListTable implements BinaryCodable {
  FeatureListTable(this.featureCount, this.featureRecords, this.featureTables);

  factory FeatureListTable.fromByteData(ByteData byteData, int offset) {
    final featureCount = byteData.getUint16(offset);

    final featureRecords = List.generate(
      featureCount,
      (i) => FeatureRecord.fromByteData(
        byteData,
        offset + 2 + kFeatureRecordSize * i,
      ),
    );

    return FeatureListTable(
      featureCount,
      featureRecords,
      [
        for (final record in featureRecords)
          FeatureTable.fromByteData(byteData, offset, record),
      ],
    );
  }

  factory FeatureListTable.create() {
    final records = _createDefaultFeatureRecordList();

    return FeatureListTable(
      records.length,
      records,
      _kDefaultFeatureTableList,
    );
  }

  final int featureCount;
  final List<FeatureRecord> featureRecords;

  final List<FeatureTable> featureTables;

  @override
  int get size =>
      2 +
      featureRecords.fold<int>(0, (p, r) => p + r.size) +
      featureTables.fold<int>(0, (p, t) => p + t.size);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, featureCount);

    var recordOffset = 2;
    var tableRelativeOffset = 2 + kFeatureRecordSize * featureCount;

    for (var i = 0; i < featureCount; i++) {
      final record = featureRecords[i]
        ..featureOffset = tableRelativeOffset
        ..encodeToBinary(
          byteData.sublistView(recordOffset, kFeatureRecordSize),
        );

      final table = featureTables[i];
      table.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, table.size),
      );

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }
  }
}
