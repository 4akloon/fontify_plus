import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../coverage.dart';
import 'substitution_subtable.dart';

/// Lookup type 4: replaces a glyph sequence with a single ligature glyph.
///
/// Written empty. An icon font has no ligatures, but a GSUB table has to
/// contain at least one well-formed lookup to be valid.
class LigatureSubstitutionSubtable extends SubstitutionSubtable {
  const LigatureSubstitutionSubtable(
    this.substFormat,
    this.coverageOffset,
    this.ligatureSetCount,
    this.ligatureSetOffsets,
    this.coverageTable,
  );

  factory LigatureSubstitutionSubtable.fromByteData(
    ByteData byteData,
    int offset,
  ) {
    final coverageOffset = byteData.getUint16(offset + 2);
    final ligatureSetCount = byteData.getUint16(offset + 4);

    return LigatureSubstitutionSubtable(
      byteData.getUint16(offset),
      coverageOffset,
      ligatureSetCount,
      List.generate(
        ligatureSetCount,
        (i) => byteData.getUint16(offset + 6 + 2 * i),
      ),
      CoverageTable.fromByteData(byteData, offset + coverageOffset),
    );
  }

  final int substFormat;
  final int coverageOffset;
  final int ligatureSetCount;
  final List<int> ligatureSetOffsets;

  final CoverageTable? coverageTable;

  @override
  int get size => 6 + 2 * ligatureSetCount + (coverageTable?.size ?? 0);

  /// NOTE: Should be calculated considering 'componentCount' of ligatures.
  ///
  /// Not supported yet - generating 0 ligature sets by default.
  @override
  int get maxContext => 0;

  @override
  void encodeToBinary(ByteData byteData) {
    final coverageOffset = 6 + 2 * ligatureSetCount;

    byteData
      ..setUint16(0, substFormat)
      ..setUint16(2, coverageOffset)
      ..setUint16(4, ligatureSetCount);

    for (var i = 0; i < ligatureSetCount; i++) {
      byteData.setInt16(6 + 2 * i, ligatureSetOffsets[i]);
    }

    coverageTable?.encodeToBinary(
      byteData.sublistView(coverageOffset, coverageTable!.size),
    );
  }
}
