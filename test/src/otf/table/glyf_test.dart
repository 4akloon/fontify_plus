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
    GlyphHeader(1, 0, 0, 10, 10),
    [2],
    [],
    [
      for (var i = 0; i < points.length; i++)
        SimpleGlyphFlag.createForPoint(0, 0, true),
    ],
    points,
  );
}

void main() {
  group('GlyphDataTable extremes', () {
    test('maxPoints/maxContours/maxSizeOfInstructions are 0 for no glyphs', () {
      final table = GlyphDataTable(null, []);

      expect(table.maxPoints, 0);
      expect(table.maxContours, 0);
      expect(table.maxSizeOfInstructions, 0);
    });

    test('maxPoints/maxContours read the largest glyph', () {
      final table = GlyphDataTable(null, [SimpleGlyph.empty(), _triangle()]);

      expect(table.maxPoints, 3);
      expect(table.maxContours, 1);
    });
  });

  group('GlyphDataTable.size', () {
    test('pads every non-empty glyph up to a 4-byte boundary', () {
      final glyph = _triangle();
      final table = GlyphDataTable(null, [glyph]);

      expect(table.size % 4, 0);
      expect(table.size, greaterThanOrEqualTo(glyph.size));
    });

    test('empty glyphs contribute nothing to the total size', () {
      final table = GlyphDataTable(null, [SimpleGlyph.empty()]);

      expect(table.size, 0);
    });
  });

  group('GlyphDataTable round trip', () {
    test('round-trips through encodeToBinary, loca, and fromByteData', () {
      final table = GlyphDataTable(null, [SimpleGlyph.empty(), _triangle()]);
      final loca = IndexToLocationTable.create(0, table);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = GlyphDataTable.fromByteData(
        bytes,
        TableRecordEntry('glyf', 0, 0, bytes.lengthInBytes),
        loca,
        2,
      );

      expect(decoded.glyphList, hasLength(2));
      expect(decoded.glyphList[0].isEmpty, isTrue);
      expect(decoded.glyphList[1].pointList, _triangle().pointList);
    });
  });
}
