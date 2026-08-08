import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../table_record_entry.dart';
import 'encoding_record.dart';

/// The cmap table's own header: a version and the encoding records.
class CharacterToGlyphTableHeader implements BinaryCodable {
  CharacterToGlyphTableHeader(
    this.version,
    this.numTables,
    this.encodingRecords,
  );

  factory CharacterToGlyphTableHeader.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final numTables = byteData.getUint16(entry.offset + 2);

    return CharacterToGlyphTableHeader(
      byteData.getUint16(entry.offset),
      numTables,
      List.generate(
        numTables,
        (i) => EncodingRecord.fromByteData(
          byteData,
          entry.offset + 4 + kEncodingRecordSize * i,
        ),
      ),
    );
  }

  final int version;
  final int numTables;
  final List<EncodingRecord> encodingRecords;

  @override
  int get size => 4 + kEncodingRecordSize * encodingRecords.length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, version)
      ..setUint16(2, numTables);

    for (var i = 0; i < encodingRecords.length; i++) {
      final record = encodingRecords[i];

      record.encodeToBinary(
        byteData.sublistView(4 + kEncodingRecordSize * i, record.size),
      );
    }
  }
}
