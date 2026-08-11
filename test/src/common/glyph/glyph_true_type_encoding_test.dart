import 'dart:math';
import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple.dart';
import 'package:test/test.dart';

GenericGlyph glyphOf(List<Point<num>> points, List<bool> onCurve) =>
    GenericGlyph(
      [
        Outline(
          pointList: points,
          isOnCurveList: onCurve,
          hasCompactCurves: false,
          hasQuadCurves: false,
          fillRule: FillRule.nonzero,
        ),
      ],
      const Rectangle(0, 0, 10, 10),
    );

/// Encodes [glyph] and decodes it straight back, the way a real font
/// round-trips through disk.
SimpleGlyph roundTrip(SimpleGlyph glyph) {
  final bytes = ByteData(glyph.size);
  glyph.encodeToBinary(bytes);

  return SimpleGlyph.fromByteData(
    bytes,
    glyph.header,
    0,
  );
}

void main() {
  group('GlyphTrueTypeEncoding.toSimpleTrueTypeGlyph', () {
    test('carries the point list and on-curve flags over', () {
      final glyph = glyphOf(
        [const Point(0, 0), const Point(10, 0), const Point(10, 10)],
        [true, true, true],
      );

      final simple = glyph.toSimpleTrueTypeGlyph();

      expect(simple.pointList, glyph.pointList);
      expect(
        simple.flags.map((f) => f.onCurvePoint),
        [true, true, true],
      );
    });

    test('takes the header bounds from the absolute coordinates', () {
      final glyph = glyphOf(
        [const Point(2, 3), const Point(12, 3), const Point(12, 8)],
        [true, true, true],
      );

      final header = glyph.toSimpleTrueTypeGlyph().header;

      expect(header.xMin, 2);
      expect(header.yMin, 3);
      expect(header.xMax, 12);
      expect(header.yMax, 8);
    });

    test('numberOfContours matches the number of outlines', () {
      final glyph = GenericGlyph(
        [
          Outline(
            pointList: [
              const Point(0, 0),
              const Point(1, 0),
              const Point(1, 1),
            ],
            isOnCurveList: [true, true, true],
            hasCompactCurves: false,
            hasQuadCurves: false,
            fillRule: FillRule.nonzero,
          ),
          Outline(
            pointList: [
              const Point(5, 5),
              const Point(6, 5),
              const Point(6, 6),
            ],
            isOnCurveList: [true, true, true],
            hasCompactCurves: false,
            hasQuadCurves: false,
            fillRule: FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 10, 10),
      );

      expect(glyph.toSimpleTrueTypeGlyph().header.numberOfContours, 2);
    });

    test('compacts a long run of identically-shaped deltas into one flag', () {
      // Every step here is (+1, 0): same short-vector and same-or-positive
      // bits throughout, so the whole run collapses into a single repeating
      // flag.
      final glyph = glyphOf(
        [
          const Point(0, 0),
          const Point(1, 0),
          const Point(2, 0),
          const Point(3, 0),
          const Point(4, 0),
        ],
        [true, true, true, true, true],
      );

      final flags = glyph.toSimpleTrueTypeGlyph().flags;

      expect(flags.first.repeatTimes, 4);
    });

    test('does not mark a run shorter than the minimum profitable length', () {
      // Deltas (0,0) then (1,0) share their short/non-negative bits — a run
      // of two — before (-1,0) breaks it with a negative x. A repeat byte for
      // just two matching flags would cost as much as writing the second one
      // out in full, so it is not worth spending.
      final glyph = glyphOf(
        [const Point(0, 0), const Point(1, 0), const Point(0, 0)],
        [true, true, true],
      );

      final flags = glyph.toSimpleTrueTypeGlyph().flags;

      expect(flags.every((f) => f.repeatTimes == 0), isTrue);
    });

    test('a repeat run still has one flag entry per point', () {
      // SimpleGlyph indexes flags positionally; compaction must not shrink
      // the list even though most of a run's bytes are never written.
      final glyph = glyphOf(
        [
          const Point(0, 0),
          const Point(1, 0),
          const Point(2, 0),
          const Point(3, 0),
        ],
        [true, true, true, true],
      );

      expect(glyph.toSimpleTrueTypeGlyph().flags, hasLength(4));
    });

    test('round-trips point coordinates through encode and decode', () {
      final points = [
        const Point(0, 0),
        const Point(1, 0),
        const Point(2, 0),
        const Point(3, 0),
        const Point(4, 5),
      ];
      final glyph = glyphOf(points, [true, true, true, true, true]);

      final decoded = roundTrip(glyph.toSimpleTrueTypeGlyph());

      expect(decoded.pointList, points);
    });

    test('round-trips on-curve flags through encode and decode', () {
      final glyph = glyphOf(
        [const Point(0, 0), const Point(5, 10), const Point(10, 0)],
        [true, false, true],
      );

      final decoded = roundTrip(glyph.toSimpleTrueTypeGlyph());

      expect(decoded.flags.map((f) => f.onCurvePoint), [true, false, true]);
    });

    test('round-trips a compacted run of many identical points', () {
      final points = [
        for (var i = 0; i < 20; i++) Point<num>(i, 0),
      ];
      final glyph = glyphOf(points, List.filled(20, true));

      final decoded = roundTrip(glyph.toSimpleTrueTypeGlyph());

      expect(decoded.pointList, points);
    });
  });
}
