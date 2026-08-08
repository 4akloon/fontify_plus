import 'dart:typed_data';

import '../../utils/otf.dart';
import 'dict.dart';

/// How one kind of INDEX element is measured, decoded and encoded.
///
/// An INDEX stores opaque byte ranges; what those bytes mean depends on which
/// INDEX it is. Keeping that in one object per element type means supporting a
/// new type is a new class, rather than another case in each of three parallel
/// switches.
abstract class IndexElementCodec<T> {
  const IndexElementCodec();

  /// The codec for [T], which must be a supported element type.
  static IndexElementCodec<T> forType<T>() {
    final codec = switch (T) {
      const (Uint8List) => const RawBytesCodec(),
      const (CFFDict) => const DictCodec(),
      _ => throw UnsupportedError('No INDEX codec for type $T'),
    };

    return codec as IndexElementCodec<T>;
  }

  T decode(ByteData byteData);

  void encode(ByteData byteData, T element);

  int lengthInBytes(T element);
}

/// Elements kept as their raw bytes, such as charstrings.
class RawBytesCodec extends IndexElementCodec<Uint8List> {
  const RawBytesCodec();

  @override
  Uint8List decode(ByteData byteData) => Uint8List.fromList(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

  @override
  void encode(ByteData byteData, Uint8List element) =>
      byteData.setByteList(0, element);

  @override
  int lengthInBytes(Uint8List element) => element.lengthInBytes;
}

/// Elements that are themselves DICTs, such as the Font DICT INDEX.
class DictCodec extends IndexElementCodec<CFFDict> {
  const DictCodec();

  @override
  CFFDict decode(ByteData byteData) => CFFDict.fromByteData(byteData);

  @override
  void encode(ByteData byteData, CFFDict element) =>
      element.encodeToBinary(byteData);

  @override
  int lengthInBytes(CFFDict element) => element.size;
}
