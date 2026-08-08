import 'dart:typed_data';

import '../../common/calculatable_offsets.dart';
import '../../common/codable/binary.dart';
import '../../utils/exception.dart';
import '../../utils/otf.dart';
import 'dict.dart';

class CFFIndex extends BinaryCodable {
  CFFIndex(this.count, this.offSize, this.offsetList, this.isCFF1);

  CFFIndex.empty(this.isCFF1)
      : count = 0,
        offSize = 1,
        offsetList = [];

  factory CFFIndex.fromByteData(ByteData byteData, bool isCFF1) {
    var offset = 0;

    final count = isCFF1 ? byteData.getUint16(0) : byteData.getUint32(0);
    offset += _getCountSize(isCFF1);

    if (count == 0) {
      return CFFIndex.empty(isCFF1);
    }

    final offSize = byteData.getUint8(offset++);
    _validateOffSize(offSize);

    final offsetList = <int>[];

    for (var i = 0; i < count + 1; i++) {
      var value = 0;

      for (var i = 0; i < offSize; i++) {
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

    offset += _getCountSize(isCFF1);

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

  int get _offsetListSize => (count + 1) * offSize;

  @override
  int get size {
    var sizeSum = countSize;

    if (isEmpty) {
      return sizeSum;
    }

    return sizeSum += 1 + _offsetListSize;
  }

  int get countSize => _getCountSize(isCFF1);

  static int _getCountSize(bool isCFF1) => isCFF1 ? 2 : 4;
}

class CFFIndexWithData<T> implements BinaryCodable, CalculatableOffsets {
  CFFIndexWithData(this.index, this.data, this.isCFF1);

  /// Decodes INDEX and its data from [ByteData]
  factory CFFIndexWithData.fromByteData(ByteData byteData, bool isCFF1) {
    final decoder = _getDecoderForType(T);

    final index = CFFIndex.fromByteData(byteData, isCFF1);
    final indexSize = index.size;

    final dataList = <T>[];

    for (var i = 0; i < index.count; i++) {
      final relativeOffset =
          index.offsetList[i] - 1; // -1 because first offset value is always 1
      final elementLength = index.offsetList[i + 1] - index.offsetList[i];

      final fontDictByteData =
          byteData.sublistView(indexSize + relativeOffset, elementLength);

      dataList.add(decoder(fontDictByteData) as T);
    }

    return CFFIndexWithData(index, dataList, isCFF1);
  }

  factory CFFIndexWithData.create(List<T> data, bool isCFF1) =>
      CFFIndexWithData(null, data, isCFF1);

  CFFIndex? index;
  final List<T> data;
  final bool isCFF1;

  static Object Function(ByteData) _getDecoderForType(Type type) {
    switch (type) {
      case const (Uint8List):
        return (bd) => Uint8List.fromList(
              bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes),
            );
      case const (CFFDict):
        return (bd) => CFFDict.fromByteData(bd);
      default:
    }

    throw UnsupportedError('No decoder for type $type');
  }

  void Function(ByteData, T) _getEncoder() {
    switch (T) {
      case const (Uint8List):
        return (bd, list) => bd.setByteList(0, list as Uint8List);
      case const (CFFDict):
        return (bd, dict) => (dict as CFFDict).encodeToBinary(bd);
      default:
    }

    throw UnsupportedError('No encoder for type $T');
  }

  int Function(T) _getByteLengthCallback() {
    switch (T) {
      case const (Uint8List):
        return (list) => (list as Uint8List).lengthInBytes;
      case const (CFFDict):
        return (dict) => (dict as CFFDict).size;
      default:
    }

    throw UnsupportedError('No length callback for type $T');
  }

  @override
  void recalculateOffsets() {
    if (data.isEmpty) {
      index = CFFIndex.empty(isCFF1);
      return;
    }

    index = _calculateIndex();
  }

  /// NOTE: This is called three times per font write — when creating the
  /// font's ByteData, when creating the sublistView and when encoding.
  ///
  /// It must NOT be naively memoized. Element sizes are not stable across a
  /// write: [_recalculateTopDictOffsets] first resets the Top DICT's offset
  /// operands to 1-byte placeholders, then grows them to their real width once
  /// the layout settles. A cache populated during the placeholder pass reports
  /// an element smaller than the one [encodeToBinary] actually writes, and the
  /// sub-view it sizes overflows.
  ///
  /// Any future memoization has to be invalidated by, or validated against, the
  /// live element sizes — which costs the same O(n) walk as recomputing.
  CFFIndex _calculateIndex() {
    final lengthCallback = _getByteLengthCallback();

    final dataSizeList = data.map(lengthCallback).toList();

    /// Generating offset list starting with 1
    final offsetList = [1];

    for (final elementSize in dataSizeList) {
      offsetList.add(offsetList.last + elementSize);
    }

    /// Finding minimum offSize
    CFFIndex newIndex;
    int expectedOffSize = 0;
    int actualOffSize;

    do {
      expectedOffSize++;
      newIndex = CFFIndex(data.length, expectedOffSize, offsetList, isCFF1);
      actualOffSize = (offsetList.last.bitLength / 8).ceil();
    } while (actualOffSize != expectedOffSize);

    if (actualOffSize > 4) {
      throw TableDataFormatException('INDEX offset overflow');
    }

    return newIndex;
  }

  @override
  int get size {
    if (data.isEmpty) {
      return CFFIndex._getCountSize(isCFF1);
    }

    final newIndex = _calculateIndex();

    return newIndex.size + newIndex.offsetList.last - 1;
  }

  CFFIndex get _guardedIndex {
    if (index == null) {
      throw StateError('index must not be null');
    }

    return index!;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    final index = _guardedIndex;

    if (data.isEmpty) {
      index.encodeToBinary(byteData.sublistView(0, index.size));
      return;
    }

    var offset = 0;

    final indexSize = index.size;

    index.encodeToBinary(byteData.sublistView(offset, indexSize));
    offset += indexSize;

    final encoder = _getEncoder();
    final lengthCallback = _getByteLengthCallback();

    for (var i = 0; i < index.count; i++) {
      final element = data[i];
      final elementSize = index.offsetList[i + 1] - index.offsetList[i];

      // The offsets in [index] are laid out ahead of encoding, so they must
      // still agree with the elements being written. If they drift, the
      // sub-view below is sized wrong and the failure surfaces as an opaque
      // RangeError deep inside the element's own encoder.
      assert(
        elementSize == lengthCallback(element),
        'INDEX element $i size mismatch: index reserves $elementSize bytes, '
        'element encodes to ${lengthCallback(element)}. The index is stale '
        'relative to the data it describes.',
      );

      encoder(byteData.sublistView(offset, elementSize), element);
      offset += elementSize;
    }
  }
}
