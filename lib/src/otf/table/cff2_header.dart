part of 'cff.dart';

const _kCFF2HeaderSize = 5;

class CFF2TableHeader implements BinaryCodable {
  CFF2TableHeader(
    this.majorVersion,
    this.minorVersion,
    this.headerSize,
    this.topDictLength,
  );

  factory CFF2TableHeader.fromByteData(ByteData byteData) => CFF2TableHeader(
        byteData.getUint8(0),
        byteData.getUint8(1),
        byteData.getUint8(2),
        byteData.getUint16(3),
      );

  factory CFF2TableHeader.create() =>
      CFF2TableHeader(_kMajorVersion2, 0, _kCFF2HeaderSize, null);

  final int majorVersion;
  final int minorVersion;
  final int headerSize;

  /// CFF2 stores the Top DICT's length here rather than in an INDEX, so it is
  /// only known once the DICT's own offsets have settled.
  int? topDictLength;

  @override
  int get size => _kCFF2HeaderSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint8(0, majorVersion)
      ..setUint8(1, minorVersion)
      ..setUint8(2, headerSize)
      ..setUint16(3, topDictLength!);
  }
}
