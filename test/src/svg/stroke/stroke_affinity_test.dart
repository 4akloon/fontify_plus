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
/// outliner has.
const _paths = [
  'M2 12C2 6 6 2 12 2C18 2 22 6 22 12',
  'M4 4H20V20H4Z',
  'M12 2L22 20H2Z',
  'M6 18L18 6M6 6L18 18',
  'M3 12A9 9 0 1 0 21 12A9 9 0 1 0 3 12',
];

const _min = 1.33;
const _max = 2.0;

void main() {
  group('stroke geometry is affine in the width', () {
    for (final pathData in _paths) {
      test('interpolation reproduces evaluation for "$pathData"', () {
        final commands = vg.parseSvgPathData(pathData).commands;
        final plan = StrokeOutliner(
          const StrokeProperties(
            width: _max,
            cap: LineCap.round,
            join: LineJoin.round,
          ),
        ).plan(commands);

        final low = plan.evaluate(_min);
        final high = plan.evaluate(_max);

        // A fixed seed keeps a failure reproducible; the point is coverage of
        // the range, not randomness for its own sake.
        final random = Random(20260810);

        for (var trial = 0; trial < 25; trial++) {
          final t = random.nextDouble();
          final width = _min + (_max - _min) * t;
          final actual = plan.evaluate(width);

          for (var c = 0; c < actual.length; c++) {
            for (var s = 0; s < actual[c].length; s++) {
              // Typed, not dynamic: `avoid_dynamic_calls` is on, and a dynamic
              // `.p0` would also hide a rename behind a runtime failure.
              const controls = <Vector2 Function(Cubic)>[
                _p0,
                _p1,
                _p2,
                _p3,
              ];

              for (final get in controls) {
                final expected = get(low[c][s]) * (1 - t) + get(high[c][s]) * t;

                // Not 1e-9: `Vector2` here is Float32List-backed and every
                // operator rounds per call, so three independently evaluated
                // widths compound single-precision noise. Task 6 measured a
                // 1.9e-6 floor on one fixture, and a 2000-curve sweep found
                // up to 6.3e-4 on others — the floor is strongly
                // fixture-dependent, so this bound is set from the sweep, not
                // from one curve. Tighten it if you narrow the fixtures.
                expect(
                  get(actual[c][s]).distanceTo(expected),
                  lessThan(2e-3),
                  reason: 'contour $c segment $s at width $width',
                );
              }
            }
          }
        }
      });
    }
  });
}
