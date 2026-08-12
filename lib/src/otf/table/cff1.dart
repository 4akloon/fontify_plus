part of 'cff.dart';

/// The `CFF ` table: version 1 Compact Font Format outlines.
///
/// Reading, building and offset layout each live in their own part beside this
/// one, so this class stays the table's structure and its encoder.
class CFF1Table extends CFFTable implements CalculatableOffsets {
  CFF1Table(
    super.entry, {
    required this.header,
    required this.nameIndex,
    required this.topDicts,
    required this.stringIndex,
    required this.globalSubrsData,
    required this.charsets,
    required this.charStringsData,
    required this.fontDictList,
    required this.privateDictList,
    required this.localSubrsDataList,
  }) : super.fromTableRecordEntry();

  factory CFF1Table.fromByteData(ByteData byteData, TableRecordEntry entry) =>
      _readCFF1Table(byteData, entry);

  factory CFF1Table.create(
    List<GenericGlyph> glyphList,
    HeaderTable head,
    HorizontalMetricsTable hmtx,
    NamingTable name,
  ) => _buildCFF1Table(glyphList, head, hmtx, name);

  final CFF1TableHeader header;
  final CFFIndexWithData<Uint8List> nameIndex;
  final CFFIndexWithData<CFFDict> topDicts;
  final CFFIndexWithData<Uint8List> stringIndex;
  final CFFIndexWithData<Uint8List> globalSubrsData;
  final CharsetEntry charsets;
  final CFFIndexWithData<Uint8List> charStringsData;
  final CFFIndexWithData<CFFDict> fontDictList;
  final List<CFFDict> privateDictList;
  final List<CFFIndexWithData<Uint8List>> localSubrsDataList;

  CFFDict get topDict => topDicts.data.first;

  @override
  int get size =>
      _fixedSize + charsets.size + charStringsData.size + _privateDictListSize;

  int get _privateDictListSize => privateDictList.fold(0, (p, d) => p + d.size);

  /// Everything before the first offset-addressed section.
  int get _fixedSize =>
      header.size +
      nameIndex.size +
      topDicts.size +
      stringIndex.size +
      globalSubrsData.size;

  @override
  void recalculateOffsets() {
    _recalculateCFF1TopDictOffsets(this);

    // Recalculating INDEXex
    nameIndex.recalculateOffsets();
    topDicts.recalculateOffsets();
    stringIndex.recalculateOffsets();
    globalSubrsData.recalculateOffsets();
    charStringsData.recalculateOffsets();
    fontDictList.recalculateOffsets();

    for (final e in localSubrsDataList) {
      e.recalculateOffsets();
    }

    // Last data offset
    final lastDataEntry = topDict.getEntryForOperator(op.private)!;
    final lastDataOffset = lastDataEntry.operandList.last.value as int;
    header.offSize = (lastDataOffset.bitLength / 8).ceil();
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    void write(BinaryCodable section) {
      final sectionSize = section.size;

      section.encodeToBinary(byteData.sublistView(offset, sectionSize));
      offset += sectionSize;
    }

    write(header);
    write(nameIndex);
    write(topDicts);
    write(stringIndex);
    write(globalSubrsData);
    write(charsets);
    write(charStringsData);

    // NOTE: Using only first private dict
    write(privateDictList.first);
  }
}
