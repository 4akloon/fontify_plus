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
  });
}
