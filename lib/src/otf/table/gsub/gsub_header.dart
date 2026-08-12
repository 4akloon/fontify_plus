import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../../debugger.dart';
import '../table_record_entry.dart';

/// The GSUB header: a version and offsets to the three lists it holds.
class GlyphSubstitutionTableHeader implements BinaryCodable {
  GlyphSubstitutionTableHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.scriptListOffset,
    required this.featureListOffset,
    required this.lookupListOffset,
    required this.featureVariationsOffset,
  });

  factory GlyphSubstitutionTableHeader.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final major = byteData.getUint16(entry.offset);
    final minor = byteData.getUint16(entry.offset + 2);

    final isV10 = Revision(major, minor) == const Revision(1, 0);

    if (!isV10) {
      debuggerOTF.debugUnsupportedTableVersion(
        kGSUBTag,
        Revision(major, minor).int32value,
      );
    }

    return GlyphSubstitutionTableHeader(
      majorVersion: major,
      minorVersion: minor,
      scriptListOffset: byteData.getUint16(entry.offset + 4),
      featureListOffset: byteData.getUint16(entry.offset + 6),
      lookupListOffset: byteData.getUint16(entry.offset + 8),
      featureVariationsOffset: isV10
          ? null
          : byteData.getUint32(entry.offset + 10),
    );
  }

  factory GlyphSubstitutionTableHeader.create() => GlyphSubstitutionTableHeader(
    majorVersion: 1,
    minorVersion: 0,
    scriptListOffset: null,
    featureListOffset: null,
    lookupListOffset: null,
    featureVariationsOffset: null,
  );

  final int majorVersion;
  final int minorVersion;

  /// Filled in while encoding, once the list layout is known.
  int? scriptListOffset;
  int? featureListOffset;
  int? lookupListOffset;
  int? featureVariationsOffset;

  bool get isV10 => majorVersion == 1 && minorVersion == 0;

  @override
  int get size => isV10 ? 10 : 14;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, majorVersion)
      ..setUint16(2, minorVersion)
      ..setUint16(4, scriptListOffset!)
      ..setUint16(6, featureListOffset!)
      ..setUint16(8, lookupListOffset!);

    if (!isV10) {
      byteData.setUint32(10, featureVariationsOffset!);
    }
  }
}
