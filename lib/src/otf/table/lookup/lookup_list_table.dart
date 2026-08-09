import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../coverage.dart';
import 'ligature_substitution_subtable.dart';
import 'lookup_table.dart';

const kLookupListTableSize = 4;

const _kDefaultSubtableList = [
  LigatureSubstitutionSubtable(1, 6, 0, [], kDefaultCoverageTable),
];

const _kDefaultLookupTableList = [
  LookupTable(4, 0, 1, [8], null, _kDefaultSubtableList),
];

/// Every lookup in the font, in application order.
class LookupListTable implements BinaryCodable {
  LookupListTable(this.lookupCount, this.lookups, this.lookupTables);

  factory LookupListTable.fromByteData(ByteData byteData, int offset) {
    final lookupCount = byteData.getUint16(offset);

    final lookups = List.generate(
      lookupCount,
      (i) => byteData.getUint16(offset + 2 + 2 * i),
    );

    return LookupListTable(
      lookupCount,
      lookups,
      List.generate(
        lookupCount,
        (i) => LookupTable.fromByteData(byteData, offset + lookups[i]),
      ),
    );
  }

  factory LookupListTable.create() =>
      LookupListTable(1, [4], _kDefaultLookupTableList);

  final int lookupCount;
  final List<int> lookups;

  final List<LookupTable> lookupTables;

  @override
  int get size =>
      2 + 2 * lookupCount + lookupTables.fold<int>(0, (p, t) => p + t.size);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, lookupCount);

    var tableRelativeOffset = 2 + 2 * lookupCount;

    for (var i = 0; i < lookupCount; i++) {
      final subtable = lookupTables[i];

      subtable.encodeToBinary(
        byteData.sublistView(tableRelativeOffset, subtable.size),
      );

      byteData.setUint16(2 + 2 * i, tableRelativeOffset);
      tableRelativeOffset += subtable.size;
    }
  }
}
