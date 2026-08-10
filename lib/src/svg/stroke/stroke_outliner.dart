import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import '../geometry/cubic.dart';
import '../geometry/cubic_offset.dart';
import '../geometry/tolerances.dart';
import 'stroke_plan.dart';
import 'stroke_properties.dart';
import 'sub_path.dart';

/// Converts a stroked SVG path into the filled region that the stroke covers.
///
/// Font glyphs have no stroke — an outline is either filled or it is invisible.
/// A stroked path handed straight to the rasterizer collapses to its zero-area
/// centreline, which is why outline-style icon sets come out blank or hairline
/// thin without this step.
///
/// The result relies on the nonzero winding rule rather than a boolean union:
/// overlapping contours wound the same way merge when filled, so crossing
/// subpaths (a plus sign, an X) need no clipping pass. Contours are emitted in
/// consistent orientation to make that hold.
class StrokeOutliner {
  StrokeOutliner(this.stroke)
    : _offsetter = CubicOffsetter(
        distance: stroke.radius,
        tolerance: kCurveTolerance,
      );

  final StrokeProperties stroke;

  final CubicOffsetter _offsetter;

  /// The closed contours covering the stroke of [commands].
  List<List<Cubic>> outline(Iterable<vg.PathCommand> commands) =>
      plan(commands).evaluate(stroke.width);

  /// The topology of [commands] stroked at this outliner's width, for
  /// redrawing at any other width.
  StrokePlan plan(Iterable<vg.PathCommand> commands) => StrokePlan(
    stroke: stroke,
    subPaths: [
      for (final subPath in SubPathBuilder().build(commands))
        SubPathPlan(
          subPath: subPath,
          forward: [
            for (final segment in subPath.segments) _offsetter.plan(segment),
          ],
          backward: [
            for (final segment in subPath.reversedSegments)
              _offsetter.plan(segment),
          ],
        ),
    ],
  );
}
