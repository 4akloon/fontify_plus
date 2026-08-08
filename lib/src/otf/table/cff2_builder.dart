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

  return CFF2Table(
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
  )..recalculateOffsets();
}
