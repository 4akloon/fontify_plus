import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/dict.dart';
import 'package:fontify_plus/src/otf/cff/dict_operator.dart' as op;
import 'package:fontify_plus/src/otf/cff/operand.dart';
import 'package:test/test.dart';

CFFDict encodeDecode(CFFDict dict) {
  final bytes = ByteData(dict.size);
  dict.encodeToBinary(bytes);

  return CFFDict.fromByteData(bytes);
}

void main() {
  group('CFFDictEntry', () {
    test('size is its operands plus its operator', () {
      final entry = CFFDictEntry([CFFOperand.fromValue(100)], op.weight);

      expect(entry.size, 1 + op.weight.size);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final entry = CFFDictEntry([CFFOperand.fromValue(1000)], op.weight);
      final bytes = ByteData(entry.size);

      entry.encodeToBinary(bytes);
      final decoded = CFFDictEntry.fromByteData(bytes, 0);

      expect(decoded.operator, op.weight);
      expect(decoded.operandList.single.value, 1000);
    });

    test('toString truncates a long operand list', () {
      final entry = CFFDictEntry(
        List.generate(20, (i) => CFFOperand.fromValue(i)),
        op.blueValues,
      );

      expect(entry.toString().length, lessThan(30));
    });

    test('recalculatePointers grows the operand to fit the real value', () {
      // Starts as a 1-byte placeholder; recalculatePointers must grow it once
      // the real offset needs more bytes than that.
      final entry = CFFDictEntry([CFFOperand(null, 1)], op.charStrings);

      entry.recalculatePointers(0, () => 5000);

      expect(entry.operandList.single.value, 5000);
    });
  });

  group('CFFDict', () {
    test('.empty has no entries and zero size', () {
      final dict = CFFDict.empty();

      expect(dict.entryList, isEmpty);
      expect(dict.size, 0);
    });

    test('getEntryForOperator finds a matching entry', () {
      final dict = CFFDict([
        CFFDictEntry([CFFOperand.fromValue(1)], op.weight),
      ]);

      expect(dict.getEntryForOperator(op.weight), isNotNull);
    });

    test('getEntryForOperator returns null when there is no match', () {
      final dict = CFFDict([
        CFFDictEntry([CFFOperand.fromValue(1)], op.weight),
      ]);

      expect(dict.getEntryForOperator(op.notice), isNull);
    });

    test('round-trips multiple entries through binary', () {
      final dict = CFFDict([
        CFFDictEntry([CFFOperand.fromValue(1)], op.weight),
        CFFDictEntry(
            [CFFOperand.fromValue(2), CFFOperand.fromValue(3)], op.fontBBox),
      ]);

      final decoded = encodeDecode(dict);

      expect(decoded.entryList, hasLength(2));
      expect(
          decoded.getEntryForOperator(op.weight)!.operandList.single.value, 1);
      expect(
        decoded
            .getEntryForOperator(op.fontBBox)!
            .operandList
            .map((o) => o.value),
        [2, 3],
      );
    });

    test('size is the sum of every entry\'s size', () {
      final dict = CFFDict([
        CFFDictEntry([CFFOperand.fromValue(1)], op.weight),
        CFFDictEntry([CFFOperand.fromValue(2)], op.notice),
      ]);

      final entrySizes = dict.entryList.fold<int>(0, (p, e) => p + e.size);

      expect(dict.size, entrySizes);
    });
  });
}
