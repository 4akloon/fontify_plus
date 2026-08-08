import 'dart:typed_data';

import '../../otf/table/head.dart';

/// The 32-bit sum of a table's bytes, zero-padded to a 4-byte boundary.
int calculateTableChecksum(ByteData encodedTable) {
  final length = (encodedTable.lengthInBytes / 4).floor();

  var sum = 0;

  for (var i = 0; i < length; i++) {
    sum = (sum + encodedTable.getUint32(4 * i)).toUnsigned(32);
  }

  final notAlignedBytesLength = encodedTable.lengthInBytes % 4;

  if (notAlignedBytesLength > 0) {
    final endBytes = [
      // Reading remaining bytes
      for (var i = 4 * length; i < encodedTable.lengthInBytes; i++)
        encodedTable.getUint8(i),

      // Filling with zeroes
      for (var i = 0; i < 4 - notAlignedBytesLength; i++) 0,
    ];

    var endValue = 0;

    for (final byte in endBytes) {
      endValue <<= 8;
      endValue += byte;
    }

    sum = (sum + endValue).toUnsigned(32);
  }

  return sum;
}

/// The whole font's checksum, as stored in `head`.
int calculateFontChecksum(ByteData byteData) =>
    (kChecksumMagicNumber - calculateTableChecksum(byteData)).toUnsigned(32);

/// Tables are padded to a 4-byte boundary.
int getPaddedTableSize(int actualSize) => (actualSize / 4).ceil() * 4;
