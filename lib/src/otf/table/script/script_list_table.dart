import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../language_system.dart';
import 'script_record.dart';
import 'script_table.dart';

/// Alphabetically ordered (by tag) list of script records
List<ScriptRecord> _defaultScriptRecordList() => [
  /// Default
  ScriptRecord('DFLT', null),

  /// Latin
  ScriptRecord('latn', null),
];

const _kDefaultLangSys = LanguageSystemTable(
  0,
  0xFFFF, // no required features
  1,
  [0],
);

const _kDefaultScriptTable = ScriptTable(4, 0, [], [], _kDefaultLangSys);

/// Every script the font declares support for.
class ScriptListTable implements BinaryCodable {
  ScriptListTable(this.scriptCount, this.scriptRecords, this.scriptTables);

  factory ScriptListTable.fromByteData(ByteData byteData, int offset) {
    final scriptCount = byteData.getUint16(offset);

    final scriptRecords = List.generate(
      scriptCount,
      (i) => ScriptRecord.fromByteData(
        byteData,
        offset + 2 + kScriptRecordSize * i,
      ),
    );

    return ScriptListTable(
      scriptCount,
      scriptRecords,
      [
        for (final record in scriptRecords)
          ScriptTable.fromByteData(byteData, offset, record),
      ],
    );
  }

  factory ScriptListTable.create() {
    final records = _defaultScriptRecordList();

    return ScriptListTable(
      records.length,
      records,
      List.filled(records.length, _kDefaultScriptTable),
    );
  }

  final int scriptCount;
  final List<ScriptRecord> scriptRecords;

  final List<ScriptTable> scriptTables;

  @override
  int get size =>
      2 +
      scriptRecords.fold<int>(0, (p, r) => p + r.size) +
      scriptTables.fold<int>(0, (p, t) => p + t.size);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, scriptCount);

    var recordOffset = 2;
    var tableRelativeOffset = 2 + kScriptRecordSize * scriptCount;

    for (var i = 0; i < scriptCount; i++) {
      final record = scriptRecords[i]
        ..scriptOffset = tableRelativeOffset
        ..encodeToBinary(byteData.sublistView(recordOffset, kScriptRecordSize));

      final table = scriptTables[i];
      table.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, table.size),
      );

      recordOffset += record.size;
      tableRelativeOffset += table.size;
    }
  }
}
