import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/char_string_command.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/operator.dart';
import 'package:test/test.dart';

void main() {
  group('CharStringCommand construction', () {
    test('asserts the operator is a charstring operator, not a dict one', () {
      expect(
        () => CharStringCommand(
          const CFFOperator(CFFOperatorContext.dict, 1),
          [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('hmoveto/vmoveto/rmoveto take one, one and two operands', () {
      expect(CharStringCommand.hmoveto(5).operandList, hasLength(1));
      expect(CharStringCommand.vmoveto(5).operandList, hasLength(1));
      expect(CharStringCommand.rmoveto(5, 6).operandList, hasLength(2));
    });

    test('hmoveto/vmoveto/rmoveto pick the matching operator', () {
      expect(CharStringCommand.hmoveto(5).operator, hmoveto);
      expect(CharStringCommand.vmoveto(5).operator, vmoveto);
      expect(CharStringCommand.rmoveto(5, 6).operator, rmoveto);
    });

    test('rlineto requires an even, non-empty operand count', () {
      expect(() => CharStringCommand.rlineto([1]), throwsArgumentError);
      expect(() => CharStringCommand.rlineto([]), throwsArgumentError);
      expect(CharStringCommand.rlineto([1, 2]).operandList, hasLength(2));
    });

    test('hhcurveto/vvcurveto require 4, 5, 8, 9... operands', () {
      expect(() => CharStringCommand.hhcurveto([1, 2, 3]), throwsArgumentError);
      expect(
        CharStringCommand.hhcurveto([1, 2, 3, 4]).operandList,
        hasLength(4),
      );
      expect(
        CharStringCommand.hhcurveto([1, 2, 3, 4, 5]).operandList,
        hasLength(5),
      );
      expect(
        () => CharStringCommand.hhcurveto([1, 2, 3, 4, 5, 6]),
        throwsArgumentError,
      );
      expect(
        CharStringCommand.vvcurveto([1, 2, 3, 4]).operandList,
        hasLength(4),
      );
    });

    test('rrcurveto requires a multiple of six operands', () {
      expect(() => CharStringCommand.rrcurveto([1, 2, 3]), throwsArgumentError);
      expect(
        CharStringCommand.rrcurveto([1, 2, 3, 4, 5, 6]).operandList,
        hasLength(6),
      );
    });
  });

  group('CharStringCommand.size', () {
    test('is the operator plus every operand\'s size', () {
      final command = CharStringCommand.rmoveto(5, 6);
      final operandSizes = command.operandList.fold<int>(
        0,
        (p, o) => p + o.size,
      );

      expect(command.size, command.operator.size + operandSizes);
    });
  });

  group('CharStringCommand.copy', () {
    test('produces an independent operand list', () {
      final original = CharStringCommand.rmoveto(5, 6);
      final copy = original.copy();

      copy.operandList.clear();

      expect(original.operandList, hasLength(2));
    });

    test('keeps the same operator', () {
      final original = CharStringCommand.hmoveto(5);

      expect(original.copy().operator, original.operator);
    });
  });

  group('CharStringCommand.encodeToBinary', () {
    test('writes every operand followed by the operator', () {
      final command = CharStringCommand.hmoveto(5);
      final bytes = ByteData(command.size);

      command.encodeToBinary(bytes);

      // The operator (hmoveto = 22) comes last, after the one operand byte.
      expect(bytes.getUint8(command.size - 1), 22);
    });
  });

  group('CharStringCommand.toString', () {
    test('names the operator', () {
      expect(CharStringCommand.hmoveto(5).toString(), contains('hmoveto'));
    });

    test('truncates a long operand list', () {
      final command = CharStringCommand.rrcurveto(List.filled(12, 1));

      expect(command.toString().length, lessThan(40));
    });
  });
}
