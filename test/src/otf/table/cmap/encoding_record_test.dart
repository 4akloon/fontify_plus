import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/encoding_record.dart';
import 'package:test/test.dart';

void main() {
  group('EncodingRecord', () {
    test('.create leaves the offset unset', () {
      expect(EncodingRecord.create(3, 1).offset, isNull);
    });

    test('size is fixed at 8 bytes', () {
      expect(EncodingRecord.create(3, 1).size, 8);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final record = EncodingRecord(platformID: 3, encodingID: 1, offset: 100);
      final bytes = ByteData(record.size);

      record.encodeToBinary(bytes);
      final decoded = EncodingRecord.fromByteData(bytes, 0);

      expect(decoded.platformID, 3);
      expect(decoded.encodingID, 1);
      expect(decoded.offset, 100);
    });

    test('encodeToBinary throws if the offset was never assigned', () {
      final record = EncodingRecord.create(3, 1);

      expect(() => record.encodeToBinary(ByteData(8)), throwsA(anything));
    });
  });
}
