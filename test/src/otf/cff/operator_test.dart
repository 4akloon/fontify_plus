import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/dict_operator.dart' as op;
import 'package:fontify_plus/src/otf/cff/operator.dart';
import 'package:test/test.dart';

ByteData encode(CFFOperator operator) {
  final bytes = ByteData(operator.size);
  operator.encodeToBinary(bytes);

  return bytes;
}

void main() {
  group('CFFOperator', () {
    test('a one-byte operator has size 1', () {
      expect(op.charStrings.size, 1);
    });

    test('a two-byte (escaped) operator has size 2', () {
      expect(op.fontMatrix.size, 2);
    });

    test('equality is based on the byte value, not identity', () {
      expect(
        const CFFOperator(CFFOperatorContext.dict, 17),
        op.charStrings,
      );
    });

    test('a one-byte and a two-byte operator with the same b0 are distinct',
        () {
      // b0=12 alone (escape) differs from b0=12,b1=7 (FontMatrix): the
      // combined intValue distinguishes them.
      expect(op.escape, isNot(op.fontMatrix));
    });

    test('equality does not consider context, only the byte value', () {
      // A real limitation: a dict operator and a charstring operator that
      // happen to share a byte value compare equal, since == only looks at
      // intValue.
      const dictOp = CFFOperator(CFFOperatorContext.dict, 5);
      const charStringOp = CFFOperator(CFFOperatorContext.charString, 5);

      expect(dictOp, charStringOp);
    });

    test('equal operators have equal hash codes', () {
      expect(op.charStrings.hashCode,
          const CFFOperator(CFFOperatorContext.dict, 17).hashCode);
    });

    test('toString names a known dict operator', () {
      expect(op.charStrings.toString(), 'CharStrings');
    });

    test('toString falls back for an unknown operator', () {
      expect(
        const CFFOperator(CFFOperatorContext.dict, 99).toString(),
        '<unknown>',
      );
    });

    test('encodeToBinary writes b0 alone for a one-byte operator', () {
      final bytes = encode(op.charStrings);

      expect(bytes.getUint8(0), 17);
      expect(bytes.lengthInBytes, 1);
    });

    test('encodeToBinary writes b0 then b1 for a two-byte operator', () {
      final bytes = encode(op.fontMatrix);

      expect(bytes.getUint8(0), 12);
      expect(bytes.getUint8(1), 7);
    });
  });
}
