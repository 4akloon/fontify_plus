part of 'cff.dart';

/// Builds a CFF2 table for [glyphMasterList].
///
/// Each entry is one glyph's masters, default first. A single-element entry
/// is a glyph that does not vary; every entry being single-element is a
/// static CFF2 table, and produces no `vstore` at all.
CFF2Table _buildCFF2Table(List<List<GenericGlyph>> glyphMasterList) {
  final regionCount = glyphMasterList.isEmpty
      ? 0
      : glyphMasterList.first.length - 1;

  // A glyph with zero masters (`length - 1 == -1`) would otherwise pass the
  // consistency check below whenever every glyph agrees on having none, and
  // then divide by zero inside CharStringInterpreterLimits.
  if (regionCount < 0) {
    throw ArgumentError('Every glyph must have at least one master');
  }

  for (final masters in glyphMasterList) {
    if (masters.length - 1 != regionCount) {
      throw ArgumentError(
        'Every glyph must have the same number of masters: '
        '${regionCount + 1} vs ${masters.length}',
      );
    }
  }

  // Rejects regionCount > 1 before any charstring work: CharStringBlender
  // and the optimizer support more regions, but this store does not.
  final vstoreData = regionCount == 0
      ? null
      : SingleRegionVariationStore(regionCount: regionCount).build();

  final optimizer = CharStringOptimizer(false, regionCount: regionCount);
  const charStringWriter = CharStringWriter(isCFF1: false);

  final charStringRawList = glyphMasterList.map((masters) {
    final prepared = masters.map((g) {
      final glyph = g.copy();

      for (final outline in glyph.outlines) {
        outline
          ..decompactImplicitPoints()
          ..quadToCubic();
      }

      return glyph;
    }).toList();

    final byteData = charStringWriter.writeCommands(
      CharStringBlender(
        CharStringEncoder(prepared, optimizer).encode(),
      ).merge(),
    );

    return byteData.buffer.asUint8List();
  }).toList();

  final table = CFF2Table(
    null,
    header: CFF2TableHeader.create(),
    topDict: CFFDict.empty(),
    globalSubrsData: CFFIndexWithData<Uint8List>.create([], false),
    charStringsData: CFFIndexWithData<Uint8List>.create(
      charStringRawList,
      false,
    ),
    vstoreData: vstoreData,
    fontDictList: CFFIndexWithData<CFFDict>.create(
      [
        // Growable list: recalculateOffsets clears and rewrites the operands.
        // List.empty (not []) so prefer_const_constructors cannot freeze it.
        CFFDict([
          CFFDictEntry(List<CFFOperand>.empty(growable: true), op.private),
        ]),
      ],
      false,
    ),
    // A Private DICT is required, but can be empty
    privateDictList: [CFFDict([])],
    localSubrsDataList: <CFFIndexWithData<Uint8List>>[],
  );

  // The first pass fills each Font DICT's Private entry in with its real
  // operands (offset and size), growing it from the bare operator it started
  // as. fontDictList's own INDEX is recalculated earlier in that same pass,
  // against the pre-growth size, so it comes out stale. A second pass sees
  // the already-grown Font DICTs and recalculates fontDictList's INDEX
  // against their real size instead — stable from there on, so exactly two
  // calls are what a correctly-encodable table needs, not one.
  table
    ..recalculateOffsets()
    ..recalculateOffsets();

  return table;
}
