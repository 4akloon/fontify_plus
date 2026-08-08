part of 'cff.dart';

/// Builds a CFF2 table for [glyphList].
CFF2Table _buildCFF2Table(List<GenericGlyph> glyphList) {
  const charStringWriter = CharStringWriter(isCFF1: false);

  final charStringRawList = glyphList.map((g) {
    final glyph = g.copy();

    for (final outline in glyph.outlines) {
      outline
        ..decompactImplicitPoints()
        ..quadToCubic();
    }

    final byteData = charStringWriter.writeCommands(
      glyph.toCharStringCommands(CharStringOptimizer(false)),
    );

    return byteData.buffer.asUint8List();
  }).toList();

  final table = CFF2Table(
    null,
    CFF2TableHeader.create(),
    CFFDict.empty(),
    CFFIndexWithData<Uint8List>.create([], false),
    CFFIndexWithData<Uint8List>.create(charStringRawList, false),
    null, // vstore omitted - no variations
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
