import 'dart:typed_data';

import '../../../utils/exception.dart';
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
/// Fields live in the group of the version that introduced them, and the
/// groups nest — [OS2Version1Fields] owns the version-4 group, which owns the
/// version-5 group — because OpenType's versions are cumulative. A null group
/// means the table ends there, and since there is nowhere to put a higher
/// group except inside a lower one, `sxHeight` present while
/// `ulCodePageRange1` is absent cannot be written down at all.
///
/// One thing the nesting cannot enforce is [version] agreeing with the groups,
/// because [version] is stored rather than derived (see the constructor). That
/// is checked at construction and throws.
class OS2Table extends FontTable {
  /// Creates an `OS/2` table from its per-version field groups.
  ///
  /// [version] is stored rather than derived from the groups because it
  /// carries information they cannot: OpenType versions 2 and 3 add no fields
  /// this package models, so a version-3 table is read with the version-1
  /// group and nothing above it, and deriving would rewrite its version to 1.
  ///
  /// Throws [TableDataFormatException] when [version] and the groups disagree
  /// in either direction — a version promising fields the groups do not hold,
  /// or a group above what the version declares. It throws rather than
  /// asserts because the failure it replaces was a real one: the encoder used
  /// to force-unwrap each optional field, so a version-5 table missing its
  /// version-5 group crashed on the spot. Silently emitting a 96-byte table
  /// whose version field says 5 — which every consumer would read two `uint16`
  /// values past the end of — is a far worse outcome than a throw, and an
  /// `assert` would do exactly that in any build with asserts off.
  OS2Table(
    super.entry, {
    required this.version,
    required this.version0,
    this.version1,
  }) : super.fromTableRecordEntry() {
    _checkVersionMatchesGroups();
  }

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

  /// The code page coverage and everything nested under it, or null below
  /// version 1.
  final OS2Version1Fields? version1;

  /// The extra metrics, or null below version 4.
  ///
  /// Shorthand for `version1?.version4`. The nesting is where the structure
  /// lives; this only saves callers a link in the chain.
  OS2Version4Fields? get version4 => version1?.version4;

  /// The optical size range, or null below version 5.
  ///
  /// Shorthand for `version1?.version4?.version5`.
  OS2Version5Fields? get version5 => version4?.version5;

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
  /// `kOS2VersionDataSize` introduces one. A table read from a corrupt font
  /// whose version is negative — `version` is read as an `int16`, so 0xFFFF
  /// arrives as -1 — therefore still measures 78 bytes and encodes as a
  /// version-0-shaped table carrying that version verbatim, rather than
  /// measuring 0 and failing mid-encode with an `IndexError`.
  bool _carries(int version) => switch (version) {
    kOS2Version1 => version1 != null,
    kOS2Version4 => version4 != null,
    kOS2Version5 => version5 != null,
    _ => true,
  };

  /// Rejects a [version] that does not match the groups actually present.
  ///
  /// The nesting already rules out a gap in the middle; this covers the one
  /// axis it cannot, in both directions.
  void _checkVersionMatchesGroups() {
    _checkGroup(kOS2Version1, version1 != null);
    _checkGroup(kOS2Version4, version4 != null);
    _checkGroup(kOS2Version5, version5 != null);
  }

  void _checkGroup(int groupVersion, bool isPresent) {
    if ((version >= groupVersion) == isPresent) {
      return;
    }

    throw TableDataFormatException(
      'OS/2 version $version does not match the field groups given: the '
      'version-$groupVersion group must be present exactly when the version '
      'is $groupVersion or higher, and it is ${isPresent ? '' : 'not '}here',
    );
  }

  @override
  void encodeToBinary(ByteData byteData) => encodeOS2Table(this, byteData);
}
