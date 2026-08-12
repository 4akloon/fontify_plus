import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../utils/otf.dart';
import 'char_string_operand.dart';
import 'char_string_operator.dart';
import 'operator.dart';

/// One charstring operator together with the operands it consumes.
class CharStringCommand implements BinaryCodable {
  // Not const: the assert reads [operator].context, which is not a constant
  // expression; operandList is also mutated in place by the optimizer.
  CharStringCommand(this.operator, this.operandList)
    : assert(
        operator.context == CFFOperatorContext.charString,
        "Operator's context must be CharString",
      );

  factory CharStringCommand.hmoveto(int dx) =>
      CharStringCommand(hmoveto, _operands([dx]));

  factory CharStringCommand.vmoveto(int dy) =>
      CharStringCommand(vmoveto, _operands([dy]));

  factory CharStringCommand.rmoveto(int dx, int dy) =>
      CharStringCommand(rmoveto, _operands([dx, dy]));

  factory CharStringCommand.hlineto(int dx) =>
      CharStringCommand(hlineto, _operands([dx]));

  factory CharStringCommand.vlineto(int dy) =>
      CharStringCommand(vlineto, _operands([dy]));

  factory CharStringCommand.rlineto(List<int> dlist) {
    if (dlist.length.isOdd || dlist.length < 2) {
      throw ArgumentError('|- {dxa dya}+ rlineto (5) |-');
    }

    return CharStringCommand(rlineto, _operands(dlist));
  }

  factory CharStringCommand.hhcurveto(List<int> dlist) {
    if (dlist.length < 4 || (dlist.length % 4 != 0 && dlist.length % 4 != 1)) {
      throw ArgumentError('|- dy1? {dxa dxb dyb dxc}+ hhcurveto (27) |-');
    }

    return CharStringCommand(hhcurveto, _operands(dlist));
  }

  factory CharStringCommand.vvcurveto(List<int> dlist) {
    if (dlist.length < 4 || (dlist.length % 4 != 0 && dlist.length % 4 != 1)) {
      throw ArgumentError('|- dx1? {dya dxb dyb dyc}+ vvcurveto (26) |-');
    }

    return CharStringCommand(vvcurveto, _operands(dlist));
  }

  factory CharStringCommand.rrcurveto(List<int> dlist) {
    if (dlist.length < 6 || dlist.length % 6 != 0) {
      throw ArgumentError('|- {dxa dya dxb dyb dxc dyc}+ rrcurveto (8) |-');
    }

    return CharStringCommand(rrcurveto, _operands(dlist));
  }

  final CFFOperator operator;
  final List<CharStringOperand> operandList;

  @override
  int get size =>
      operator.size + operandList.fold<int>(0, (p, e) => p + e.size);

  static List<CharStringOperand> _operands(List<num> values) => [
    for (final value in values) CharStringOperand(value),
  ];

  CharStringCommand copy() => CharStringCommand(operator, [...operandList]);

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    for (final operand in operandList) {
      final operandSize = operand.size;
      operand.encodeToBinary(byteData.sublistView(offset, operandSize));
      offset += operandSize;
    }

    operator.encodeToBinary(byteData.sublistView(offset, operator.size));
  }

  @override
  String toString() {
    var operands = operandList.map((e) => e.toString()).join(', ');

    if (operands.length > 10) {
      operands = '${operands.substring(0, 10)}...';
    }

    return '$operator [$operands]';
  }
}
