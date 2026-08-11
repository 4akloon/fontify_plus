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
import 'os2_version_fields.dart';

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
    throw const TableDataFormatException(
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
    version: version,
    version0: OS2Version0Fields(
      xAvgCharWidth: _getAverageWidth(hmtx),
      // Pinned to 400 (Regular) even for a variable font whose `wght` axis
      // carries literal stroke widths in the 1.33-2.0 range. An honest
      // usWeightClass for that range would be 2 ("Extra-thin"), but generic
      // font tooling that reads usWeightClass without instancing the font
      // would then treat the icon font as thinner than Thin, which is a worse
      // default than a class that doesn't describe this axis at all.
      usWeightClass: 400,
      usWidthClass: 5, // Normal width
      fsType: 0, // Installable embedding
      ySubscriptXSize: scriptXsize,
      ySubscriptYSize: scriptYsize,
      ySubscriptXOffset: 0,
      ySubscriptYOffset: (height * kDefaultSubscriptRelativeYoffset).round(),
      ySuperscriptXSize: scriptXsize,
      ySuperscriptYSize: scriptYsize,
      ySuperscriptXOffset: 0,
      ySuperscriptYOffset: (height * kDefaultSuperscriptRelativeYoffset)
          .round(),
      yStrikeoutSize: (height * kDefaultStrikeoutRelativeSize).round(),
      yStrikeoutPosition: (height * kDefaultStrikeoutRelativeOffset).round(),
      sFamilyClass: 0, // No Classification
      panose: kDefaultPANOSE,

      /// NOTE: Only 2 unicode ranges are used now.
      ///
      /// Should be made calculated, in case of using other ranges.
      ulUnicodeRange1: 1, // Bit 1: Basic Latin. Includes space
      // Bits 57 & 60: Non-Plane 0 and Private Use Area
      ulUnicodeRange2: (1 << 28) | (1 << 25),
      ulUnicodeRange3: 0,
      ulUnicodeRange4: 0,
      achVendID: asciiAchVendID,
      fsSelection: 0x40 | 0x80, // REGULAR and USE_TYPO_METRICS
      usFirstCharIndex: cmapFormat4subtable.startCode.first,
      usLastCharIndex: lastRealCharIndex,
      sTypoAscender: hhea.ascender,
      sTypoDescender: hhea.descender,
      sTypoLineGap: hhea.lineGap,
      usWinAscent: math.max(head.yMax, hhea.ascender),
      usWinDescent: -math.min(head.yMin, hhea.descender),
    ),
    // The code page is not functional.
    version1: !isV1
        ? null
        : OS2Version1Fields(
            ulCodePageRange1: 0,
            ulCodePageRange2: 0,
            version4: !isV4
                ? null
                : OS2Version4Fields(
                    sxHeight: 0,
                    sCapHeight: 0,
                    usDefaultChar: 0,
                    usBreakChar: kUnicodeSpaceCharCode,
                    usMaxContext: _getMaxContext(gsub),

                    /// For fonts that were not designed for multiple
                    /// optical-size variants, usLowerOpticalPointSize should
                    /// be set to 0 (zero), and usUpperOpticalPointSize should
                    /// be set to 0xFFFF.
                    version5: !isV5
                        ? null
                        : const OS2Version5Fields(
                            usLowerOpticalPointSize: 0,
                            usUpperOpticalPointSize: 0xFFFE,
                          ),
                  ),
          ),
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
