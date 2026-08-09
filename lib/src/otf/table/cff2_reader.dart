part of 'cff.dart';

/// Reads a CFF2 table out of an existing font.
CFF2Table _readCFF2Table(ByteData byteData, TableRecordEntry entry) {
  /// 3 entries with fixed location
  var fixedOffset = entry.offset;

  final header = CFF2TableHeader.fromByteData(
    byteData.sublistView(fixedOffset, _kCFF2HeaderSize),
  );
  fixedOffset += _kCFF2HeaderSize;

  final topDict = CFFDict.fromByteData(
    byteData.sublistView(fixedOffset, header.topDictLength!),
  );
  fixedOffset += header.topDictLength!;

  final globalSubrsData = CFFIndexWithData<Uint8List>.fromByteData(
    byteData.sublistView(fixedOffset),
    false,
  );
  fixedOffset += globalSubrsData.index!.size;

  /// CharStrings INDEX
  final charStringsIndexOffset =
      topDict.getEntryForOperator(op.charStrings)!.operandList.first.value
          as int;

  final charStringsData = CFFIndexWithData<Uint8List>.fromByteData(
    byteData.sublistView(entry.offset + charStringsIndexOffset),
    false,
  );

  /// VariationStore
  final vstoreEntry = topDict.getEntryForOperator(op.vstore);

  final vstoreData = vstoreEntry == null
      ? null
      : VariationStoreData.fromByteData(
          byteData.sublistView(
            entry.offset + (vstoreEntry.operandList.first.value as int),
          ),
        );

  // NOTE: not decoding FDSelect - using single Font DICT only

  /// Font DICT INDEX
  final fdArrayOffset =
      topDict.getEntryForOperator(op.fdArray)!.operandList.first.value as int;

  final fontDictList = CFFIndexWithData<CFFDict>.fromByteData(
    byteData.sublistView(entry.offset + fdArrayOffset),
    false,
  );

  /// Private DICT list
  final privateDictList = <CFFDict>[];

  /// Local subroutines for each Private DICT
  final localSubrsDataList = <CFFIndexWithData<Uint8List>>[];

  for (var i = 0; i < fontDictList.index!.count; i++) {
    final privateEntry = fontDictList.data[i].getEntryForOperator(op.private)!;
    final dictOffset =
        entry.offset + (privateEntry.operandList.last.value as int);
    final dictLength = privateEntry.operandList.first.value as int;

    final dict = CFFDict.fromByteData(
      byteData.sublistView(dictOffset, dictLength),
    );
    privateDictList.add(dict);

    final localSubrEntry = dict.getEntryForOperator(op.subrs);

    if (localSubrEntry != null) {
      /// Offset from the start of the Private DICT
      final localSubrOffset = localSubrEntry.operandList.first.value as int;

      localSubrsDataList.add(
        CFFIndexWithData<Uint8List>.fromByteData(
          byteData.sublistView(dictOffset + localSubrOffset),
          false,
        ),
      );
    }
  }

  return CFF2Table(
    entry,
    header,
    topDict,
    globalSubrsData,
    charStringsData,
    vstoreData,
    fontDictList,
    privateDictList,
    localSubrsDataList,
  );
}
