part of 'cff.dart';

/// Adds the Top DICT entries whose operands are offsets, with placeholder
/// values.
///
/// They must exist before the layout is measured, because their own encoded
/// width is part of what is being measured.
void _generateCFF2TopDictEntries(CFF2Table table) {
  table.topDict.entryList = <CFFDictEntry>[
    CFFDictEntry([CFFOperand.fromValue(0)], op.charStrings),
    if (table.vstoreData != null)
      CFFDictEntry([CFFOperand.fromValue(0)], op.vstore),
    CFFDictEntry([CFFOperand.fromValue(0)], op.fdArray),
    // NOTE: not encoding FDSelect - using single Font DICT only
  ];
}

/// Fills the Top DICT's offset operands in with the real layout.
void _recalculateCFF2TopDictOffsets(CFF2Table table) {
  // Generating entries with zero-values
  _generateCFF2TopDictEntries(table);

  final topDict = table.topDict;

  var offset = table.header.size + table.globalSubrsData.size + topDict.size;

  int? vstoreOffset;

  if (table.vstoreData != null) {
    vstoreOffset = offset;
    offset += table.vstoreData!.size;
  }

  final charStringsOffset = offset;
  offset += table.charStringsData.size;

  final fdArrayOffset = offset;

  final vstoreEntry = topDict.getEntryForOperator(op.vstore);

  _calculateEntryOffsets(
    [
      ?vstoreEntry,
      topDict.getEntryForOperator(op.charStrings)!,
      topDict.getEntryForOperator(op.fdArray)!,
    ],
    [
      if (table.vstoreData != null) vstoreOffset!,
      charStringsOffset,
      fdArrayOffset,
    ],
    operandIndex: 0,
  );
}

/// Points each Font DICT at its Private DICT, and each Private DICT at its
/// local subroutines.
void _recalculateCFF2FontDictOffsets(CFF2Table table) {
  final fdArrayEntry = table.topDict.getEntryForOperator(op.fdArray)!;
  final fdArrayOffset = fdArrayEntry.operandList.first.value as int;

  var fontDictOffset = fdArrayOffset + table.fontDictList.index!.size;

  for (var i = 0; i < table.fontDictList.data.length; i++) {
    final fontDict = table.fontDictList.data[i];
    final privateDict = table.privateDictList[i];
    final privateEntry = fontDict.getEntryForOperator(op.private)!;

    privateEntry.operandList
      ..clear()
      ..addAll([
        CFFOperand.fromValue(privateDict.size),
        CFFOperand.fromValue(0),
      ]);

    fontDictOffset += fontDict.size;

    final subrsEntry = privateDict.getEntryForOperator(op.subrs);

    if (subrsEntry != null) {
      subrsEntry.operandList
        ..clear()
        ..add(CFFOperand.fromValue(0));
      subrsEntry.recalculatePointers(0, () => privateDict.size);
    }

    _calculateEntryOffsets([privateEntry], [fontDictOffset], operandIndex: 1);
  }
}
