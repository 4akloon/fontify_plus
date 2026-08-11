part of 'cff.dart';

const _kCFF1HeaderSize = 4;

// NOTE: local subrs, encodings are omitted

class CFF1TableHeader implements BinaryCodable {
  CFF1TableHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.headerSize,
    required this.offSize,
  });

  factory CFF1TableHeader.fromByteData(ByteData byteData) => CFF1TableHeader(
    majorVersion: byteData.getUint8(0),
    minorVersion: byteData.getUint8(1),
    headerSize: byteData.getUint8(2),
    offSize: byteData.getUint8(3),
  );

  factory CFF1TableHeader.create() => CFF1TableHeader(
    majorVersion: 1,
    minorVersion: 0,
    headerSize: _kCFF1HeaderSize,
    offSize: null,
  );

  final int majorVersion;
  final int minorVersion;
  final int headerSize;

  /// Width of the largest offset in the table, filled in once the layout
  /// settles.
  int? offSize;

  @override
  int get size => _kCFF1HeaderSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint8(0, majorVersion)
      ..setUint8(1, minorVersion)
      ..setUint8(2, headerSize)
      ..setUint8(3, offSize!);
  }
}
