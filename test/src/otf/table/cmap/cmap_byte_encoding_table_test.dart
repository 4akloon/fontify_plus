import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/cmap_byte_encoding_table.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_format.dart';
import 'package:test/test.dart';

void main() {
  group('CmapByteEncodingTable.create', () {
    test('declares format 0', () {
      expect(CmapByteEncodingTable.create().format, kCmapFormat0);
    });

    test('maps every code to glyph 0', () {
      expect(
        CmapByteEncodingTable.create().glyphIdArray,
        everyElement(0),
      );
    });

    test('size is fixed at 262 bytes', () {
      expect(CmapByteEncodingTable.create().size, 262);
    });
  });

  group('CmapByteEncodingTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = CmapByteEncodingTable.create();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = CmapByteEncodingTable.fromByteData(bytes, 0);

      expect(decoded.format, kCmapFormat0);
      expect(decoded.glyphIdArray, hasLength(256));
    });
  });
}
