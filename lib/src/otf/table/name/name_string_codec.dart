import '../../../utils/otf.dart';
import '../../../utils/ucs2.dart';
import 'name_record.dart';

/// The encoding a record's strings use.
///
/// NOTE: There are more cases than this, but it will do for now — the only
/// records this package writes are Macintosh Roman and Windows UTF-16BE.
List<int> Function(String) encoderFor(NameRecord record) =>
    record.platformID == kPlatformWindows
        ? toUCS2byteList
        : (string) => string.codeUnits;

/// The inverse of [encoderFor].
String Function(List<int>) decoderFor(NameRecord record) =>
    record.platformID == kPlatformWindows
        ? fromUCS2byteList
        : String.fromCharCodes;
