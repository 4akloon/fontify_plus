import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cff.dart';
import 'package:test/test.dart';

/// A minimal format-1 charset table: one range starting at SID [sid],
/// covering [nLeft] further glyphs after it.
ByteData format1Bytes(int sid, int nLeft) {
  final bytes = ByteData(4);

  bytes
    ..setUint8(0, 1) // format
    ..setUint16(1, sid)
    ..setUint8(3, nLeft);

  return bytes;
}

void main() {
  group('CharsetEntry.fromByteData', () {
    test('parses a single-range format 1 table', () {
      // 3 glyphs beyond .notdef: SIDs 1, 2, 3 as one range (nLeft = 2).
      final entry = CharsetEntry.fromByteData(format1Bytes(1, 2), 4)!;

      expect(entry.format, 1);
    });

    test('round-trips through encodeToBinary', () {
      final original = CharsetEntry.fromByteData(format1Bytes(5, 1), 3)!;
      final bytes = ByteData(original.size);

      original.encodeToBinary(bytes);
      final decoded = CharsetEntry.fromByteData(bytes, 3)!;

      expect(decoded.format, original.format);
      expect(decoded.size, original.size);
    });

    test('reads consecutive ranges until every glyph is covered', () {
      // Two ranges: SIDs 1-2 (nLeft=1), then SIDs 10-10 (nLeft=0) — 3 glyphs
      // beyond .notdef, so glyphCount is 4.
      final bytes = ByteData(1 + 3 + 3);
      bytes.setUint8(0, 1);
      bytes
        ..setUint16(1, 1)
        ..setUint8(3, 1)
        ..setUint16(4, 10)
        ..setUint8(6, 0);

      final entry = CharsetEntry.fromByteData(bytes, 4)!;

      expect(entry.size, bytes.lengthInBytes);
    });

    test('returns null for an unimplemented format', () {
      final bytes = ByteData(1)..setUint8(0, 0);

      expect(CharsetEntry.fromByteData(bytes, 1), isNull);
    });
  });
}
