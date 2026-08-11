/// The `OS/2` fields every table has, whatever its version.
///
/// A version-0 table is exactly this group and nothing else. Field order here
/// matches the order the format lays them out in, but nothing reads it: the
/// encoder writes each field at its own fixed offset.
class OS2Version0Fields {
  /// Creates the version-0 field group.
  ///
  /// Every parameter is named because almost all of them are `int`s standing
  /// next to same-typed neighbours — `ySubscriptXSize`/`ySubscriptYSize`, the
  /// four `ulUnicodeRange`s, the `sTypo*`/`usWin*` runs — where a
  /// transposition would compile and only show up as a rendering difference.
  const OS2Version0Fields({
    required this.xAvgCharWidth,
    required this.usWeightClass,
    required this.usWidthClass,
    required this.fsType,
    required this.ySubscriptXSize,
    required this.ySubscriptYSize,
    required this.ySubscriptXOffset,
    required this.ySubscriptYOffset,
    required this.ySuperscriptXSize,
    required this.ySuperscriptYSize,
    required this.ySuperscriptXOffset,
    required this.ySuperscriptYOffset,
    required this.yStrikeoutSize,
    required this.yStrikeoutPosition,
    required this.sFamilyClass,
    required this.panose,
    required this.ulUnicodeRange1,
    required this.ulUnicodeRange2,
    required this.ulUnicodeRange3,
    required this.ulUnicodeRange4,
    required this.achVendID,
    required this.fsSelection,
    required this.usFirstCharIndex,
    required this.usLastCharIndex,
    required this.sTypoAscender,
    required this.sTypoDescender,
    required this.sTypoLineGap,
    required this.usWinAscent,
    required this.usWinDescent,
  });

  /// Average advance width of the font's non-empty glyphs.
  final int xAvgCharWidth;

  /// Weight class, 1-1000, where 400 is Regular.
  final int usWeightClass;

  /// Width class, 1-9, where 5 is Normal.
  final int usWidthClass;

  /// Embedding and licensing permissions.
  final int fsType;

  /// Horizontal size of subscript glyphs.
  final int ySubscriptXSize;

  /// Vertical size of subscript glyphs.
  final int ySubscriptYSize;

  /// Horizontal offset of subscript glyphs.
  final int ySubscriptXOffset;

  /// Vertical offset of subscript glyphs.
  final int ySubscriptYOffset;

  /// Horizontal size of superscript glyphs.
  final int ySuperscriptXSize;

  /// Vertical size of superscript glyphs.
  final int ySuperscriptYSize;

  /// Horizontal offset of superscript glyphs.
  final int ySuperscriptXOffset;

  /// Vertical offset of superscript glyphs.
  final int ySuperscriptYOffset;

  /// Thickness of the strikeout stroke.
  final int yStrikeoutSize;

  /// Position of the strikeout stroke relative to the baseline.
  final int yStrikeoutPosition;

  /// IBM font family class and subclass.
  final int sFamilyClass;

  /// The ten-byte PANOSE classification.
  final List<int> panose;

  /// Unicode Character Range bits 0-31.
  final int ulUnicodeRange1;

  /// Unicode Character Range bits 32-63.
  final int ulUnicodeRange2;

  /// Unicode Character Range bits 64-95.
  final int ulUnicodeRange3;

  /// Unicode Character Range bits 96-127.
  final int ulUnicodeRange4;

  /// Four-character font vendor identifier.
  final String achVendID;

  /// Font selection flags (italic, bold, regular, and so on).
  final int fsSelection;

  /// Lowest character code the font maps.
  final int usFirstCharIndex;

  /// Highest character code the font maps.
  final int usLastCharIndex;

  /// Typographic ascender.
  final int sTypoAscender;

  /// Typographic descender.
  final int sTypoDescender;

  /// Typographic line gap.
  final int sTypoLineGap;

  /// Ascent Windows clips glyphs to.
  final int usWinAscent;

  /// Descent Windows clips glyphs to.
  final int usWinDescent;
}

/// The code page coverage `OS/2` version 1 added, and whatever follows it.
///
/// The groups nest because OpenType's versions are cumulative: a table that
/// has [OS2Version4Fields] necessarily has the version-1 fields too. Owning
/// the next group rather than sitting beside it is what makes "`sxHeight` set
/// while `ulCodePageRange1` is absent" unrepresentable — there is nowhere to
/// put the version-4 group except inside this one.
class OS2Version1Fields {
  /// Creates the version-1 field group.
  ///
  /// [version4] null means the table ends after the code page ranges.
  const OS2Version1Fields({
    required this.ulCodePageRange1,
    required this.ulCodePageRange2,
    this.version4,
  });

  /// Code Page Character Range bits 0-31.
  final int ulCodePageRange1;

  /// Code Page Character Range bits 32-63.
  final int ulCodePageRange2;

  /// The group version 4 adds, or null when the table ends at version 1.
  final OS2Version4Fields? version4;
}

/// The metrics `OS/2` version 4 added, and whatever follows them.
///
/// OpenType attaches these to version 2; this package's version map
/// (`kOS2VersionDataSize`) has no entry below version 4, so a version-2 or
/// version-3 table is read without them.
class OS2Version4Fields {
  /// Creates the version-4 field group.
  ///
  /// [version5] null means the table ends after these metrics.
  const OS2Version4Fields({
    required this.sxHeight,
    required this.sCapHeight,
    required this.usDefaultChar,
    required this.usBreakChar,
    required this.usMaxContext,
    this.version5,
  });

  /// Height of a lowercase `x`.
  final int sxHeight;

  /// Height of an uppercase `H`.
  final int sCapHeight;

  /// Character displayed for codes the font does not map.
  final int usDefaultChar;

  /// Character used as a word break.
  final int usBreakChar;

  /// Longest glyph sequence any layout feature matches.
  final int usMaxContext;

  /// The group version 5 adds, or null when the table ends at version 4.
  final OS2Version5Fields? version5;
}

/// The optical size range `OS/2` version 5 added.
class OS2Version5Fields {
  /// Creates the version-5 field group.
  const OS2Version5Fields({
    required this.usLowerOpticalPointSize,
    required this.usUpperOpticalPointSize,
  });

  /// Lowest point size this font is intended for, in twentieths of a point.
  final int usLowerOpticalPointSize;

  /// Highest point size this font is intended for, in twentieths of a point.
  final int usUpperOpticalPointSize;
}
