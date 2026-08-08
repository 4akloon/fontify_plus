import 'dart:math' as math;

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/svg/stroke.dart';
import 'package:fontify_plus/src/svg/stroke_outliner.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:test/test.dart';

/// Signed area of a closed polygon via the shoelace formula.
///
/// Sign carries the winding direction, which decides whether a contour adds to
/// or subtracts from the fill under the nonzero rule.
double _signedArea(List<List<double>> points) {
  var sum = 0.0;

  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += a[0] * b[1] - b[0] * a[1];
  }

  return sum / 2;
}

/// Extracts each `M ... Z` contour from polygonal path data.
List<List<List<double>>> _contours(String pathData) {
  final contours = <List<List<double>>>[];

  for (final chunk in pathData.split('M')) {
    if (chunk.trim().isEmpty) {
      continue;
    }

    final points = <List<double>>[];

    for (final part in chunk.replaceAll('Z', '').split('L')) {
      final coords = part.trim().split(RegExp(r'\s+'));

      if (coords.length == 2) {
        final x = double.tryParse(coords[0]);
        final y = double.tryParse(coords[1]);

        if (x != null && y != null) {
          points.add([x, y]);
        }
      }
    }

    if (points.isNotEmpty) {
      contours.add(points);
    }
  }

  return contours;
}

double _totalArea(String pathData) =>
    _contours(pathData).fold(0.0, (sum, c) => sum + _signedArea(c).abs());

const _stroke = StrokeProperties(width: 2);

void main() {
  group('StrokeProperties', () {
    StrokeProperties? resolveFrom(String svg) {
      final parsed = Svg.parse('t', svg, outlineStrokes: false);
      return StrokeProperties.resolve(parsed.elementList.first);
    }

    test('reads stroke geometry from the element', () {
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16"><path d="M0 0H8" stroke="#000" '
        'stroke-width="3" stroke-linecap="round" stroke-linejoin="bevel" '
        'stroke-miterlimit="8"/></svg>',
      );

      expect(props, isNotNull);
      expect(props!.width, 3);
      expect(props.radius, 1.5);
      expect(props.cap, LineCap.round);
      expect(props.join, LineJoin.bevel);
      expect(props.miterLimit, 8);
    });

    test('inherits stroke attributes from an ancestor group', () {
      // Figma nests icon paths inside <g>, so inheritance is the common case,
      // not an edge case.
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16"><g stroke="#000" stroke-width="4" '
        'stroke-linecap="square"><path d="M0 0H8"/></g></svg>',
      );

      expect(props, isNotNull);
      expect(props!.width, 4);
      expect(props.cap, LineCap.square);
    });

    test('defaults stroke-width to 1 when only stroke is set', () {
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16"><path d="M0 0H8" stroke="#000"/></svg>',
      );

      expect(props?.width, 1);
    });

    test('tolerates a unit suffix on stroke-width', () {
      final props = resolveFrom(
        '<svg viewBox="0 0 16 16">'
        '<path d="M0 0H8" stroke="#000" stroke-width="2px"/></svg>',
      );

      expect(props?.width, 2);
    });

    test('reports no stroke for an unstroked path', () {
      expect(
        resolveFrom('<svg viewBox="0 0 16 16"><path d="M0 0H8"/></svg>'),
        isNull,
      );
    });

    test('reports no stroke for stroke="none"', () {
      expect(
        resolveFrom(
          '<svg viewBox="0 0 16 16">'
          '<path d="M0 0H8" stroke="none" stroke-width="2"/></svg>',
        ),
        isNull,
      );
    });
  });

  group('outlineStrokeToPathData', () {
    test('gives a straight stroke the area of its bounding rectangle', () {
      // A 10-long, 2-wide butt-capped stroke covers exactly 20 square units.
      final outlined = outlineStrokeToPathData('M0 0H10', _stroke);

      expect(outlined, isNotNull);
      expect(_totalArea(outlined!), closeTo(20, 0.01));
    });

    test('extends a square cap by half the stroke width at each end', () {
      final outlined = outlineStrokeToPathData(
        'M0 0H10',
        const StrokeProperties(width: 2, cap: LineCap.square),
      );

      // 10 + 1 + 1 long, 2 wide.
      expect(_totalArea(outlined!), closeTo(24, 0.01));
    });

    test('adds a half disc at each end for a round cap', () {
      final outlined = outlineStrokeToPathData(
        'M0 0H10',
        const StrokeProperties(width: 2, cap: LineCap.round),
      );

      // 20 for the body, plus a unit circle spread across the two caps.
      //
      // The arc is flattened into an inscribed polygon, so it approaches the
      // true circle from below and never exceeds it. Bounding it on both sides
      // pins the geometry without asserting a segment count the flattening
      // tolerance is free to change.
      const body = 20.0;
      const disc = math.pi;

      expect(_totalArea(outlined!), lessThanOrEqualTo(body + disc));
      expect(_totalArea(outlined), greaterThan(body + disc * 0.95));
    });

    test('produces a hollow ring for a closed stroke', () {
      // A stroked 10x10 square: two contours, wound opposite so the nonzero
      // rule leaves the interior empty.
      final outlined = outlineStrokeToPathData(
        'M0 0H10V10H0Z',
        const StrokeProperties(width: 2, join: LineJoin.miter),
      );

      final contours = _contours(outlined!);
      expect(contours, hasLength(2));

      final areas = contours.map(_signedArea).toList();
      expect(
        areas[0].sign,
        isNot(areas[1].sign),
        reason: 'inner and outer walls must wind opposite to leave a hole',
      );

      // Outer 12x12 minus inner 8x8.
      final ring = areas.map((a) => a.abs()).reduce((a, b) => a - b).abs();
      expect(ring, closeTo(144 - 64, 0.01));
    });

    test('keeps crossing subpaths as separate contours', () {
      // A plus sign: two strokes that cross. They must not be spliced into one
      // contour, and the nonzero rule merges them where they overlap.
      final outlined = outlineStrokeToPathData('M5 0V10M0 5H10', _stroke);

      expect(_contours(outlined!), hasLength(2));
    });

    test('returns null when there is nothing to stroke', () {
      expect(outlineStrokeToPathData('', _stroke), isNull);
    });

    test('falls back to a bevel past the miter limit', () {
      // A very sharp corner would spike far past the join; stroke-miterlimit
      // caps it. The tight limit must produce strictly less area than a
      // generous one.
      const path = 'M0 0L10 0L0 0.5';

      final clipped = outlineStrokeToPathData(
        path,
        const StrokeProperties(width: 2, miterLimit: 1),
      );
      final spiked = outlineStrokeToPathData(
        path,
        const StrokeProperties(width: 2, miterLimit: 100),
      );

      expect(_totalArea(clipped!), lessThan(_totalArea(spiked!)));
    });

    test('flattens curves finely enough to stay smooth', () {
      final outlined = outlineStrokeToPathData(
        'M0 0C0 5 10 5 10 0',
        _stroke,
      );

      // A coarse approximation would betray itself as a handful of points.
      expect(_contours(outlined!).first.length, greaterThan(20));
    });
  });

  group('Svg.parse with outlineStrokes', () {
    // The end-to-end guard: this is the exact shape Figma exports for
    // outline-style icon sets, and the reason such icons used to come out blank.
    const strokedPlus = '<svg viewBox="0 0 16 16" fill="none">'
        '<path d="M8 2.66667V13.3333M13.3333 8H2.66666" stroke="#000" '
        'stroke-width="1.33" stroke-linecap="round"/></svg>';

    test('turns a stroked icon into fillable outlines', () {
      final glyph = GenericGlyph.fromSvg(
        Svg.parse('plus', strokedPlus, outlineStrokes: true),
      );

      expect(glyph.outlines, isNotEmpty);

      final area = glyph.outlines.fold<double>(
        0,
        (sum, o) =>
            sum +
            _signedArea([
              for (final p in o.pointList) [p.x.toDouble(), p.y.toDouble()],
            ]).abs(),
      );

      expect(area, greaterThan(1), reason: 'a stroked icon must enclose area');
    });

    test('leaves a zero-area centreline when disabled', () {
      final glyph = GenericGlyph.fromSvg(
        Svg.parse('plus', strokedPlus, outlineStrokes: false),
      );

      final area = glyph.outlines.fold<double>(
        0,
        (sum, o) =>
            sum +
            _signedArea([
              for (final p in o.pointList) [p.x.toDouble(), p.y.toDouble()],
            ]).abs(),
      );

      expect(
        area,
        closeTo(0, 0.001),
        reason: 'the unconverted centreline is what made icons render blank',
      );
    });

    test('keeps the fill of a path that is both filled and stroked', () {
      final glyph = GenericGlyph.fromSvg(
        Svg.parse(
          'both',
          '<svg viewBox="0 0 16 16">'
              '<path d="M2 2H10V10H2Z" fill="#000" stroke="#000" '
              'stroke-width="2"/></svg>',
          outlineStrokes: true,
        ),
      );

      // The original filled contour plus the two walls of the stroked ring.
      expect(glyph.outlines.length, greaterThanOrEqualTo(3));
    });
  });
}
