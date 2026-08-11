import 'dart:typed_data';

import '../abstract.dart';
import '../cmap.dart';
import '../gsub.dart';
import '../head.dart';
import '../hhea.dart';
import '../hmtx.dart';
import '../table_record_entry.dart';
import 'os2_builder.dart';
import 'os2_encoder.dart';
import 'os2_reader.dart';
import 'os2_version.dart';
import 'os2_version_fields.dart';

/// The `OS/2` table: metrics and classification Windows and layout engines
/// read.
///
/// Fields live in the group of the version that introduced them, and every
/// group past version 0 is nullable because a lower-version table simply ends
/// early. A null group means the table stops there: `sxHeight` present while
/// `ulCodePageRange1` is absent is unrepresentable in the format, so it is
/// unrepresentable here too.
class OS2Table extends FontTable {
  /// Creates an `OS/2` table from its per-version field groups.
  ///
  /// [version] is stored rather than derived from the groups because it
  /// carries information they cannot: OpenType versions 2 and 3 add no fields
  /// this package models, so a version-3 table is read with the version-1
  /// group and nothing above it, and deriving would rewrite its version to 1.
  /// The assertion below is what keeps the two consistent in the direction
  /// that matters — a version that promises more than the groups hold.
  OS2Table(
    super.entry, {
    required this.version,
    required this.version0,
    this.version1,
    this.version4,
    this.version5,
  }) : assert(
         (version >= kOS2Version1) == (version1 != null) &&
             (version >= kOS2Version4) == (version4 != null) &&
             (version >= kOS2Version5) == (version5 != null),
         'OS/2 version $version does not match the groups given: a table '
         'carries exactly the groups introduced at or below its version',
       ),
       super.fromTableRecordEntry();

  factory OS2Table.fromByteData(ByteData byteData, TableRecordEntry entry) =>
      readOS2Table(byteData, entry);

  factory OS2Table.create(
    HorizontalMetricsTable hmtx,
    HeaderTable head,
    HorizontalHeaderTable hhea,
    CharacterToGlyphTable cmap,
    GlyphSubstitutionTable gsub,
    String achVendID, {
    int version = kOS2Version5,
  }) => buildOS2Table(
    hmtx,
    head,
    hhea,
    cmap,
    gsub,
    achVendID,
    version: version,
  );

  /// The version this table declares, as written to the font.
  ///
  /// Not always recoverable from [version1]/[version4]/[version5]: see the
  /// constructor.
  final int version;

  /// The fields every `OS/2` table carries.
  final OS2Version0Fields version0;

  /// The code page coverage, or null below version 1.
  final OS2Version1Fields? version1;

  /// The extra metrics, or null below version 4.
  final OS2Version4Fields? version4;

  /// The optical size range, or null below version 5.
  final OS2Version5Fields? version5;

  @override
  int get size {
    // Counted from the groups present rather than from `version`, so it
    // always describes exactly what the encoder is about to write.
    var size = 0;

    for (final e in kOS2VersionDataSize.entries) {
      if (!_carries(e.key)) {
        break;
      }

      size += e.value;
    }

    return size;
  }

  /// Whether this table carries the group the given version introduced.
  ///
  /// Version 0's group is never absent, and no other version in
  /// `kOS2VersionDataSize` introduces one.
  bool _carries(int version) => switch (version) {
    kOS2Version1 => version1 != null,
    kOS2Version4 => version4 != null,
    kOS2Version5 => version5 != null,
    _ => true,
  };

  @override
  void encodeToBinary(ByteData byteData) => encodeOS2Table(this, byteData);
}
