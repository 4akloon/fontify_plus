import 'dart:typed_data';

import 'cmap_data.dart';
import 'cmap_format.dart';

const _kByteEncodingTableSize = 256 + 6;

/// Format 0: a flat 256-entry map.
///
/// Written empty. It exists because some Macintosh consumers still expect a
/// (1, 0) subtable to be present, not because anything reads it.
class CmapByteEncodingTable extends CmapData {
  const CmapByteEncodingTable(
    super.format, {
    required this.length,
    required this.language,
    required this.glyphIdArray,
  });

  factory CmapByteEncodingTable.fromByteData(ByteData byteData, int offset) =>
      CmapByteEncodingTable(
        byteData.getUint16(offset),
        length: byteData.getUint16(offset + 2),
        language: byteData.getUint16(offset + 4),
        glyphIdArray: List.generate(
          256,
          (i) => byteData.getUint8(offset + 6 + i),
        ),
      );

  factory CmapByteEncodingTable.create() => CmapByteEncodingTable(
    kCmapFormat0,
    length: _kByteEncodingTableSize,
    language: 0,
    glyphIdArray: List.filled(256, 0), // Not using standard mac glyphs
  );

  final int length;
  final int language;
  final List<int> glyphIdArray;

  @override
  int get size => _kByteEncodingTableSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, length)
      ..setUint16(4, language);

    for (var i = 0; i < glyphIdArray.length; i++) {
      byteData.setUint8(6 + i, glyphIdArray[i]);
    }
  }
}
