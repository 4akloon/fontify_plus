import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/sequential_map_group.dart';
import 'package:test/test.dart';

void main() {
  group('SequentialMapGroup', () {
    test('size is fixed at 12 bytes', () {
      expect(
        SequentialMapGroup(
          startCharCode: 1,
          endCharCode: 2,
          startGlyphID: 3,
        ).size,
        12,
      );
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final group = SequentialMapGroup(
        startCharCode: 0x10000,
        endCharCode: 0x10010,
        startGlyphID: 5,
      );
      final bytes = ByteData(group.size);

      group.encodeToBinary(bytes);
      final decoded = SequentialMapGroup.fromByteData(bytes, 0);

      expect(decoded.startCharCode, 0x10000);
      expect(decoded.endCharCode, 0x10010);
      expect(decoded.startGlyphID, 5);
    });
  });
}
