import 'dart:typed_data';

import '../../common/calculatable_offsets.dart';
import '../../common/codable/binary.dart';
import '../../utils/exception.dart';
import '../../utils/otf.dart';
import 'index.dart';
import 'index_element_codec.dart';

/// An INDEX together with the elements it describes.
class CFFIndexWithData<T> implements BinaryCodable, CalculatableOffsets {
  CFFIndexWithData(this.index, this.data, this.isCFF1)
    : _codec = IndexElementCodec.forType<T>();

  /// Decodes INDEX and its data from [ByteData]
  factory CFFIndexWithData.fromByteData(ByteData byteData, bool isCFF1) {
    final codec = IndexElementCodec.forType<T>();

    final index = CFFIndex.fromByteData(byteData, isCFF1);
    final indexSize = index.size;

    final dataList = <T>[];

    for (var i = 0; i < index.count; i++) {
      // -1 because first offset value is always 1
      final relativeOffset = index.offsetList[i] - 1;
      final elementLength = index.offsetList[i + 1] - index.offsetList[i];

      dataList.add(
        codec.decode(
          byteData.sublistView(indexSize + relativeOffset, elementLength),
        ),
      );
    }

    return CFFIndexWithData(index, dataList, isCFF1);
  }

  factory CFFIndexWithData.create(List<T> data, bool isCFF1) =>
      CFFIndexWithData(null, data, isCFF1);

  CFFIndex? index;
  final List<T> data;
  final bool isCFF1;

  final IndexElementCodec<T> _codec;

  @override
  int get size {
    if (data.isEmpty) {
      return CFFIndex.countSizeFor(isCFF1);
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
  void recalculateOffsets() {
    index = data.isEmpty ? CFFIndex.empty(isCFF1) : _calculateIndex();
  }

  /// NOTE: This is called three times per font write — when creating the
  /// font's ByteData, when creating the sublistView and when encoding.
  ///
  /// It must NOT be naively memoized. Element sizes are not stable across a
  /// write: the Top DICT's offset operands start as 1-byte placeholders and
  /// grow to their real width once the layout settles. A cache populated
  /// during the placeholder pass reports an element smaller than the one
  /// [encodeToBinary] actually writes, and the sub-view it sizes overflows.
  ///
  /// Any future memoization has to be invalidated by, or validated against,
  /// the live element sizes — which costs the same O(n) walk as recomputing.
  CFFIndex _calculateIndex() {
    /// Generating offset list starting with 1
    final offsetList = [1];

    for (final element in data) {
      offsetList.add(offsetList.last + _codec.lengthInBytes(element));
    }

    /// Finding minimum offSize
    CFFIndex newIndex;
    int expectedOffSize = 0;
    int actualOffSize;

    do {
      expectedOffSize++;
      newIndex = CFFIndex(
        count: data.length,
        offSize: expectedOffSize,
        offsetList: offsetList,
        isCFF1: isCFF1,
      );
      actualOffSize = (offsetList.last.bitLength / 8).ceil();
    } while (actualOffSize != expectedOffSize);

    if (actualOffSize > 4) {
      throw const TableDataFormatException('INDEX offset overflow');
    }

    return newIndex;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    final index = _guardedIndex;

    if (data.isEmpty) {
      index.encodeToBinary(byteData.sublistView(0, index.size));
      return;
    }

    final indexSize = index.size;
    index.encodeToBinary(byteData.sublistView(0, indexSize));

    var offset = indexSize;

    for (var i = 0; i < index.count; i++) {
      final element = data[i];
      final elementSize = index.offsetList[i + 1] - index.offsetList[i];

      // The offsets in [index] are laid out ahead of encoding, so they must
      // still agree with the elements being written. If they drift, the
      // sub-view below is sized wrong and the failure surfaces as an opaque
      // RangeError deep inside the element's own encoder.
      assert(
        elementSize == _codec.lengthInBytes(element),
        'INDEX element $i size mismatch: index reserves $elementSize bytes, '
        'element encodes to ${_codec.lengthInBytes(element)}. The index is '
        'stale relative to the data it describes.',
      );

      _codec.encode(byteData.sublistView(offset, elementSize), element);
      offset += elementSize;
    }
  }
}
