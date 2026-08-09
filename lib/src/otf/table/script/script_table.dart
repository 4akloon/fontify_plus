import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../language_system.dart';
import 'script_record.dart';

/// The language systems available for one script.
class ScriptTable implements BinaryCodable {
  const ScriptTable(
    this.defaultLangSysOffset,
    this.langSysCount,
    this.langSysRecords,
    this.langSysTables,
    this.defaultLangSys,
  );

  factory ScriptTable.fromByteData(
    ByteData byteData,
    int offset,
    ScriptRecord record,
  ) {
    offset += record.scriptOffset!;

    final defaultLangSysOffset = byteData.getUint16(offset);

    final defaultLangSys = defaultLangSysOffset == 0
        ? null
        : LanguageSystemTable.fromByteData(
            byteData,
            offset + defaultLangSysOffset,
          );

    final langSysCount = byteData.getUint16(offset + 2);

    final langSysRecords = List.generate(
      langSysCount,
      (i) => LanguageSystemRecord.fromByteData(
        byteData,
        offset + 4 + kLangSysRecordSize * i,
      ),
    );

    return ScriptTable(
      defaultLangSysOffset,
      langSysCount,
      langSysRecords,
      [
        for (final record in langSysRecords)
          LanguageSystemTable.fromByteData(
            byteData,
            offset + record.langSysOffset,
          ),
      ],
      defaultLangSys,
    );
  }

  final int defaultLangSysOffset;
  final int langSysCount;
  final List<LanguageSystemRecord> langSysRecords;

  final List<LanguageSystemTable> langSysTables;
  final LanguageSystemTable? defaultLangSys;

  @override
  int get size =>
      4 +
      (defaultLangSys?.size ?? 0) +
      langSysRecords.fold<int>(0, (p, r) => p + r.size) +
      langSysTables.fold<int>(0, (p, t) => p + t.size);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(2, langSysCount);

    var recordOffset = 4;
    var tableRelativeOffset = 4 + kLangSysRecordSize * langSysRecords.length;

    for (var i = 0; i < langSysRecords.length; i++) {
      final record = langSysRecords[i]
        ..langSysOffset = tableRelativeOffset
        ..encodeToBinary(
          byteData.sublistView(recordOffset, kLangSysRecordSize),
        );

      final table = langSysTables[i];
      table.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, table.size),
      );

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }

    // The default system follows the listed ones, so its offset is only known
    // once they have all been written.
    byteData.setUint16(0, tableRelativeOffset);

    defaultLangSys?.encodeToBinary(
      byteData.sublistView(tableRelativeOffset, defaultLangSys!.size),
    );
  }
}
