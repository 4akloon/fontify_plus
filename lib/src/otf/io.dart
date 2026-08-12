import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../utils/logger.dart';
import '../utils/otf.dart';
import 'otf.dart';
import 'reader.dart';
import 'table/offset.dart';
import 'table/table_record_entry.dart';
import 'writer.dart';

/// {@category api}
/// Reads OpenType font from a file.
OpenTypeFont readFromFile(String path) => OTFReader.fromByteData(
  ByteData.sublistView(File(path).readAsBytesSync()),
).read();

/// Created/modified from the `head` table only.
///
/// Skips every other table so regenerating a variable font does not warn
/// about unread `fvar`/`STAT` (#12). Returns null if the file is missing,
/// unreadable, or has no `head`.
({DateTime created, DateTime modified})? tryReadHeadTimestamps(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    final data = ByteData.sublistView(file.readAsBytesSync());
    final offsetTable = OffsetTable.fromByteData(data);
    var offset = kOffsetTableLength;

    for (var i = 0; i < offsetTable.numTables; i++) {
      final entry = TableRecordEntry.fromByteData(data, offset);
      offset += kTableRecordEntryLength;

      if (entry.tag != kHeadTag) {
        continue;
      }

      return (
        created: data.getDateTime(entry.offset + 20),
        modified: data.getDateTime(entry.offset + 28),
      );
    }
  } on Object {
    return null;
  }

  return null;
}

/// {@category api}
/// Writes OpenType font to a file.
void writeToFile(String path, OpenTypeFont font) {
  final file = File(path);
  final byteData = OTFWriter().write(font);
  final extension = p.extension(file.path).toLowerCase();

  if (extension != '.otf' && font.isOpenType) {
    logger.w(
      'A font that contains only CFF outline data should have an .OTF extension.',
    );
  }

  file.writeAsBytesSync(byteData.buffer.asUint8List());
}
