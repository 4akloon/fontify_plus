import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';

const kScriptRecordSize = 6;

/// Names a script and points at its table.
class ScriptRecord implements BinaryCodable {
  ScriptRecord(this.scriptTag, this.scriptOffset);

  factory ScriptRecord.fromByteData(ByteData byteData, int offset) =>
      ScriptRecord(byteData.getTag(offset), byteData.getUint16(offset + 4));

  final String scriptTag;

  /// Filled in while encoding, once the table layout is known.
  int? scriptOffset;

  @override
  int get size => kScriptRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, scriptTag)
      ..setUint16(4, scriptOffset!);
  }
}
