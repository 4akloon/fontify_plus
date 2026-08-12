part of 'cff.dart';

/// Reads a CFF1 table out of an existing font.
///
/// NOTE: nothing in the SVG-to-font pipeline calls this — it exists for the
/// reader side, which parses tables but never re-encodes what it read.
CFF1Table _readCFF1Table(ByteData byteData, TableRecordEntry entry) {
  /// 3 entries with fixed location
  var fixedOffset = entry.offset;

  final header = CFF1TableHeader.fromByteData(
    byteData.sublistView(fixedOffset, _kCFF2HeaderSize),
  );
  fixedOffset += header.size;

  final nameIndex = CFFIndexWithData<Uint8List>.fromByteData(
    byteData.sublistView(fixedOffset),
    true,
  );
  fixedOffset += nameIndex.size;

  final topDicts = CFFIndexWithData<CFFDict>.fromByteData(
    byteData.sublistView(fixedOffset),
    true,
  );
  fixedOffset += topDicts.size;

  // NOTE: Using only first Top DICT
  final topDict = topDicts.data.first;

  /// String INDEX
  final stringIndex = CFFIndexWithData<Uint8List>.fromByteData(
    byteData.sublistView(fixedOffset),
    true,
  );
  fixedOffset += stringIndex.size;

  final globalSubrsData = CFFIndexWithData<Uint8List>.fromByteData(
    byteData.sublistView(fixedOffset),
    true,
  );
  fixedOffset += globalSubrsData.index!.size;

  /// CharStrings INDEX
  final charStringsIndexOffset =
      topDict.getEntryForOperator(op.charStrings)!.operandList.first.value
          as int;

  final charStringsData = CFFIndexWithData<Uint8List>.fromByteData(
    byteData.sublistView(entry.offset + charStringsIndexOffset),
    true,
  );

  /// Charsets
  final charsetsOffset =
      topDict.getEntryForOperator(op.charset)!.operandList.first.value as int;

  final charsetEntry = CharsetEntry.fromByteData(
    byteData.sublistView(entry.offset + charsetsOffset),
    charStringsData.index!.count,
  )!;

  final privateEntry = topDict.getEntryForOperator(op.private)!;
  final dictOffset =
      entry.offset + (privateEntry.operandList.last.value as int);
  final dictLength = privateEntry.operandList.first.value as int;
  final privateDict = CFFDict.fromByteData(
    byteData.sublistView(dictOffset, dictLength),
  );

  /// Local subroutines for each Private DICT
  final localSubrsDataList = <CFFIndexWithData<Uint8List>>[];

  // NOTE: reading only first local subrs
  final localSubrEntry = privateDict.getEntryForOperator(op.subrs);

  if (localSubrEntry != null) {
    /// Offset from the start of the Private DICT
    final localSubrOffset = localSubrEntry.operandList.first.value as int;

    localSubrsDataList.add(
      CFFIndexWithData<Uint8List>.fromByteData(
        byteData.sublistView(dictOffset + localSubrOffset),
        true,
      ),
    );
  }

  return CFF1Table(
    entry,
    header: header,
    nameIndex: nameIndex,
    topDicts: topDicts,
    stringIndex: stringIndex,
    globalSubrsData: globalSubrsData,
    charsets: charsetEntry,
    charStringsData: charStringsData,
    fontDictList: CFFIndexWithData<CFFDict>.create([], true),
    privateDictList: <CFFDict>[privateDict],
    localSubrsDataList: localSubrsDataList,
  );
}
