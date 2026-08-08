import '../geometry/cubic.dart';
import '../geometry/cubic_offset.dart';
import '../geometry/tolerances.dart';
import 'contour_writer.dart';
import 'stroke_capper.dart';
import 'stroke_joiner.dart';
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
        ),
        _joiner = StrokeJoiner(stroke),
        _capper = StrokeCapper(stroke);

  final StrokeProperties stroke;

  final CubicOffsetter _offsetter;
  final StrokeJoiner _joiner;
  final StrokeCapper _capper;

  static const _writer = ContourWriter();

  /// Path data for the covered region, or null when [pathData] contains
  /// nothing strokeable.
  String? outline(String pathData) {
    final contours = [
      for (final subPath in SubPathBuilder().build(pathData))
        ..._outlineSubPath(subPath),
    ];

    return contours.isEmpty ? null : _writer.write(contours);
  }

  /// The filled contours covering one stroked subpath.
  List<List<Cubic>> _outlineSubPath(SubPath subPath) {
    if (subPath.segments.isEmpty) {
      return const [];
    }

    if (subPath.closed) {
      // A closed stroke is an annulus: the outer wall and the inner wall,
      // wound opposite so the nonzero rule leaves the middle hollow.
      return [
        _offsetSide(subPath.segments, closed: true),
        _offsetSide(subPath.reversedSegments, closed: true),
      ];
    }

    // An open stroke is a single loop: up one side, around the end cap, back
    // down the other side, around the start cap.
    final forward = subPath.segments;
    final backward = subPath.reversedSegments;

    return [
      <Cubic>[
        ..._offsetSide(forward, closed: false),
        ..._capAfter(forward),
        ..._offsetSide(backward, closed: false),
        ..._capAfter(backward),
      ],
    ];
  }

  List<Cubic> _capAfter(List<Cubic> segments) =>
      _capper.cap(segments.last.p3, segments.last.tangentAt(1));

  /// Offsets a chain of segments to its left, inserting join geometry.
  List<Cubic> _offsetSide(List<Cubic> segments, {required bool closed}) {
    final result = <Cubic>[];

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final offset = _offsetter.offset(segment);

      if (offset.isEmpty) {
        continue;
      }

      if (result.isNotEmpty) {
        result.addAll(
          _joiner.join(
            vertex: segment.p0,
            from: result.last.p3,
            to: offset.first.p0,
            incoming: segments[i - 1].tangentAt(1),
            outgoing: segment.tangentAt(0),
          ),
        );
      }

      result.addAll(offset);
    }

    if (closed && result.isNotEmpty) {
      // Close the ring by joining the last segment back to the first.
      result.addAll(
        _joiner.join(
          vertex: segments.first.p0,
          from: result.last.p3,
          to: result.first.p0,
          incoming: segments.last.tangentAt(1),
          outgoing: segments.first.tangentAt(0),
        ),
      );
    }

    return result;
  }
}
