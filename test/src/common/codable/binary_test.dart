import 'dart:typed_data';

import 'package:fontify_plus/src/common/codable/binary.dart';
import 'package:test/test.dart';

class _Codable implements BinaryCodable {
  @override
  int get size => 1;

  @override
  void encodeToBinary(ByteData byteData) => byteData.setUint8(0, 42);
}

void main() {
  group('BinaryCodable', () {
    test('implements both BinaryEncodable and BinaryDecodable', () {
      final codable = _Codable();

      expect(codable, isA<BinaryEncodable>());
      expect(codable, isA<BinaryDecodable>());
    });

    test('a concrete implementation reports its size and encodes', () {
      final codable = _Codable();
      final bytes = ByteData(codable.size);

      codable.encodeToBinary(bytes);

      expect(bytes.getUint8(0), 42);
    });
  });
}
