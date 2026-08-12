import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/glyf.dart';
import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:fontify_plus/src/otf/table/glyph/header.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple.dart';
import 'package:fontify_plus/src/otf/table/maxp.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

SimpleGlyph _triangle() {
  final points = [
    const math.Point<num>(0, 0),
    const math.Point<num>(10, 0),
    const math.Point<num>(10, 10),
  ];

  return SimpleGlyph(
    header: const GlyphHeader(
      numberOfContours: 1,
      xMin: 0,
      yMin: 0,
      xMax: 10,
      yMax: 10,
    ),
    endPtsOfContours: [2],
    instructions: [],
    flags: [
      for (var i = 0; i < points.length; i++)
        SimpleGlyphFlag.createForPoint(x: 0, y: 0, isOnCurve: true),
    ],
    pointList: points,
  );
}

void main() {
  group('MaximumProfileTable.create', () {
    test(
      'produces a version-0.5 (OpenType/CFF) table when there is no glyf',
      () {
        final table = MaximumProfileTable.create(3, null);

        expect(table.numGlyphs, 3);
        expect(table.maxPoints, isNull);
        expect(table.size, 6);
      },
    );

    test('produces a version-1.0 (TrueType) table with the glyf extremes', () {
      final glyf = GlyphDataTable(null, [SimpleGlyph.empty(), _triangle()]);
      final table = MaximumProfileTable.create(2, glyf);

      expect(table.maxPoints, glyf.maxPoints);
      expect(table.maxContours, glyf.maxContours);
      expect(table.size, 32);
    });
  });

  group('MaximumProfileTable round trip', () {
    test(
      'round-trips a version-0.5 table through encodeToBinary and fromByteData',
      () {
        final table = MaximumProfileTable.create(5, null);
        final bytes = ByteData(table.size);

        table.encodeToBinary(bytes);

        final decoded = MaximumProfileTable.fromByteData(
          bytes,
          TableRecordEntry(
            'maxp',
            checkSum: 0,
            offset: 0,
            length: bytes.lengthInBytes,
          ),
        );

        expect(decoded!.numGlyphs, 5);
        expect(decoded.maxPoints, isNull);
      },
    );

    test(
      'round-trips a version-1.0 table through encodeToBinary and fromByteData',
      () {
        final glyf = GlyphDataTable(null, [SimpleGlyph.empty(), _triangle()]);
        final table = MaximumProfileTable.create(2, glyf);
        final bytes = ByteData(table.size);

        table.encodeToBinary(bytes);

        final decoded = MaximumProfileTable.fromByteData(
          bytes,
          TableRecordEntry(
            'maxp',
            checkSum: 0,
            offset: 0,
            length: bytes.lengthInBytes,
          ),
        );

        expect(decoded!.numGlyphs, 2);
        expect(decoded.maxPoints, glyf.maxPoints);
        expect(decoded.maxContours, glyf.maxContours);
      },
    );

    test('returns null for an unsupported version', () {
      final bytes = ByteData(6)..setInt32(0, 0x00020000);

      final decoded = MaximumProfileTable.fromByteData(
        bytes,
        TableRecordEntry(
          'maxp',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded, isNull);
    });
  });
}
