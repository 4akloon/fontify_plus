import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../utils/exception.dart';

/// The header of a CFF INDEX: how many elements it holds and where each ends.
class CFFIndex extends BinaryCodable {
  CFFIndex(this.count, this.offSize, this.offsetList, this.isCFF1);

  CFFIndex.empty(this.isCFF1) : count = 0, offSize = 1, offsetList = [];

  factory CFFIndex.fromByteData(ByteData byteData, bool isCFF1) {
    var offset = 0;

    final count = isCFF1 ? byteData.getUint16(0) : byteData.getUint32(0);
    offset += countSizeFor(isCFF1);

    if (count == 0) {
      return CFFIndex.empty(isCFF1);
    }

    final offSize = byteData.getUint8(offset++);
    _validateOffSize(offSize);

    final offsetList = <int>[];

    for (var i = 0; i < count + 1; i++) {
      var value = 0;

      for (var j = 0; j < offSize; j++) {
        value <<= 8;
        value += byteData.getUint8(offset++);
      }

      offsetList.add(value);
    }

    return CFFIndex(count, offSize, offsetList, isCFF1);
  }

  final int count;
  final int offSize;
  final List<int> offsetList;
  final bool isCFF1;

  bool get isEmpty => count == 0;

  int get countSize => countSizeFor(isCFF1);

  @override
  int get size => isEmpty ? countSize : countSize + 1 + _offsetListSize;

  int get _offsetListSize => (count + 1) * offSize;

  /// Width of the element count, which CFF2 widened to 32 bits.
  static int countSizeFor(bool isCFF1) => isCFF1 ? 2 : 4;

  static void _validateOffSize(int offSize) {
    if (offSize < 1 || offSize > 4) {
      throw TableDataFormatException('Wrong offSize value');
    }
  }

  @override
  void encodeToBinary(ByteData byteData) {
    _validateOffSize(offSize);

    var offset = 0;

    if (isCFF1) {
      byteData.setUint16(offset, count);
    } else {
      byteData.setUint32(offset, count);
    }

    offset += countSize;

    if (isEmpty) {
      return;
    }

    byteData.setUint8(offset++, offSize);

    for (var i = 0; i < count + 1; i++) {
      for (var j = 0; j < offSize; j++) {
        final byte = (offsetList[i] >> 8 * (offSize - j - 1)) & 0xFF;
        byteData.setUint8(offset++, byte);
      }
    }
  }
}
