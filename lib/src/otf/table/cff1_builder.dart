part of 'cff.dart';

/// Builds a CFF1 table for [glyphList].
CFF1Table _buildCFF1Table(
  List<GenericGlyph> glyphList,
  HeaderTable head,
  HorizontalMetricsTable hmtx,
  NamingTable name,
) {
  final strings = _CFF1StringIndexBuilder();

  // excluding .notdef
  for (final glyph in glyphList.sublist(1)) {
    final standardSid = _kCharcodeToSidMap[glyph.metadata.charCode];

    if (standardSid != null) {
      strings.reuseStandard(standardSid);
    } else {
      strings.put(glyph.metadata.name!);
    }
  }

  // The glyph names claim the low SIDs; everything the Top DICT adds below
  // comes after them and is not part of the charset.
  final glyphSidList = [...strings.sidList];

  final fontName = name.getStringByNameId(NameID.fullFontName)!;

  final topDictStringEntryMap = {
    op.version: name.getStringByNameId(NameID.version),
    op.notice:
        '${name.getStringByNameId(NameID.copyright)} '
        '${name.getStringByNameId(NameID.urlVendor)}',
    op.fullName: fontName,
    op.weight: name.getStringByNameId(NameID.fontSubfamily),
  };

  final topDicts = CFFIndexWithData.create(
    [
      CFFDict([
        for (final e in topDictStringEntryMap.entries)
          if (e.value != null)
            CFFDictEntry([CFFOperand.fromValue(strings.put(e.value!))], e.key),
        CFFDictEntry(
          [
            CFFOperand.fromValue(head.xMin),
            CFFOperand.fromValue(head.yMin),
            CFFOperand.fromValue(head.xMax),
            CFFOperand.fromValue(head.yMax),
          ],
          op.fontBBox,
        ),
      ]),
    ],
    true,
  );

  return CFF1Table(
    null,
    header: CFF1TableHeader.create(),
    nameIndex: CFFIndexWithData<Uint8List>.create(
      [Uint8List.fromList(fontName.getPostScriptString().codeUnits)],
      true,
    ),
    topDicts: topDicts,
    stringIndex: CFFIndexWithData<Uint8List>.create(strings.data, true),
    globalSubrsData: CFFIndexWithData<Uint8List>.create([], true),
    charsets: _CharsetEntryFormat1.create(glyphSidList),
    charStringsData: CFFIndexWithData<Uint8List>.create(
      _encodeCharStrings(glyphList, hmtx),
      true,
    ),
    fontDictList: CFFIndexWithData<CFFDict>.create([CFFDict.empty()], true),
    privateDictList: [
      CFFDict([
        CFFDictEntry([CFFOperand.fromValue(0)], op.nominalWidthX),
      ]),
    ],
    localSubrsDataList: <CFFIndexWithData<Uint8List>>[],
  )..recalculateOffsets();
}

/// Encodes one charstring per glyph, in glyph order.
List<Uint8List> _encodeCharStrings(
  List<GenericGlyph> glyphList,
  HorizontalMetricsTable hmtx,
) {
  final result = <Uint8List>[];

  for (var i = 0; i < glyphList.length; i++) {
    final glyph = glyphList[i].copy();

    for (final outline in glyph.outlines) {
      outline
        ..decompactImplicitPoints()
        ..quadToCubic();
    }

    final byteData = const CharStringWriter(isCFF1: true).writeCommands(
      [
        ...glyph.toCharStringCommands(CharStringOptimizer(true)),
        CharStringCommand(cs_op.endchar, []),
      ],
      glyphWidth: hmtx.hMetrics[i].advanceWidth,
    );

    result.add(byteData.buffer.asUint8List());
  }

  return result;
}

/// Collects the strings a CFF1 table needs and hands out their SIDs.
///
/// SIDs below [_cffStandardStringCount] name one of the predefined strings;
/// anything else has to be added to the String INDEX and numbered after them.
class _CFF1StringIndexBuilder {
  final data = <Uint8List>[];
  final sidList = <int>[];

  var _nextSid = _cffStandardStringCount;

  /// Adds [string] to the index and returns its SID.
  int put(String string) {
    data.add(Uint8List.fromList(string.codeUnits));
    sidList.add(_nextSid);

    return _nextSid++;
  }

  /// Records a SID that names a predefined string, storing nothing.
  void reuseStandard(int sid) => sidList.add(sid);
}
