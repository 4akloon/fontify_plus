import 'dart:async';
import 'dart:math' as math;

import 'package:fontify_plus/src/common/glyph/generic_glyph_base.dart';
import 'package:fontify_plus/src/common/glyph/glyph_masters.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:test/test.dart';

/// Runs [body] with `print` captured instead of written to stdout.
///
/// Matches `test/src/utils/logger_test.dart`'s helper of the same name —
/// duplicated rather than imported, following the precedent in
/// `test/src/otf/debugger_test.dart`, since importing one test file from
/// another is not this codebase's pattern.
List<String> capturePrints(void Function() body) {
  final lines = <String>[];

  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );

  return lines;
}

const _plus =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/></svg>';

const _strokedSvg = _plus;

// One shape at 1, one at 1.5 — the "hairline detail against thicker main
// strokes" the warning's docs describe.
const _mixedWidthSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/>'
    '<path d="M4 4L8 4" stroke="#000" stroke-width="1" '
    'stroke-linecap="round"/></svg>';

const _curved =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12" stroke="#000" '
    'stroke-width="1.5" stroke-linecap="round"/></svg>';

const _filled =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M4 4H20V20H4Z" fill="#000"/></svg>';

// Not `const`: the constructor validates with a body (throwing
// `ArgumentError`), which a const constructor cannot do.
final _range = StrokeWidthRange(1.33, 2);

/// Samples per cubic when measuring area.
const _areaSteps = 24;

/// The ink a glyph covers, in the source SVG's user units.
///
/// The same measurement `test/src/svg/stroke/contour_reader.dart` makes of the
/// outliner's cubics, taken one stage later: a master's [Outline]s, where the
/// curves have already been split into points and on-curve flags. Curves are
/// sampled rather than read off their end points, because a stroke's walls are
/// cubics and their bulge is most of what changes with width.
///
/// Each contour contributes the absolute value of its own signed area. The
/// outliner picks a winding per ring, so summing signed areas would let two
/// rings cancel; summing magnitudes cannot, at the price of double-counting
/// where two rings overlap. That is only sound for a fixture whose rings do
/// not overlap — which is why the caller below uses a single-contour one.
double _outlineArea(GenericGlyph glyph) {
  var total = 0.0;

  for (final outline in glyph.outlines) {
    final points = outline.pointList;
    final isOnCurve = outline.isOnCurveList;

    if (points.length < 3) {
      continue;
    }

    // Walks the contour exactly as `Outline.cubicToQuad` does: an on-curve
    // point one step ahead is a straight segment, two off-curve points are a
    // cubic, and a cubic running off the end closes back onto the start.
    final sampled = <math.Point<num>>[points.first];
    var i = 0;

    while (i < points.length - 1) {
      if (isOnCurve[i + 1]) {
        sampled.add(points[i + 1]);
        i++;
        continue;
      }

      final end = i + 3 < points.length ? points[i + 3] : points.first;

      for (var s = 1; s <= _areaSteps; s++) {
        sampled.add(
          _cubicAt(
            points[i],
            points[i + 1],
            points[i + 2],
            end,
            s / _areaSteps,
          ),
        );
      }

      i += 3;
    }

    total += _shoelace(sampled).abs();
  }

  return total;
}

math.Point<num> _cubicAt(
  math.Point<num> p0,
  math.Point<num> p1,
  math.Point<num> p2,
  math.Point<num> p3,
  double t,
) {
  final u = 1 - t;
  final a = u * u * u;
  final b = 3 * u * u * t;
  final c = 3 * u * t * t;
  final d = t * t * t;

  return math.Point<num>(
    a * p0.x + b * p1.x + c * p2.x + d * p3.x,
    a * p0.y + b * p1.y + c * p2.y + d * p3.y,
  );
}

/// The signed area of the closed polygon through [points].
double _shoelace(List<math.Point<num>> points) {
  var sum = 0.0;

  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];

    sum += a.x * b.y - b.x * a.y;
  }

  return sum / 2;
}

void main() {
  group('GlyphMasterBuilder', () {
    test('gives both masters the same point count', () {
      for (final source in [_plus, _curved]) {
        final masters = GlyphMasterBuilder(_range).fromSvg('icon', source);

        expect(
          masters.min.pointList.length,
          masters.max.pointList.length,
          reason: 'masters differ in point count',
        );
        expect(masters.min.isOnCurveList, masters.max.isOnCurveList);
      }
    });

    test('the thick master really is thicker', () {
      final masters = GlyphMasterBuilder(_range).fromSvg('icon', _curved);

      // Same centreline, more ink: the wider master's box is at least as wide
      // and its points are not all identical.
      expect(masters.max.metrics.width, greaterThan(masters.min.metrics.width));
    });

    test('a fill is identical in both masters', () {
      final masters = GlyphMasterBuilder(_range).fromSvg('icon', _filled);

      expect(masters.min.pointList, masters.max.pointList);
    });

    test('no defaultWidth builds exactly two masters', () {
      final masters = GlyphMasterBuilder(_range).fromSvg('icon', _curved);

      expect(masters.atDefault, isNull);
    });

    test('a defaultWidth builds a third, compatible master', () {
      final builder = GlyphMasterBuilder(_range, defaultWidth: 1.5);
      final masters = builder.fromSvg('icon', _curved);
      final atDefault = masters.atDefault;

      expect(atDefault, isNotNull);

      // A third master is only usable if the deltas between it and the other
      // two exist — same contours, same points, same on-curve flags.
      builder.checkCompatible('icon', atDefault!, masters.max);
      builder.checkCompatible('icon', atDefault, masters.min);
    });

    test('a fill is identical in all three masters', () {
      final masters = GlyphMasterBuilder(
        _range,
        defaultWidth: 1.5,
      ).fromSvg('icon', _filled);

      expect(masters.atDefault!.pointList, masters.max.pointList);
      expect(masters.atDefault!.pointList, masters.min.pointList);
    });

    test('the third master is between min and max, not a copy of either', () {
      final masters = GlyphMasterBuilder(
        _range,
        defaultWidth: 1.5,
      ).fromSvg('icon', _curved);

      // `_curved` is one open, smooth, non-self-intersecting stroke with round
      // caps, so its outline is a single ring enclosing the Minkowski sum of
      // the centreline with a disc of radius w/2: area 2rL + pi*r^2, strictly
      // increasing in w. With a centreline about 31 units long that is roughly
      // 43, 48 and 65 units at widths 1.33, 1.5 and 2 — gaps far wider than
      // the sampling error in `_outlineArea`.
      final minArea = _outlineArea(masters.min);
      final defaultArea = _outlineArea(masters.atDefault!);
      final maxArea = _outlineArea(masters.max);

      expect(defaultArea, greaterThan(minArea));
      expect(defaultArea, lessThan(maxArea));
    });

    test('a default equal to an endpoint is accepted here', () {
      // Validation is the caller's job, not this class's: the boundaries the
      // width arrives through reject it in the error vocabulary their own
      // callers expect — `ArgumentError` from the Dart API, a
      // `FontifyException` naming a config key from YAML/CLI. This test exists
      // so that a future reader does not "helpfully" add a duplicate check
      // here, and it fails the moment one is added in either the constructor
      // or `fromSvg`.
      late final GlyphMasters masters;

      expect(
        () => masters = GlyphMasterBuilder(
          _range,
          defaultWidth: _range.max,
        ).fromSvg('icon', _curved),
        returnsNormally,
      );

      // Not merely "did not throw": the endpoint width was really used, and
      // reproduced the max master exactly.
      expect(masters.atDefault!.pointList, masters.max.pointList);
    });

    test('rejects a range that is not ascending and positive', () {
      expect(() => StrokeWidthRange(2, 1.33), throwsArgumentError);
      expect(() => StrokeWidthRange(0, 2), throwsArgumentError);
      expect(() => StrokeWidthRange(1.5, 1.5), throwsArgumentError);
    });

    test('an SVG mixing stroke widths is named in a warning', () {
      // The axis overrides stroke-width absolutely, so an icon drawing a
      // detail at 1 and its main strokes at 1.5 loses that hierarchy. Losing
      // it silently is what this prevents.
      final records = capturePrints(
        () => GlyphMasterBuilder(_range).fromSvg('mixed', _mixedWidthSvg),
      );

      expect(records.join('\n'), contains('mixed'));
      expect(records.join('\n'), contains('1.0'));
      expect(records.join('\n'), contains('1.5'));
    });

    test('a single authored width warns about nothing', () {
      final records = capturePrints(
        () => GlyphMasterBuilder(_range).fromSvg('plain', _strokedSvg),
      );

      expect(records, isEmpty);
    });

    test('two mixed-width files are each named in their own warning', () {
      // Each file's message carries its own name, so this cannot tell
      // `logger.w` apart from `logger.logOnce` (the two messages differ and
      // so are never deduplicated either way) — but it does pin the
      // "collapsing across an icon set would hide every file but the first"
      // property the CHANGELOG describes: building an icon set must not
      // lose either file's warning.
      final records = capturePrints(() {
        GlyphMasterBuilder(_range).fromSvg('first', _mixedWidthSvg);
        GlyphMasterBuilder(_range).fromSvg('second', _mixedWidthSvg);
      });

      final joined = records.join('\n');

      expect(joined, contains('first'));
      expect(joined, contains('second'));
    });

    test('the same name warns every time, not only the first', () {
      // This is what actually distinguishes `logger.w` from `logger.logOnce`:
      // with the file's name baked into the message, two *different* names
      // never collide in `logOnce`'s dedup set regardless of which method is
      // used (see the test above), so only two calls that would produce the
      // exact same message can tell them apart.
      final records = capturePrints(() {
        GlyphMasterBuilder(_range).fromSvg('same', _mixedWidthSvg);
        GlyphMasterBuilder(_range).fromSvg('same', _mixedWidthSvg);
      });

      expect(records, hasLength(2));
    });
  });
}
