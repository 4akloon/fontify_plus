import '../../../utils/enum_class.dart';

/// The name strings a font may carry, by their OpenType name ID.
enum NameID {
  /// 0:  Copyright notice.
  copyright,

  /// 1:  Font Family name.
  fontFamily,

  /// 2:  Font Subfamily name.
  fontSubfamily,

  /// 3:  Unique font identifier
  uniqueID,

  /// 4:  Full font name
  fullFontName,

  /// 5:  Version string.
  version,

  /// 6:  PostScript name.
  postScriptName,

  /// 8:  Manufacturer Name.
  manufacturer,

  /// 10: Description
  description,

  /// 11: URL of font vendor
  urlVendor,

  /// 256: Display name for the stroke width variation axis.
  ///
  /// The first ID in the user-defined range. `fvar` axis names must live there
  /// rather than reuse a standard ID.
  strokeWidthAxis,
}

/// The wire value of each [NameID].
///
/// Not the enum's own index: the IDs skip 7 and 9, which this package does not
/// write.
const kNameIDmap = EnumClass<NameID, int>({
  NameID.copyright: 0,
  NameID.fontFamily: 1,
  NameID.fontSubfamily: 2,
  NameID.uniqueID: 3,
  NameID.fullFontName: 4,
  NameID.version: 5,
  NameID.postScriptName: 6,
  NameID.manufacturer: 8,
  NameID.description: 10,
  NameID.urlVendor: 11,
  NameID.strokeWidthAxis: 256,
});
