import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:fontify_plus/src/otf/table/glyph/header.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple.dart';
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

void main() {
  group('SimpleGlyph.empty', () {
    test('has zero contours and is empty', () {
      final glyph = SimpleGlyph.empty();

      expect(glyph.isEmpty, isTrue);
      expect(glyph.size, 0);
    });
  });

  group('SimpleGlyph.isEmpty', () {
    test('is false for a glyph with contours', () {
      expect(_triangle().isEmpty, isFalse);
    });
  });

  group('SimpleGlyph round trip', () {
    test(
      'round-trips a single-contour glyph through encodeToBinary and fromByteData',
      () {
        final glyph = _triangle();
        final bytes = ByteData(glyph.size);

        glyph.encodeToBinary(bytes);
        final decoded = SimpleGlyph.fromByteData(bytes, glyph.header, 0);

        expect(decoded.header.numberOfContours, 1);
        expect(decoded.endPtsOfContours, [2]);
        expect(decoded.pointList, [
          const math.Point<num>(0, 0),
          const math.Point<num>(10, 0),
          const math.Point<num>(10, 10),
        ]);
      },
    );

    test('round-trips repeated flags without losing any point', () {
      final points = [
        for (var i = 0; i < 5; i++) math.Point<num>(i * 10, 0),
      ];
      final flag = SimpleGlyphFlag.createForPoint(
        x: 0,
        y: 0,
        isOnCurve: true,
      ).repeated(4);
      final glyph = SimpleGlyph(
        header: GlyphHeader(
          numberOfContours: 1,
          xMin: 0,
          yMin: 0,
          xMax: 40,
          yMax: 0,
        ),
        endPtsOfContours: [4],
        instructions: [],
        // One entry per point, as fromByteData builds it.
        flags: List.filled(5, flag),
        pointList: points,
      );
      final bytes = ByteData(glyph.size);

      glyph.encodeToBinary(bytes);
      final decoded = SimpleGlyph.fromByteData(bytes, glyph.header, 0);

      expect(decoded.pointList, points);
    });

    test('round-trips non-empty instructions', () {
      final glyph = SimpleGlyph(
        header: GlyphHeader(
          numberOfContours: 1,
          xMin: 0,
          yMin: 0,
          xMax: 10,
          yMax: 10,
        ),
        endPtsOfContours: [0],
        instructions: [1, 2, 3],
        flags: [SimpleGlyphFlag.createForPoint(x: 0, y: 0, isOnCurve: true)],
        pointList: [const math.Point<num>(0, 0)],
      );
      final bytes = ByteData(glyph.size);

      glyph.encodeToBinary(bytes);
      final decoded = SimpleGlyph.fromByteData(bytes, glyph.header, 0);

      expect(decoded.instructions, [1, 2, 3]);
    });
  });
}
