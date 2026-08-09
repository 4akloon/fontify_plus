import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import 'substitution_subtable.dart';

/// One lookup: a type, its flags, and the subtables that apply it.
class LookupTable implements BinaryCodable {
  const LookupTable(
    this.lookupType,
    this.lookupFlag,
    this.subTableCount,
    this.subtableOffsets,
    this.markFilteringSet,
    this.subtables,
  );

  factory LookupTable.fromByteData(ByteData byteData, int offset) {
    final lookupType = byteData.getUint16(offset);
    final lookupFlag = byteData.getUint16(offset + 2);
    final subTableCount = byteData.getUint16(offset + 4);

    final subtableOffsets = List.generate(
      subTableCount,
      (i) => byteData.getUint16(offset + 6 + 2 * i),
    );

    final markFilteringSetOffset = offset + 6 + 2 * subTableCount;

    return LookupTable(
      lookupType,
      lookupFlag,
      subTableCount,
      subtableOffsets,
      _useMarkFilteringSet(lookupFlag)
          ? byteData.getUint16(markFilteringSetOffset)
          : null,
      List.generate(
        subTableCount,
        (i) => SubstitutionSubtable.fromByteData(
          byteData,
          offset + subtableOffsets[i],
          lookupType,
        ),
      ).whereType<SubstitutionSubtable>().toList(),
    );
  }

  final int lookupType;
  final int lookupFlag;
  final int subTableCount;
  final List<int> subtableOffsets;
  final int? markFilteringSet;

  final List<SubstitutionSubtable> subtables;

  @override
  int get size =>
      6 + 2 * subTableCount + subtables.fold<int>(0, (p, t) => p + t.size);

  static bool _useMarkFilteringSet(int lookupFlag) =>
      checkBitMask(lookupFlag, 0x0010);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, lookupType)
      ..setUint16(2, lookupFlag)
      ..setUint16(4, subTableCount);

    var currentRelativeOffset = 6 + 2 * subTableCount;
    final subtableOffsetList = <int>[];

    for (final subtable in subtables) {
      subtable.encodeToBinary(
        byteData.sublistView(currentRelativeOffset, subtable.size),
      );
      subtableOffsetList.add(currentRelativeOffset);
      currentRelativeOffset += subtable.size;
    }

    for (var i = 0; i < subTableCount; i++) {
      byteData.setInt16(6 + 2 * i, subtableOffsetList[i]);
    }

    if (_useMarkFilteringSet(lookupFlag)) {
      byteData.setUint16(6 + 2 * subTableCount, markFilteringSet!);
    }
  }
}
