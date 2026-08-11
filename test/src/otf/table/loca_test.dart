import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/glyf.dart';
import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:fontify_plus/src/otf/table/glyph/header.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple.dart';
import 'package:fontify_plus/src/otf/table/loca.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

SimpleGlyph _triangle() {
  final points = [
    const math.Point<num>(0, 0),
    const math.Point<num>(10, 0),
    const math.Point<num>(10, 10),
  ];

  return SimpleGlyph(
    header: GlyphHeader(
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

GlyphDataTable _glyf() =>
    GlyphDataTable(null, [SimpleGlyph.empty(), _triangle()]);

void main() {
  group('IndexToLocationTable.create', () {
    test('offsets start at 0 and end at the padded total size', () {
      final glyf = _glyf();
      final table = IndexToLocationTable.create(0, glyf);

      expect(table.glyphOffsets.first, 0);
      expect(table.glyphOffsets.last, glyf.size);
    });

    test('has one more offset than there are glyphs', () {
      final glyf = _glyf();
      final table = IndexToLocationTable.create(0, glyf);

      expect(table.glyphOffsets, hasLength(glyf.glyphList.length + 1));
    });
  });

  group('IndexToLocationTable round trip', () {
    test('round-trips the short (format 0) encoding', () {
      final glyf = _glyf();
      final table = IndexToLocationTable.create(0, glyf);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = IndexToLocationTable.fromByteData(
        bytes,
        TableRecordEntry(
          'loca',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
        0,
        glyf.glyphList.length,
      );

      expect(decoded.glyphOffsets, table.glyphOffsets);
    });

    test('round-trips the long (format 1) encoding', () {
      final glyf = _glyf();
      final table = IndexToLocationTable.create(1, glyf);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = IndexToLocationTable.fromByteData(
        bytes,
        TableRecordEntry(
          'loca',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
        1,
        glyf.glyphList.length,
      );

      expect(decoded.glyphOffsets, table.glyphOffsets);
    });
  });
}
