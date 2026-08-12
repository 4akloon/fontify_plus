import 'dart:typed_data';

import '../../../common/codable/binary.dart';

const _kGlyphHeaderSize = 10;

class GlyphHeader implements BinaryCodable {
  const GlyphHeader({
    required this.numberOfContours,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  factory GlyphHeader.fromByteData(ByteData byteData, int offset) {
    return GlyphHeader(
      numberOfContours: byteData.getInt16(offset),
      xMin: byteData.getInt16(offset + 2),
      yMin: byteData.getInt16(offset + 4),
      xMax: byteData.getInt16(offset + 6),
      yMax: byteData.getInt16(offset + 8),
    );
  }

  final int numberOfContours;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;

  bool get isComposite => numberOfContours.isNegative;

  @override
  int get size => _kGlyphHeaderSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setInt16(0, numberOfContours)
      ..setInt16(2, xMin)
      ..setInt16(4, yMin)
      ..setInt16(6, xMax)
      ..setInt16(8, yMax);
  }
}
