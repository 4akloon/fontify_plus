import 'dart:math';

import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_outliner.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;
import 'package:vector_math/vector_math.dart';

Vector2 _p0(Cubic c) => c.p0;
Vector2 _p1(Cubic c) => c.p1;
Vector2 _p2(Cubic c) => c.p2;
Vector2 _p3(Cubic c) => c.p3;

/// Curves, corners, a closed ring and an open end — every geometry path the
/// outliner has — paired with how many closed contours stroking it produces:
/// a closed subpath is an annulus of 2 (outer wall, inner wall), an open one
/// a single loop of 1, and this holds regardless of cap/join, so it is a
/// fixed expectation, not something derived from the code under test.
///
/// Asserting it is what stops every per-segment loop below from vacuously
/// passing on empty output — every one of those loops is bounded by
/// `actual.length` / `actual[c].length`, so a plan that silently evaluates to
/// nothing (e.g. `StrokePlan.evaluate` short-circuiting to `const []`) would
/// otherwise sail through with zero assertions made.
const _pathsWithContourCounts = [
  ('M2 12C2 6 6 2 12 2C18 2 22 6 22 12', 1),
  ('M4 4H20V20H4Z', 2),
  ('M12 2L22 20H2Z', 2),
  ('M6 18L18 6M6 6L18 18', 2),
  ('M3 12A9 9 0 1 0 21 12A9 9 0 1 0 3 12', 1),
];

/// (cap, join) combinations covering every branch of `StrokeJoiner` and
/// `StrokeCapper` between them, one value of each enum per combination.
///
/// SVG's actual defaults are `butt`/`miter` — the commonest authored
/// configuration — and miter is the most fragile join (width-invariant only
/// because it divides by `stroke.radius`), so a suite that only ever
/// exercised `round`/`round` would leave all of that unguarded.
const _capJoinCombinations = [
  (LineCap.butt, LineJoin.miter),
  (LineCap.round, LineJoin.round),
  (LineCap.square, LineJoin.bevel),
];

const _min = 1.33;
const _max = 2.0;

void main() {
  group('stroke geometry is affine in the width', () {
    for (final (pathData, expectedContours) in _pathsWithContourCounts) {
      for (final (cap, join) in _capJoinCombinations) {
        test(
          'interpolation reproduces evaluation for "$pathData" '
          '(cap: $cap, join: $join)',
          () {
            final commands = vg.parseSvgPathData(pathData).commands;
            final plan = StrokeOutliner(
              StrokeProperties(width: _max, cap: cap, join: join),
            ).plan(commands);

            final low = plan.evaluate(_min);
            final high = plan.evaluate(_max);

            // A fixed seed keeps a failure reproducible; the point is
            // coverage of the range, not randomness for its own sake.
            final random = Random(20260810);

            for (var trial = 0; trial < 25; trial++) {
              final t = random.nextDouble();
              final width = _min + (_max - _min) * t;
              final actual = plan.evaluate(width);

              expect(
                actual.length,
                expectedContours,
                reason: 'contour count at width $width',
              );

              for (var c = 0; c < actual.length; c++) {
                expect(
                  actual[c],
                  isNotEmpty,
                  reason: 'contour $c at width $width',
                );

                for (var s = 0; s < actual[c].length; s++) {
                  // Typed, not dynamic: `avoid_dynamic_calls` is on, and a
                  // dynamic `.p0` would also hide a rename behind a runtime
                  // failure.
                  const controls = <Vector2 Function(Cubic)>[
                    _p0,
                    _p1,
                    _p2,
                    _p3,
                  ];

                  for (final get in controls) {
                    final expected =
                        get(low[c][s]) * (1 - t) + get(high[c][s]) * t;

                    // Not 1e-9: `Vector2` here is Float32List-backed and
                    // every operator rounds per call, so three independently
                    // evaluated widths compound single-precision noise. Task
                    // 6 measured a 1.9e-6 floor on one fixture, and a
                    // 2000-curve sweep found up to 6.3e-4 on others — the
                    // floor is strongly fixture-dependent, so this bound is
                    // set from the sweep, not from one curve. Tighten it if
                    // you narrow the fixtures.
                    expect(
                      get(actual[c][s]).distanceTo(expected),
                      lessThan(2e-3),
                      reason: 'contour $c segment $s at width $width',
                    );
                  }
                }
              }
            }
          },
        );
      }
    }
  });
}
