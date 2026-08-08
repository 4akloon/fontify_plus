part of 'cff.dart';

/// Adds the Top DICT entries whose operands are offsets, with placeholder
/// values.
///
/// They must exist before the layout is measured, because their own encoded
/// width is part of what is being measured.
void _generateCFF1TopDictEntries(CFF1Table table) {
  final entryList = <CFFDictEntry>[
    CFFDictEntry([CFFOperand.fromValue(0)], op.charset),
    CFFDictEntry([CFFOperand.fromValue(0)], op.charStrings),
    CFFDictEntry(
      [
        CFFOperand.fromValue(table.privateDictList.first.size),
        CFFOperand.fromValue(0),
      ],
      op.private,
    ),
  ];

  final operatorList = entryList.map((e) => e.operator).toList();

  table.topDict.entryList
    ..removeWhere((e) => operatorList.contains(e.operator))
    ..addAll(entryList);
}

/// Fills the Top DICT's offset operands in with the real layout.
void _recalculateCFF1TopDictOffsets(CFF1Table table) {
  // Generating entries with zero-values
  _generateCFF1TopDictEntries(table);

  var offset = table._fixedSize;

  final charsetOffset = offset;
  offset += table.charsets.size;

  final charStringsOffset = offset;
  offset += table.charStringsData.size;

  // NOTE: Using only first private dict
  final privateDictOffset = offset;

  final topDict = table.topDict;

  _calculateEntryOffsets(
    [
      topDict.getEntryForOperator(op.charset)!,
      topDict.getEntryForOperator(op.charStrings)!,
      topDict.getEntryForOperator(op.private)!,
    ],
    [charsetOffset, charStringsOffset, privateDictOffset],
    operandIndexList: [0, 0, 1],
  );
}
