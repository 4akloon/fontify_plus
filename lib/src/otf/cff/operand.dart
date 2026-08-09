import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../utils/exception.dart';
import 'real_number_codec.dart';

/// A number in a CFF DICT or charstring.
///
/// CFF has several integer encodings of different widths and one textual real
/// number encoding; which one applies is decided by the leading byte, and by
/// the value's magnitude when writing.
class CFFOperand extends BinaryCodable {
  CFFOperand(this.value, this._size);

  CFFOperand.fromValue(this.value);

  factory CFFOperand.fromByteData(ByteData byteData, int offset, int b0) {
    switch (b0) {
      /// -32768 to +32767
      case 28:
        return CFFOperand(byteData.getInt16(offset), 3);

      /// -(2^31) to +(2^31 - 1)
      case 29:
        return CFFOperand(byteData.getInt32(offset), 5);

      case 30:
        final (value, size) = decodeRealNumber(byteData, offset);
        return CFFOperand(value, size);
    }

    /// -107 to +107
    if (b0 >= 32 && b0 <= 246) {
      return CFFOperand(b0 - 139, 1);
    }

    /// +108 to +1131
    if (b0 >= 247 && b0 <= 250) {
      return CFFOperand((b0 - 247) * 256 + byteData.getUint8(offset) + 108, 2);
    }

    /// -1131 to -108
    if (b0 >= 251 && b0 <= 254) {
      return CFFOperand(-(b0 - 251) * 256 - byteData.getUint8(offset) - 108, 2);
    }

    throw TableDataFormatException(
      'Unknown operand type in CFF table (offset $offset)',
    );
  }

  /// Either real or integer number
  final num? value;

  int? _size;

  @override
  int get size => _size ??= _calculateSize();

  num get _guardedValue {
    if (value == null) {
      throw StateError('Value must not be null');
    }

    return value!;
  }

  int _calculateSize() {
    final value = _guardedValue;

    if (value is double) {
      return realNumberSize(value);
    }

    if (value >= -107 && value <= 107) {
      return 1;
    }

    if ((value >= 108 && value <= 1131) || (value >= -1131 && value <= -108)) {
      return 2;
    }

    return value >= -32768 && value <= 32767 ? 3 : 5;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    final value = _guardedValue;

    if (value is double) {
      encodeRealNumber(byteData, value);
      return;
    }

    _encodeInt(byteData, value as int);
  }

  void _encodeInt(ByteData byteData, int value) {
    if (value >= -107 && value <= 107) {
      byteData.setUint8(0, value + 139);
      return;
    }

    if (value >= 108 && value <= 1131) {
      final biased = value - 108;

      byteData
        ..setUint8(0, (biased >> 8) + 247)
        ..setUint8(1, biased & 0xFF);
      return;
    }

    if (value >= -1131 && value <= -108) {
      final biased = -value - 108;

      byteData
        ..setUint8(0, (biased >> 8) + 251)
        ..setUint8(1, biased & 0xFF);
      return;
    }

    if (value >= -32768 && value <= 32767) {
      byteData
        ..setUint8(0, 28)
        ..setInt16(1, value);
      return;
    }

    byteData
      ..setUint8(0, 29)
      ..setInt32(1, value);
  }

  @override
  String toString() => value.toString();
}
