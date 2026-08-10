import 'package:fontify_plus/src/svg/stroke/stroke_outliner.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// A rounded, curved, self-crossing path — every join and cap kind at once.
const _pathData = 'M2 12C2 6 6 2 12 2C18 2 22 6 22 12M6 18L18 6M6 6L18 18';

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
    final commands = vg.parseSvgPathData(_pathData).commands;

    test('evaluating at the planning width reproduces outline()', () {
      final outliner = StrokeOutliner(_stroke);

      final direct = outliner.outline(commands);
      final planned = outliner.plan(commands).evaluate(_stroke.width);

      expect(_segmentCounts(planned), _segmentCounts(direct));

      for (var c = 0; c < direct.length; c++) {
        for (var s = 0; s < direct[c].length; s++) {
          expect(planned[c][s].p0.distanceTo(direct[c][s].p0), lessThan(1e-9));
          expect(planned[c][s].p3.distanceTo(direct[c][s].p3), lessThan(1e-9));
        }
      }
    });

    test('holds its topology across the whole width range', () {
      final plan = StrokeOutliner(_stroke).plan(commands);
      final reference = _segmentCounts(plan.evaluate(2));

      for (final width in [0.5, 1.0, 1.33, 1.5, 2.0, 3.0]) {
        expect(
          _segmentCounts(plan.evaluate(width)),
          reference,
          reason: 'topology changed at width $width',
        );
      }
    });

    test('an unplanned outliner still subdivides differently per width', () {
      // Guards the test above: without a plan, widths really do diverge, so
      // holding the topology is a property of the plan rather than of the
      // path being too simple to care.
      final thin = StrokeOutliner(
        const StrokeProperties(width: 0.5, cap: LineCap.round),
      ).outline(commands);
      final thick = StrokeOutliner(
        const StrokeProperties(width: 6, cap: LineCap.round),
      ).outline(commands);

      expect(_segmentCounts(thin), isNot(_segmentCounts(thick)));
    });
  });
}
