import 'dart:math' as math;

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/svg/stroke.dart';
import 'package:fontify_plus/src/svg/stroke_outliner.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:path_parsing/path_parsing.dart';
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

/// Flattens path data into one point list per contour.
///
/// The outliner emits cubics wherever the geometry was curved, so these
/// assertions have to go through a real path parser rather than splitting the
/// string on command letters.
class _ContourReader extends PathProxy {
  final contours = <List<List<double>>>[];

  List<List<double>>? _current;
  var _cursor = [0.0, 0.0];

  @override
  void moveTo(double x, double y) {
    _flush();
    _cursor = [x, y];
    _current = [
      [x, y],
    ];
  }

  @override
  void lineTo(double x, double y) {
    _cursor = [x, y];
    (_current ??= []).add([x, y]);
  }

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final p0 = _cursor;
    const steps = 24;

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final u = 1 - t;
      final a = u * u * u;
      final b = 3 * u * u * t;
      final c = 3 * u * t * t;
      final d = t * t * t;

      (_current ??= []).add([
        a * p0[0] + b * x1 + c * x2 + d * x3,
        a * p0[1] + b * y1 + c * y2 + d * y3,
      ]);
    }

    _cursor = [x3, y3];
  }

  @override
  void close() => _flush();

  void _flush() {
    final current = _current;

    if (current != null && current.length > 2) {
      contours.add(current);
    }

    _current = null;
  }

  List<List<List<double>>> read(String pathData) {
    writeSvgPathDataToPath(pathData, this);
    _flush();

    return contours;
  }
}

List<List<List<double>>> _contours(String pathData) =>
    _ContourReader().read(pathData);

double _totalArea(String pathData) =>
    _contours(pathData).fold(0.0, (sum, c) => sum + _signedArea(c).abs());

/// Number of drawing commands in path data — the size the glyph will cost.
int _commandCount(String pathData) =>
    RegExp('[MLCZ]').allMatches(pathData).length;

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

    test('emits curves rather than a dense polyline', () {
      // Offsetting only works on line segments, so the outline is built as a
      // flattened polyline and then refitted. Shipping the polyline verbatim
      // would cost dozens of commands per icon for no extra accuracy.
      final outlined = outlineStrokeToPathData('M0 0C0 5 10 5 10 0', _stroke)!;

      expect(outlined, contains('C'));
      // The flattened polyline behind this outline runs to several hundred
      // points; refitting has to bring it back to the order of the curve.
      expect(
        _commandCount(outlined),
        lessThan(30),
        reason: 'a refitted curve should need far fewer commands than samples',
      );
    });

    test('stays accurate after refitting', () {
      // Compactness is only worth having if the shape survives it. A stroke of
      // width 2 along a curve of arc length L covers about 2L.
      final outlined = outlineStrokeToPathData('M0 0C0 5 10 5 10 0', _stroke)!;

      final contour = _contours(outlined).single;
      final xs = contour.map((p) => p[0]);
      final ys = contour.map((p) => p[1]);

      // Both ends of this curve leave vertically, so the stroke spreads
      // sideways there and the butt caps sit flat on y = 0.
      expect(xs.reduce(math.min), closeTo(-1, 0.05));
      expect(xs.reduce(math.max), closeTo(11, 0.05));
      expect(ys.reduce(math.min), closeTo(0, 0.05));

      // The curve peaks at 3.75, plus half a stroke width.
      expect(ys.reduce(math.max), closeTo(4.75, 0.05));
    });

    test('keeps a miter corner sharp through refitting', () {
      // Curve fitting is smooth by construction, so a corner survives only if
      // the outliner marks it and the run is cut there. If that breaks, the
      // sharp tip is quietly rounded away.
      final outlined = outlineStrokeToPathData(
        'M0 0L10 0L10 10',
        const StrokeProperties(width: 2, miterLimit: 10),
      )!;

      final contour = _contours(outlined).single;

      // The outer miter tip of a right angle sits at (11, -1).
      final reachesTip = contour.any(
        (p) => (p[0] - 11).abs() < 0.01 && (p[1] + 1).abs() < 0.01,
      );

      expect(reachesTip, isTrue, reason: 'the miter tip was rounded off');
    });

    test('keeps a square cap sharp through refitting', () {
      final outlined = outlineStrokeToPathData(
        'M0 0H10',
        const StrokeProperties(width: 2, cap: LineCap.square),
      )!;

      // Square caps are four right angles; rounding any of them loses area.
      expect(_totalArea(outlined), closeTo(24, 0.01));
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
