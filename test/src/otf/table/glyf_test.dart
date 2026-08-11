import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/table/glyf.dart';
import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:fontify_plus/src/otf/table/glyph/header.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple.dart';
import 'package:fontify_plus/src/otf/table/loca.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

/// A circle glyph, drawn to exactly fill a square artboard of side
/// `2 * radius`. Every on-curve point of a correctly-converted outline sits
/// at precisely [radius] from the artboard's centre, which makes "how far did
/// the curve drift from [radius]" a direct proxy for outline correctness.
String _circleSvg(double radius) {
  final diameter = radius * 2;

  return '<svg xmlns="http://www.w3.org/2000/svg" '
      'viewBox="0 0 $diameter $diameter">'
      '<circle cx="$radius" cy="$radius" r="$radius"/></svg>';
}

/// Evaluates the quadratic bezier through [p0], [p1] (control), [p2] at [t].
double _quadAt(num p0, num p1, num p2, double t) =>
    (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2;

double _distance(math.Point<num> a, math.Point<num> b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

/// The farthest any point *on* [outline]'s curves gets from [center].
///
/// Walks the actual quadratic segments rather than just the stored points:
/// an off-curve point is a control point, not a point on the curve, so
/// checking stored points alone would miss curve segments that bulge between
/// them. [outline] must already be decompacted (see
/// [Outline.decompactImplicitPoints]) so every off-curve point has an
/// on-curve neighbour on each side.
double _maxRadiusOnCurve(Outline outline, math.Point<num> center) {
  final points = outline.pointList;
  final isOnCurve = outline.isOnCurveList;
  var maxDistance = 0.0;

  for (var i = 0; i < points.length; i++) {
    if (isOnCurve[i]) {
      maxDistance = math.max(maxDistance, _distance(points[i], center));
      continue;
    }

    final p0 = points[i - 1];
    final p1 = points[i];
    final p2 = points[(i + 1) % points.length];

    for (var s = 0; s <= 32; s++) {
      final t = s / 32;
      final sample = math.Point<num>(
        _quadAt(p0.x, p1.x, p2.x, t),
        _quadAt(p0.y, p1.y, p2.y, t),
      );

      maxDistance = math.max(maxDistance, _distance(sample, center));
    }
  }

  return maxDistance;
}

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
        TableRecordEntry(
          'glyf',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
        loca,
        2,
      );

      expect(decoded.glyphList, hasLength(2));
      expect(decoded.glyphList[0].isEmpty, isTrue);
      expect(decoded.glyphList[1].pointList, _triangle().pointList);
    });
  });

  group('GlyphDataTable.fromGlyphs cubic-to-quadratic conversion', () {
    test(
      'a circle keeps its curve within about 1% of its nominal radius',
      () {
        const radius = 170.0;
        const center = math.Point<double>(radius, radius);

        final glyph = GenericGlyph.fromSvg('circle', _circleSvg(radius));
        final table = GlyphDataTable.fromGlyphs([glyph]);

        final decoded = GenericGlyph.fromSimpleTrueTypeGlyph(
          table.glyphList.single,
        );
        final outline = decoded.outlines.single..decompactImplicitPoints();

        final maxRadius = _maxRadiusOnCurve(outline, center);

        // Regression guard: an SVG circle is cubic, and TrueType stores only
        // quadratics. Skipping the cubic-to-quadratic conversion leaves the
        // cubic control points in place as if they were quadratic ones,
        // which a rasterizer reads as a curve bulging toward those points —
        // worst at the 45-degree marks, by roughly 10% of the radius here.
        // A correct conversion should track the circle within about 1%.
        expect(maxRadius, closeTo(radius, radius * 0.01));
      },
    );
  });
}
