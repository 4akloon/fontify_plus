import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/cmap_header.dart';
import 'package:fontify_plus/src/otf/table/cmap/encoding_record.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('CharacterToGlyphTableHeader', () {
    test('size accounts for every encoding record', () {
      final header = CharacterToGlyphTableHeader(
        version: 0,
        numTables: 2,
        encodingRecords: [
          EncodingRecord(platformID: 3, encodingID: 1, offset: 0),
          EncodingRecord(platformID: 1, encodingID: 0, offset: 0),
        ],
      );

      expect(header.size, 4 + 8 * 2);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final header = CharacterToGlyphTableHeader(
        version: 0,
        numTables: 1,
        encodingRecords: [
          EncodingRecord(platformID: 3, encodingID: 1, offset: 20),
        ],
      );
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);
      final decoded = CharacterToGlyphTableHeader.fromByteData(
        bytes,
        TableRecordEntry(
          'cmap',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded.numTables, 1);
      expect(decoded.encodingRecords.single.platformID, 3);
      expect(decoded.encodingRecords.single.offset, 20);
    });
  });
}
