part of 'cff.dart';

/// The `CFF2` table: version 2 Compact Font Format outlines.
///
/// Reading, building and offset layout each live in their own part beside this
/// one, so this class stays the table's structure and its encoder.
class CFF2Table extends CFFTable implements CalculatableOffsets {
  CFF2Table(
    super.entry,
    this.header,
    this.topDict,
    this.globalSubrsData,
    this.charStringsData,
    this.vstoreData,
    this.fontDictList,
    this.privateDictList,
    this.localSubrsDataList,
  ) : super.fromTableRecordEntry();

  factory CFF2Table.fromByteData(ByteData byteData, TableRecordEntry entry) =>
      _readCFF2Table(byteData, entry);

  factory CFF2Table.create(List<List<GenericGlyph>> glyphMasterList) =>
      _buildCFF2Table(glyphMasterList);

  final CFF2TableHeader header;
  final CFFDict topDict;
  final CFFIndexWithData<Uint8List> globalSubrsData;
  final CFFIndexWithData<Uint8List> charStringsData;
  final VariationStoreData? vstoreData;
  final CFFIndexWithData<CFFDict> fontDictList;
  final List<CFFDict> privateDictList;
  final List<CFFIndexWithData<Uint8List>> localSubrsDataList;

  @override
  int get size =>
      header.size +
      topDict.size +
      globalSubrsData.size +
      (vstoreData?.size ?? 0) +
      charStringsData.size +
      fontDictList.size +
      _privateDictListSize +
      _localSubrsListSize;

  int get _privateDictListSize => privateDictList.fold(0, (p, d) => p + d.size);

  int get _localSubrsListSize =>
      localSubrsDataList.fold(0, (p, d) => p + d.size);

  /// NOTE: a single call leaves fontDictList's own INDEX stale. It measures
  /// each Font DICT's size before [_recalculateCFF2FontDictOffsets] (below)
  /// fills that DICT's Private entry in with its real operands, so the INDEX
  /// is sized against the bare, pre-growth DICT. [CFF2Table.create] calls
  /// this twice for exactly that reason — the second pass sees the grown
  /// DICTs and is stable from there. Call it at least twice before encoding
  /// a table built any other way.
  @override
  void recalculateOffsets() {
    _recalculateCFF2TopDictOffsets(this);

    header.topDictLength = topDict.size;

    globalSubrsData.recalculateOffsets();
    fontDictList.recalculateOffsets();
    charStringsData.recalculateOffsets();

    // Recalculating font DICTs private offsets and SUBRS entries offsets
    _recalculateCFF2FontDictOffsets(this);

    // Recalculating local subrs
    for (final localSubrs in localSubrsDataList) {
      localSubrs.recalculateOffsets();
    }
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
    write(topDict);
    write(globalSubrsData);

    if (vstoreData != null) {
      write(vstoreData!);
    }

    write(charStringsData);
    write(fontDictList);

    for (var i = 0; i < fontDictList.data.length; i++) {
      write(privateDictList[i]);
    }

    localSubrsDataList.forEach(write);
  }
}
