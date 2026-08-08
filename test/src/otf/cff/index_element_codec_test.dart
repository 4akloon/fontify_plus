import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/dict.dart';
import 'package:fontify_plus/src/otf/cff/dict_operator.dart' as op;
import 'package:fontify_plus/src/otf/cff/index_element_codec.dart';
import 'package:fontify_plus/src/otf/cff/operand.dart';
import 'package:test/test.dart';

void main() {
  group('IndexElementCodec.forType', () {
    test('resolves Uint8List to RawBytesCodec', () {
      expect(IndexElementCodec.forType<Uint8List>(), isA<RawBytesCodec>());
    });

    test('resolves CFFDict to DictCodec', () {
      expect(IndexElementCodec.forType<CFFDict>(), isA<DictCodec>());
    });

    test('throws for an unsupported type', () {
      expect(IndexElementCodec.forType<int>, throwsUnsupportedError);
    });
  });

  group('RawBytesCodec', () {
    const codec = RawBytesCodec();

    test('lengthInBytes matches the list length', () {
      expect(codec.lengthInBytes(Uint8List.fromList([1, 2, 3])), 3);
    });

    test('round-trips bytes through encode and decode', () {
      final original = Uint8List.fromList([10, 20, 30]);
      final bytes = ByteData(3);

      codec.encode(bytes, original);
      final decoded = codec.decode(bytes);

      expect(decoded, original);
    });

    test('decode copies the bytes rather than aliasing the view', () {
      final bytes = ByteData(3)
        ..setUint8(0, 1)
        ..setUint8(1, 2)
        ..setUint8(2, 3);

      final decoded = codec.decode(bytes);
      bytes.setUint8(0, 99);

      expect(decoded[0], 1);
    });
  });

  group('DictCodec', () {
    const codec = DictCodec();

    test('lengthInBytes matches the dict\'s own size', () {
      final dict = CFFDict([
        CFFDictEntry([CFFOperand.fromValue(1)], op.weight),
      ]);

      expect(codec.lengthInBytes(dict), dict.size);
    });

    test('round-trips a dict through encode and decode', () {
      final dict = CFFDict([
        CFFDictEntry([CFFOperand.fromValue(42)], op.weight),
      ]);
      final bytes = ByteData(dict.size);

      codec.encode(bytes, dict);
      final decoded = codec.decode(bytes);

      expect(
          decoded.getEntryForOperator(op.weight)!.operandList.single.value, 42);
    });
  });
}
