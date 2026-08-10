import 'package:fontify_plus/src/svg/stroke/stroke_outliner.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// A rounded, curved, self-crossing path — every join and cap kind at once.
const _curvyPath = 'M2 12C2 6 6 2 12 2C18 2 22 6 22 12M6 18L18 6M6 6L18 18';

/// A chevron whose one corner turns exactly 90° at a 45° orientation — the
/// most common join in icon sets (chevrons, checkmarks, arrowheads), and the
/// shape that puts a round join's arc sweep exactly on the knife edge of
/// `arcToCubics`' `ceil(sweep / 90°)`.
const _chevronPath = 'M6 9L12 15L18 9';

/// A corner that turns by a few thousandths of a degree — near-collinear
/// rather than near-perpendicular. The gap a join has to bridge there is
/// tiny and scales with the radius, which is what probes the coincidence
/// threshold at the top of `StrokeJoiner.join` rather than the smooth-
/// junction or arc-sweep branches the other two paths exercise.
const _nearCollinearPath = 'M0 0L10 0L20 0.00039';

const _paths = [_curvyPath, _chevronPath, _nearCollinearPath];

const _widths = [0.5, 1.0, 1.33, 1.5, 2.0, 3.0];

/// The config test 1 and test 3 anchor on: round joins and caps exercise
/// every branch in `StrokeJoiner` and `StrokeCapper` at once.
const _stroke = StrokeProperties(
  width: 2,
  cap: LineCap.round,
  join: LineJoin.round,
);

/// One entry per contour: how many segments it holds. Topology, not
/// coordinates — this is what has to stay fixed across widths.
List<int> _segmentCounts(List<List<Object>> contours) => [
  for (final contour in contours) contour.length,
];

void main() {
  group('StrokePlan', () {
    final commands = vg.parseSvgPathData(_curvyPath).commands;

    test('evaluating at the planning width reproduces outline()', () {
      final outliner = StrokeOutliner(_stroke);

      final direct = outliner.outline(commands);
      final planned = outliner.plan(commands).evaluate(_stroke.width);

      expect(_segmentCounts(planned), _segmentCounts(direct));

      for (var c = 0; c < direct.length; c++) {
        for (var s = 0; s < direct[c].length; s++) {
          expect(planned[c][s].p0.distanceTo(direct[c][s].p0), lessThan(1e-9));
          expect(planned[c][s].p1.distanceTo(direct[c][s].p1), lessThan(1e-9));
          expect(planned[c][s].p2.distanceTo(direct[c][s].p2), lessThan(1e-9));
          expect(planned[c][s].p3.distanceTo(direct[c][s].p3), lessThan(1e-9));
        }
      }
    });

    test('holds its topology across the whole width range', () {
      // Sweeps shape x cap x join x width. The two branches in StrokeJoiner
      // that turned out not to be width-invariant by construction — a round
      // join's arc sweep, and the coincidence test's absolute threshold —
      // only diverge for specific shapes (an exact quarter-turn corner, and
      // a near-collinear one), so a single fixed path and join would not
      // have exercised them.
      for (final path in _paths) {
        final pathCommands = vg.parseSvgPathData(path).commands;

        for (final cap in LineCap.values) {
          for (final join in LineJoin.values) {
            final plan = StrokeOutliner(
              StrokeProperties(width: _widths.first, cap: cap, join: join),
            ).plan(pathCommands);
            final reference = _segmentCounts(plan.evaluate(_widths.first));

            for (final width in _widths) {
              expect(
                _segmentCounts(plan.evaluate(width)),
                reference,
                reason:
                    'topology changed at width $width '
                    '(path: $path, cap: $cap, join: $join)',
              );
            }
          }
        }
      }
    });

    test('an unplanned outliner still subdivides differently per width', () {
      // Guards the test above: without a plan, widths really do diverge, so
      // holding the topology is a property of the plan rather than of the
      // path being too simple to care. Same cap/join as _stroke — the
      // config test 1 anchors on — so this guards that configuration
      // specifically rather than a different one.
      final thin = StrokeOutliner(
        const StrokeProperties(
          width: 0.5,
          cap: LineCap.round,
          join: LineJoin.round,
        ),
      ).outline(commands);
      final thick = StrokeOutliner(
        const StrokeProperties(
          width: 6,
          cap: LineCap.round,
          join: LineJoin.round,
        ),
      ).outline(commands);

      expect(_segmentCounts(thin), isNot(_segmentCounts(thick)));
    });
  });
}
