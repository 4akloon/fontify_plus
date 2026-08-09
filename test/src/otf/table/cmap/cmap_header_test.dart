import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/cmap_header.dart';
import 'package:fontify_plus/src/otf/table/cmap/encoding_record.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('CharacterToGlyphTableHeader', () {
    test('size accounts for every encoding record', () {
      final header = CharacterToGlyphTableHeader(
        0,
        2,
        [EncodingRecord(3, 1, 0), EncodingRecord(1, 0, 0)],
      );

      expect(header.size, 4 + 8 * 2);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final header = CharacterToGlyphTableHeader(
        0,
        1,
        [EncodingRecord(3, 1, 20)],
      );
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);
      final decoded = CharacterToGlyphTableHeader.fromByteData(
        bytes,
        TableRecordEntry('cmap', 0, 0, bytes.lengthInBytes),
      );

      expect(decoded.numTables, 1);
      expect(decoded.encodingRecords.single.platformID, 3);
      expect(decoded.encodingRecords.single.offset, 20);
    });
  });
}
