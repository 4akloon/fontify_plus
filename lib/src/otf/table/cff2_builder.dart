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

  for (final masters in glyphMasterList) {
    if (masters.length - 1 != regionCount) {
      throw ArgumentError(
        'Every glyph must have the same number of masters: '
        '${regionCount + 1} vs ${masters.length}',
      );
    }
  }

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
      blendCommands(
        prepared.first.toCharStringCommandsForMasters(prepared, optimizer),
      ),
    );

    return byteData.buffer.asUint8List();
  }).toList();

  final table = CFF2Table(
    null,
    CFF2TableHeader.create(),
    CFFDict.empty(),
    CFFIndexWithData<Uint8List>.create([], false),
    CFFIndexWithData<Uint8List>.create(charStringRawList, false),
    regionCount == 0 ? null : singleRegionVariationStore(),
    CFFIndexWithData<CFFDict>.create(
      [
        CFFDict([CFFDictEntry([], op.private)]),
      ],
      false,
    ),
    // A Private DICT is required, but can be empty
    [CFFDict([])],
    <CFFIndexWithData<Uint8List>>[],
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
