import 'dart:async';
import 'dart:math' as math;

import 'package:fontify_plus/src/common/glyph/generic_glyph_base.dart';
import 'package:fontify_plus/src/common/glyph/glyph_masters.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/utils/exception.dart';
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

// The same curve as _curved with the default butt cap, so it draws no arcs at
// all. A width whose radius underflows collapses this onto its centreline
// without changing any segment count, which is why the guard has to be on the
// radius rather than on a downstream count mismatch.
const _buttCapped =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12" stroke="#000" '
    'stroke-width="1.5"/></svg>';

// One shape from a real icon set (Hugeicons "Airplane 02", stroke-rounded),
// verbatim. What matters is the authoring style rather than the picture: it is
// one smooth outline written as a long chain of cubics whose control points
// were each rounded to four or five decimals independently, so consecutive
// segments meet at junctions whose tangents agree only to within that
// rounding. That is what puts the tangent difference next to the coincidence
// threshold, and it is the shape of essentially every exported icon path —
// which is why this reproduced across hundreds of icons in the wild while
// none of the hand-written fixtures above ever hit it.
//
// Note the two duplicated-but-not-identical coordinates ("21.8065 7.27356"
// then "21.8065 7.27358", "10.3782 14.4876" twice): the export rounded the
// same mathematical point twice and got two answers.
const _nearTangentialChain =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M8.32846 10.9843L10.2154 9.60557L14.6436 6.37707C14.6436 6.37707 '
    '16.2785 5.17593 17.1919 4.77581C18.2765 4.30067 19.2869 4.52156 20.3739 '
    '4.82515C20.9362 4.98218 21.2173 5.06069 21.4202 5.20717C21.742 5.43958 '
    '21.9513 5.79728 21.9943 6.18852C22.0215 6.4351 21.9498 6.71459 21.8065 '
    '7.27356L21.8065 7.27358C21.5294 8.35431 21.2181 9.32819 20.2588 '
    '10.0175C19.4509 10.598 17.5793 11.3946 17.5793 11.3946L12.5317 '
    '13.5645L10.3782 14.4876L10.3782 14.4876C9.5974 14.8223 9.207 14.9896 '
    '8.94139 15.3002C8.31933 16.0275 8.23148 17.3438 7.99931 18.2494C7.87101 '
    '18.7498 7.16748 19.6171 6.54058 19.4869C6.15355 19.4065 6.14613 18.922 '
    '6.09796 18.6131L5.6342 15.6389C5.5233 14.9276 5.51479 14.9131 4.94599 '
    '14.4627L2.56757 12.5793C2.32053 12.3836 1.89903 12.135 2.022 '
    '11.7641C2.22119 11.1633 3.33408 10.9957 3.83747 11.1363C4.74834 11.3907 '
    '5.94747 11.9738 6.89684 11.8058C7.3022 11.7341 7.64428 11.4842 8.32844 '
    '10.9843L8.32846 10.9843Z" stroke="black" stroke-linecap="round" '
    'stroke-linejoin="round" stroke-width="1.5"/></svg>';

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

int _windingAt(GenericGlyph glyph, double x, double y) {
  var winding = 0;

  for (final outline in glyph.outlines) {
    final pts = outline.pointList;
    if (pts.length < 3) {
      continue;
    }

    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final cross = (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x);
      if (a.y <= y) {
        if (b.y > y && cross > 0) {
          winding++;
        }
      } else if (b.y <= y && cross < 0) {
        winding--;
      }
    }
  }

  return winding;
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

    test('a real icon builds at every range, however narrow', () {
      // Endpoint pairs are not interchangeable, and the failure was not
      // monotonic in how far apart they sat: this icon built at [1.4, 1.6] but
      // not at [1.45, 1.55], nor at [1.49, 1.51] — a hundredth either side of
      // its own authored 1.5. What decided it was whether the two particular
      // widths landed on the same side of a threshold inside the joiner, so a
      // range narrow enough to look obviously safe was as likely to fail as a
      // wide one. Only sweeping pairs can catch that; a single range cannot.
      //
      // The joiner's own test asserts the invariance directly, corner by
      // corner. This asserts the property that actually matters to a caller:
      // the masters come out interpolatable.
      for (final range in [
        [1.0, 2.0],
        [1.33, 2.0],
        [1.35, 1.65],
        [1.4, 1.6],
        [1.45, 1.55],
        [1.49, 1.51],
        [1.499, 1.501],
        [0.5, 3.0],
      ]) {
        final builder = GlyphMasterBuilder(
          StrokeWidthRange(range[0], range[1]),
          defaultWidth: (range[0] + range[1]) / 2,
        );

        final masters = builder.fromSvg('icon', _nearTangentialChain);

        expect(
          masters.min.pointList.length,
          masters.max.pointList.length,
          reason: 'masters differ in point count at $range',
        );
        expect(
          masters.atDefault!.pointList.length,
          masters.max.pointList.length,
          reason: 'the third master differs in point count at $range',
        );
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

    test(
      'a tight corner planned at a wide max keeps its cubic on the '
      'narrow master',
      () {
        // Quarter-circle of radius 1.2. Offsetting inward by 1.5 collapses
        // (distance * curvature = 1.25 > 0.95), so a ContourShape recorded
        // at max marks those pieces straight. Replaying that shape on the
        // narrow master drops the control points — the faceted corners on
        // account-setting-03 at every width below max.
        const radius = 1.2;
        const kappa = 0.5522847498 * radius;
        const svg =
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8" '
            'fill="none"><path d="M ${4 + radius} 4 '
            'C ${4 + radius} ${4 + kappa} ${4 + kappa} ${4 + radius} '
            '4 ${4 + radius}" stroke="#000" stroke-width="1.5"/></svg>';

        final masters = GlyphMasterBuilder(
          StrokeWidthRange(0.5, 3),
        ).fromSvg('corner', svg);

        final offCurve = masters.min.isOnCurveList.where((on) => !on).length;

        // Compatible masters share the flag list, so the max-width chord
        // must be stored as a cubic (collinear controls) rather than as a
        // line. A single cubic on each wall is four off-curve points; two
        // (outer wall only) is the flattened bug.
        expect(masters.min.isOnCurveList, masters.max.isOnCurveList);
        expect(offCurve, greaterThan(2));
      },
    );

    test('a closed tight corner still ends every contour on-curve', () {
      // Same collapse as the test above, but the path is closed so the inner
      // wall is its own contour. If that contour's last piece is a max-width
      // chord and we keep it as a cubic while still dropping the repeated
      // start, the contour ends off-curve and CFF encoding throws.
      const radius = 1.2;
      const kappa = 0.5522847498 * radius;
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8" '
          'fill="none"><path d="M ${4 + radius} 4 '
          'C ${4 + radius} ${4 + kappa} ${4 + kappa} ${4 + radius} '
          '4 ${4 + radius} '
          'C ${4 - kappa} ${4 + radius} ${4 - radius} ${4 + kappa} '
          '${4 - radius} 4 '
          'C ${4 - radius} ${4 - kappa} ${4 - kappa} ${4 - radius} '
          '4 ${4 - radius} '
          'C ${4 + kappa} ${4 - radius} ${4 + radius} ${4 - kappa} '
          '${4 + radius} 4 Z" stroke="#000" stroke-width="1.5"/></svg>';

      final masters = GlyphMasterBuilder(
        StrokeWidthRange(0.5, 3),
      ).fromSvg('ring', svg);

      for (final outline in [
        ...masters.min.outlines,
        ...masters.max.outlines,
      ]) {
        expect(
          outline.isOnCurveList.last,
          isTrue,
          reason: 'CFF contours cannot end off-curve',
        );
      }
    });

    test('fill plus stroke is solid under nonzero winding', () {
      const svg =
          '<svg viewBox="0 0 16 16">'
          '<path d="M2 2H10V10H2Z" fill="#000" stroke="#000" '
          'stroke-width="2"/></svg>';
      final glyph = GlyphMasterBuilder(_range).fromSvg('both', svg).max;

      expect(
        _windingAt(glyph, 2.5, 10),
        isNot(0),
        reason: 'inner half of the stroke must stay inked',
      );
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

      // Asserted directly as well, the way the point-count test above does it:
      // the two calls above are the only place `checkCompatible` is exercised
      // at all, so leaning on them alone would let this test decay into
      // `isNotNull` if that method ever regressed to a no-op.
      expect(atDefault.pointList.length, masters.max.pointList.length);
      expect(atDefault.isOnCurveList, masters.max.isOnCurveList);
      expect(atDefault.outlines.length, masters.max.outlines.length);
    });

    // A degenerate default width is rejected by `StrokePlan.evaluate`, which
    // is the one place every width — endpoint or interior — passes through.
    // This builder deliberately does not re-check the width itself (see its
    // dartdoc), so these two assert the backstop under that decision rather
    // than a rule of its own. `range` is untouched in both, so nothing else
    // can be what fires.
    //
    // These used to expect an `IncompatibleMastersException` "diverges at
    // segment", because a degenerate width perturbed the offset points enough
    // to change a join's branch and so a contour's segment count. That was a
    // side effect of those branches reading the offset points at all, and it
    // disappeared when they were changed to read the source tangents — which
    // is what stopped ordinary widths diverging. Detection by numerical
    // accident is what got replaced here; the width is now simply checked.
    test('a defaultWidth of zero is named, not left to the geometry', () {
      expect(
        () => GlyphMasterBuilder(_range, defaultWidth: 0).fromSvg(
          'icon',
          _curved,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'width')
              .having((e) => e.invalidValue, 'invalidValue', 0),
        ),
      );
    });

    test('a non-finite defaultWidth is named, not left to a RangeError', () {
      // Without the check this reached `outlinesFromContours` as a bare
      // `RangeError (length): Invalid value: Not in inclusive range 0..11: 12`,
      // naming neither the glyph nor the width — and, once the joins stopped
      // reading the offset points, not even that: NaN replays the recorded
      // structure exactly and reaches the font as NaN coordinates.
      expect(
        () => GlyphMasterBuilder(
          _range,
          defaultWidth: double.nan,
        ).fromSvg('icon', _curved),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'width')
              .having((e) => (e.invalidValue as double).isNaN, 'isNaN', true),
        ),
      );
    });

    test('a width whose radius underflows is named too', () {
      // The bound is on the radius, not on the width being merely positive.
      // Below kZeroLength `arcToCubics` emits nothing, so a round cap would
      // collapse from four segments to none — and a butt-capped glyph, which
      // draws no arcs, would not even do that: it would build "successfully"
      // with every outline squashed onto the centreline. Checking the radius
      // catches both, and it is what leaves no width-dependent branch
      // downstream of `StrokePlan.evaluate` at all.
      //
      // 1e-11 builds cleanly, so 1e-12 sits just the far side of the bound.
      for (final width in [1e-12, 1e-300, 5e-324]) {
        for (final source in [_curved, _buttCapped]) {
          expect(
            () => GlyphMasterBuilder(
              _range,
              defaultWidth: width,
            ).fromSvg('icon', source),
            throwsA(
              isA<ArgumentError>().having((e) => e.name, 'name', 'width'),
            ),
            reason: 'width $width should be rejected',
          );
        }
      }

      expect(
        () => GlyphMasterBuilder(
          _range,
          defaultWidth: 1e-11,
        ).fromSvg('icon', _curved),
        returnsNormally,
      );
    });

    test('incompatible masters are reported with the glyph and the reason', () {
      // `_checkContoursReplayShape` can no longer be reached by any input —
      // see its own comment — so this covers the same exception through
      // `checkCompatible`, which is public and is what actually fires if two
      // masters ever come out differently shaped.
      final builder = GlyphMasterBuilder(_range);
      final masters = builder.fromSvg('icon', _curved);
      final other = builder.fromSvg('icon', _plus);

      expect(
        () => builder.checkCompatible('icon', masters.min, other.max),
        throwsA(
          isA<IncompatibleMastersException>()
              .having((e) => e.glyphName, 'glyphName', 'icon')
              .having((e) => e.detail, 'detail', contains('contour')),
        ),
      );
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
