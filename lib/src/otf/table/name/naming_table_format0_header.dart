import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../../debugger.dart';
import '../table_record_entry.dart';
import 'name_record.dart';
import 'naming_table.dart';

/// The format 0 header: a record per string, then the storage area.
class NamingTableFormat0Header implements BinaryCodable {
  const NamingTableFormat0Header({
    required this.format,
    required this.count,
    required this.stringOffset,
    required this.nameRecordList,
  });

  factory NamingTableFormat0Header.create(List<NameRecord> nameRecordList) =>
      NamingTableFormat0Header(
        format: kNameFormat0,
        count: nameRecordList.length,
        stringOffset: 6 + nameRecordList.length * kNameRecordSize,
        nameRecordList: nameRecordList,
      );

  static NamingTableFormat0Header? fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final format = byteData.getUint16(entry.offset);

    if (format != kNameFormat0) {
      debuggerOTF.debugUnsupportedTableFormat(entry.tag, format);
      return null;
    }

    final count = byteData.getUint16(entry.offset + 2);

    return NamingTableFormat0Header(
      format: format,
      count: count,
      stringOffset: byteData.getUint16(entry.offset + 4),
      nameRecordList: List.generate(
        count,
        (i) => NameRecord.fromByteData(
          byteData,
          entry.offset + 6 + i * kNameRecordSize,
        ),
      ),
    );
  }

  final int format;
  final int count;
  final int stringOffset;
  final List<NameRecord> nameRecordList;

  @override
  int get size => 6 + nameRecordList.length * kNameRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, count)
      ..setUint16(4, stringOffset);

    var recordOffset = 6;

    for (final record in nameRecordList) {
      record.encodeToBinary(byteData.sublistView(recordOffset, record.size));
      recordOffset += record.size;
    }
  }
}
