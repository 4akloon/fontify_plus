import 'dart:typed_data';

import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/otf/table/fvar.dart';
import 'package:test/test.dart';

void main() {
  group('FontVariationsTable', () {
    final table = FontVariationsTable.create(
      StrokeWidthRange(1.33, 2),
      axisNameID: 256,
    );

    test('is one axis with no instances', () {
      // 16 byte header + one 20 byte axis record.
      expect(table.size, 36);
    });

    test('encodes the header the way the spec lays it out', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      expect(data.getUint16(0), 1, reason: 'majorVersion');
      expect(data.getUint16(2), 0, reason: 'minorVersion');
      expect(data.getUint16(4), 16, reason: 'axesArrayOffset');
      expect(data.getUint16(6), 2, reason: 'reserved');
      expect(data.getUint16(8), 1, reason: 'axisCount');
      expect(data.getUint16(10), 20, reason: 'axisSize');
      expect(data.getUint16(12), 0, reason: 'instanceCount');
      // The spec's formula for instanceSize applies unconditionally, not only
      // when instanceCount > 0: HarfBuzz's fvar sanitizer checks it that way
      // and drops the whole table if it's short, even with no instances.
      expect(data.getUint16(14), 8, reason: 'instanceSize');
    });

    test('writes the axis as wght in 16.16 fixed point', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      expect(
        String.fromCharCodes([
          for (var i = 16; i < 20; i++) data.getUint8(i),
        ]),
        'wght',
      );
      expect(data.getInt32(20) / 65536, closeTo(1.33, 1 / 65536));
      expect(data.getInt32(24) / 65536, closeTo(2, 1 / 65536));
      expect(data.getInt32(28) / 65536, closeTo(2, 1 / 65536));
      expect(data.getUint16(34), 256, reason: 'axisNameID');
    });

    test('defaults to the axis maximum', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      // defaultValue == maxValue: one variation region instead of two, which
      // halves the delta payload.
      expect(data.getInt32(24), data.getInt32(28));
    });

    test('a defaultWidth becomes the default instance, not max', () {
      final table = FontVariationsTable.create(
        StrokeWidthRange(1.33, 2),
        defaultWidth: 1.5,
        axisNameID: 256,
      );
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      // minValue, defaultValue, maxValue are the three Fixed values that
      // follow the four-byte axis tag at the start of the axis record.
      expect(data.getInt32(20) / 65536, closeTo(1.33, 1 / 65536));
      expect(data.getInt32(24) / 65536, closeTo(1.5, 1 / 65536));
      expect(data.getInt32(28) / 65536, closeTo(2, 1 / 65536));
      // A default strictly inside the range is exactly the case the two-region
      // variation store exists for, so the endpoints must stay where they are.
      expect(table.size, 36, reason: 'the axis record does not grow');
    });

    test('no defaultWidth still gives the default at max, unchanged', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      // Captured by running the pre-defaultWidth encoder, so this compares
      // against bytes that predate the parameter rather than against a fresh
      // reading of the same code it is meant to pin down.
      expect(data.buffer.asUint8List(), <int>[
        0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x02, //
        0x00, 0x01, 0x00, 0x14, 0x00, 0x00, 0x00, 0x08, //
        0x77, 0x67, 0x68, 0x74, 0x00, 0x01, 0x54, 0x7b, //
        0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, //
        0x00, 0x00, 0x01, 0x00, //
      ]);
    });
  });
}
