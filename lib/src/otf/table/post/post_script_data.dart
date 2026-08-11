import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../../debugger.dart';
import 'post_script_table_header.dart';
import 'post_script_version_20.dart';

const kPostVersion20 = 0x00020000;
const kPostVersion30 = 0x00030000;

/// The variable part of the `post` table, whichever version declares it.
abstract class PostScriptData implements BinaryCodable {
  const PostScriptData();

  static PostScriptData? fromByteData(
    ByteData byteData,
    int offset,
    PostScriptTableHeader header,
  ) {
    final version = header.version.int32value;

    switch (version) {
      case kPostVersion20:
        return PostScriptVersion20.fromByteData(byteData, offset);
      case kPostVersion30:
        return const PostScriptVersion30();
    }

    debuggerOTF.debugUnsupportedTableVersion(kPostTag, version);

    return null;
  }

  Revision get version;
}

/// Version 3.0: no glyph names at all.
///
/// The default here — glyph names cost bytes and nothing in an icon font
/// consumes them.
class PostScriptVersion30 extends PostScriptData {
  const PostScriptVersion30();

  @override
  int get size => 0;

  @override
  Revision get version => const Revision.fromInt32(kPostVersion30);

  @override
  void encodeToBinary(_) {}
}
