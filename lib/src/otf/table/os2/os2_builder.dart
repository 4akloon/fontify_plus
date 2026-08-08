import 'dart:math' as math;

import '../../../utils/exception.dart';
import '../../../utils/misc.dart';
import '../../../utils/otf.dart';
import '../cmap.dart';
import '../gsub.dart';
import '../head.dart';
import '../hhea.dart';
import '../hmtx.dart';
import 'os2_defaults.dart';
import 'os2_table.dart';
import 'os2_version.dart';

/// Builds an OS/2 table from the metrics the other tables already carry.
OS2Table buildOS2Table(
  HorizontalMetricsTable hmtx,
  HeaderTable head,
  HorizontalHeaderTable hhea,
  CharacterToGlyphTable cmap,
  GlyphSubstitutionTable gsub,
  String achVendID, {
  int version = kOS2Version5,
}) {
  final asciiAchVendID = achVendID.getAsciiPrintable();

  if (asciiAchVendID.length != 4) {
    throw TableDataFormatException(
      'Incorrect achVendID tag format in OS/2 table',
    );
  }

  final emSize = head.unitsPerEm;
  final height = hhea.ascender - hhea.descender;

  final isV1 = version >= kOS2Version1;
  final isV4 = version >= kOS2Version4;
  final isV5 = version >= kOS2Version5;

  final scriptXsize = (emSize * kDefaultSubscriptRelativeXsize).round();
  final scriptYsize = (height * kDefaultSubscriptRelativeYsize).round();

  final cmapFormat4subtable = cmap.data
      .whereType<CmapSegmentMappingToDeltaValuesTable>()
      .first;

  // Format 4's segment list always ends with the required 0xFFFF/0xFFFF
  // terminator segment (see CharacterToGlyphTable.create), so the highest
  // real character code is the second-to-last endCode entry, not the last.
  final format4EndCodes = cmapFormat4subtable.endCode;
  final lastRealCharIndex =
      format4EndCodes[math.max(0, format4EndCodes.length - 2)];

  return OS2Table(
    null,
    version,
    _getAverageWidth(hmtx),
    400, // Regular weight
    5, // Normal width
    0, // Installable embedding
    scriptXsize,
    scriptYsize,
    0, // zero X offset
    (height * kDefaultSubscriptRelativeYoffset).round(),
    scriptXsize,
    scriptYsize,
    0, // zero X offset
    (height * kDefaultSuperscriptRelativeYoffset).round(),
    (height * kDefaultStrikeoutRelativeSize).round(),
    (height * kDefaultStrikeoutRelativeOffset).round(),
    0, // No Classification
    kDefaultPANOSE,

    /// NOTE: Only 2 unicode ranges are used now.
    ///
    /// Should be made calculated, in case of using other ranges.
    1, // Bit 1: Basic Latin. Includes space
    (1 << 28) | (1 << 25), // Bits 57 & 60: Non-Plane 0 and Private Use Area
    0,
    0,
    asciiAchVendID,
    0x40 | 0x80, // REGULAR and USE_TYPO_METRICS
    cmapFormat4subtable.startCode.first,
    lastRealCharIndex,
    hhea.ascender,
    hhea.descender,
    hhea.lineGap,
    math.max(head.yMax, hhea.ascender),
    -math.min(head.yMin, hhea.descender),
    !isV1 ? null : 0, // The code page is not functional
    !isV1 ? null : 0,
    !isV4 ? null : 0,
    !isV4 ? null : 0,
    !isV4 ? null : 0,
    !isV4 ? null : kUnicodeSpaceCharCode,
    !isV4 ? null : _getMaxContext(gsub),

    /// For fonts that were not designed for multiple optical-size variants,
    /// usLowerOpticalPointSize should be set to 0 (zero),
    /// and usUpperOpticalPointSize should be set to 0xFFFF.
    !isV5 ? null : 0,
    !isV5 ? null : 0xFFFE,
  );
}

int _getAverageWidth(HorizontalMetricsTable hmtx) {
  if (hmtx.hMetrics.isEmpty) {
    return 0;
  }

  final nonEmptyWidths = hmtx.hMetrics.where((m) => m.advanceWidth > 0);
  final widthSum = nonEmptyWidths.fold<int>(0, (p, m) => p + m.advanceWidth);

  return (widthSum / nonEmptyWidths.length).round();
}

// NOTE: GPOS is also used in calculation, not supported yet
int _getMaxContext(GlyphSubstitutionTable gsub) {
  var maxContext = 0;

  for (final lookup in gsub.lookupListTable.lookupTables) {
    for (final subtable in lookup.subtables) {
      maxContext = math.max(maxContext, subtable.maxContext);
    }
  }

  return maxContext;
}
