import 'dart:typed_data';

import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/otf/table/stat.dart';
import 'package:test/test.dart';

void main() {
  group('StyleAttributesTable', () {
    final range = StrokeWidthRange(1.33, 2);
    final table = StyleAttributesTable.create(range, axisNameID: 256);

    test('is a v1.2 header, one axis record and two axis values', () {
      // 20 header + 8 axis record + 2 offsets + 2 * 12 format 1 values.
      expect(table.size, 56);
    });

    test('encodes the header the way the spec lays it out', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      expect(data.getUint16(0), 1, reason: 'majorVersion');
      expect(data.getUint16(2), 2, reason: 'minorVersion');
      expect(data.getUint16(4), 8, reason: 'designAxisSize');
      expect(data.getUint16(6), 1, reason: 'designAxisCount');
      expect(data.getUint32(8), 20, reason: 'designAxesOffset');
      expect(data.getUint16(12), 2, reason: 'axisValueCount');
      // OTS drops the whole table if this is wrong, independently of
      // axisValueCount: it locates the Offset16 array by this field alone.
      expect(data.getUint32(14), 28, reason: 'offsetToAxisValueOffsets');
      // Name ID 2 ("Font Subfamily") is always present, and always
      // "Regular", in this package's `name` table — a legal, resolvable
      // fallback per the spec's own example.
      expect(data.getUint16(18), 2, reason: 'elidedFallbackNameID');
    });

    test('names the axis wght and points at the shared name record', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      expect(
        String.fromCharCodes([for (var i = 20; i < 24; i++) data.getUint8(i)]),
        'wght',
      );
      expect(data.getUint16(24), 256, reason: 'axisNameID');
      expect(data.getUint16(26), 0, reason: 'axisOrdering');
    });

    test('lays out the axis value offsets relative to their own array, '
        'not the table', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      // Both HarfBuzz and OTS read these Offset16 entries as relative to
      // offsetToAxisValueOffsets (byte 28), not to the start of the table:
      // getting the base wrong would parse cleanly but point every axis
      // value at nonsense.
      expect(data.getUint16(28), 4, reason: 'offset to the first AxisValue');
      expect(data.getUint16(30), 16, reason: 'offset to the second AxisValue');
    });

    test('writes both endpoints as format 1 axis values', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      expect(data.getUint16(32), 1, reason: 'format');
      expect(data.getUint16(34), 0, reason: 'axisIndex');
      expect(data.getUint16(36), 0, reason: 'flags');
      expect(data.getUint16(38), 256, reason: 'valueNameID');
      expect(data.getInt32(40) / 65536, closeTo(range.min, 1 / 65536));

      expect(data.getUint16(44), 1, reason: 'format');
      expect(data.getUint16(46), 0, reason: 'axisIndex');
      expect(data.getUint16(48), 0, reason: 'flags');
      expect(data.getUint16(50), 256, reason: 'valueNameID');
      expect(data.getInt32(52) / 65536, closeTo(range.max, 1 / 65536));
    });

    test('a defaultWidth gets its own named axis value', () {
      final table = StyleAttributesTable.create(
        range,
        defaultWidth: 1.5,
        axisNameID: 256,
      );
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      // 20 header + 8 axis record + 3 offsets + 3 * 12 format 1 values.
      expect(table.size, 70);
      expect(data.getUint16(12), 3, reason: 'axisValueCount');
      // Everything downstream of the offsets array shifts by the one extra
      // Offset16, so the array's own position is the one thing that must not.
      expect(data.getUint32(14), 28, reason: 'offsetToAxisValueOffsets');

      const axisValuesStart = 28 + 3 * 2;
      for (var i = 0; i < 3; i++) {
        expect(
          data.getUint16(28 + i * 2),
          axisValuesStart - 28 + i * 12,
          reason: 'offset to AxisValue $i, relative to its own array',
        );
      }

      // All three resolve to the axis's own name: the interior default has no
      // more of a name of its own than the endpoints do.
      final expected = <double>[range.min, 1.5, range.max];

      for (var i = 0; i < expected.length; i++) {
        final at = axisValuesStart + i * 12;

        expect(data.getUint16(at), 1, reason: 'format at $at');
        expect(data.getUint16(at + 2), 0, reason: 'axisIndex at $at');
        expect(data.getUint16(at + 4), 0, reason: 'flags at $at');
        expect(data.getUint16(at + 6), 256, reason: 'valueNameID at $at');
        expect(
          data.getInt32(at + 8) / 65536,
          closeTo(expected[i], 1 / 65536),
          reason: 'value at $at',
        );
      }
    });

    test('no defaultWidth still writes exactly two axis values', () {
      final data = ByteData(table.size);
      table.encodeToBinary(data);

      // Captured by running the pre-defaultWidth encoder, so this compares
      // against bytes that predate the parameter rather than against a fresh
      // reading of the same code it is meant to pin down.
      expect(data.buffer.asUint8List(), <int>[
        0x00, 0x01, 0x00, 0x02, 0x00, 0x08, 0x00, 0x01, //
        0x00, 0x00, 0x00, 0x14, 0x00, 0x02, 0x00, 0x00, //
        0x00, 0x1c, 0x00, 0x02, 0x77, 0x67, 0x68, 0x74, //
        0x01, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x10, //
        0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, //
        0x00, 0x01, 0x54, 0x7b, 0x00, 0x01, 0x00, 0x00, //
        0x00, 0x00, 0x01, 0x00, 0x00, 0x02, 0x00, 0x00, //
      ]);
    });
  });
}
