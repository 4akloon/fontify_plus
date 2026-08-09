import 'dart:typed_data';

import 'operand.dart';

/// A CFF operand as it appears inside a charstring.
///
/// Charstrings extend the DICT operand encoding with a 16.16 fixed-point form
/// introduced by `b0 == 255`, which is why this cannot simply be [CFFOperand].
class CharStringOperand extends CFFOperand {
  CharStringOperand(super.value, [super.size]);

  factory CharStringOperand.fromByteData(
    ByteData byteData,
    int offset,
    int b0,
  ) {
    if (b0 == 255) {
      return CharStringOperand(byteData.getUint32(0) / 0x10000, 5);
    }

    final operand = CFFOperand.fromByteData(byteData, offset, b0);

    return CharStringOperand(operand.value, operand.size);
  }

  @override
  int get size => value is double ? 5 : super.size;

  @override
  void encodeToBinary(ByteData byteData) {
    if (value is! double) {
      super.encodeToBinary(byteData);
      return;
    }

    byteData
      ..setUint8(0, 255)
      ..setUint32(1, (value! * 0x10000).round().toInt());
  }
}
