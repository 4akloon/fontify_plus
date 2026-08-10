import '../geometry/cubic.dart';
import '../geometry/offset_plan.dart';
import 'stroke_capper.dart';
import 'stroke_joiner.dart';
import 'stroke_properties.dart';
import 'sub_path.dart';

/// One subpath's recorded subdivision, both ways round.
class SubPathPlan {
  const SubPathPlan({
    required this.subPath,
    required this.forward,
    required this.backward,
  });

  final SubPath subPath;

  /// One plan per segment of [SubPath.segments].
  final List<OffsetPlan> forward;

  /// One plan per segment of [SubPath.reversedSegments].
  final List<OffsetPlan> backward;
}

/// A stroked path's topology, fixed once so it can be drawn at any width.
///
/// Joins and caps are not recorded: every branch they take is a ratio against
/// the stroke radius or a test on the source curve's tangents, so re-running
/// them at another width takes the same branch. Only the offsetter's
/// subdivision depends on the width, and that is what [SubPathPlan] holds.
class StrokePlan {
  const StrokePlan({required this.stroke, required this.subPaths});

  /// Cap, join and miter limit; its width is the width the plan was made at.
  final StrokeProperties stroke;

  final List<SubPathPlan> subPaths;

  /// The closed contours covering the stroke at [width].
  ///
  /// Empty when the plan holds nothing strokeable.
  List<List<Cubic>> evaluate(double width) {
    // [stroke] with its width replaced: joins and caps read cap, join and
    // miterLimit from this, and the radius that scales them follows from
    // [width] rather than the width the plan was made at.
    final target = StrokeProperties(
      width: width,
      cap: stroke.cap,
      join: stroke.join,
      miterLimit: stroke.miterLimit,
    );

    // Every branch a joiner or capper takes is width-invariant (a tangent
    // test, or a ratio against the radius), so building fresh ones for
    // [target] reproduces the same structure the plan was made with, just
    // scaled to the new radius.
    final joiner = StrokeJoiner(target);
    final capper = StrokeCapper(target);

    return [
      for (final subPath in subPaths)
        ..._outlineSubPath(subPath, target, joiner, capper),
    ];
  }

  /// The filled contours covering one stroked subpath.
  List<List<Cubic>> _outlineSubPath(
    SubPathPlan subPath,
    StrokeProperties target,
    StrokeJoiner joiner,
    StrokeCapper capper,
  ) {
    if (subPath.subPath.segments.isEmpty) {
      return const [];
    }

    if (subPath.subPath.closed) {
      // A closed stroke is an annulus: the outer wall and the inner wall,
      // wound opposite so the nonzero rule leaves the middle hollow.
      return [
        _offsetSide(
          subPath.subPath.segments,
          subPath.forward,
          target,
          joiner,
          closed: true,
        ),
        _offsetSide(
          subPath.subPath.reversedSegments,
          subPath.backward,
          target,
          joiner,
          closed: true,
        ),
      ];
    }

    // An open stroke is a single loop: up one side, around the end cap, back
    // down the other side, around the start cap.
    final forward = subPath.subPath.segments;
    final backward = subPath.subPath.reversedSegments;

    return [
      <Cubic>[
        ..._offsetSide(forward, subPath.forward, target, joiner, closed: false),
        ..._capAfter(forward, capper),
        ..._offsetSide(
          backward,
          subPath.backward,
          target,
          joiner,
          closed: false,
        ),
        ..._capAfter(backward, capper),
      ],
    ];
  }

  List<Cubic> _capAfter(List<Cubic> segments, StrokeCapper capper) =>
      capper.cap(segments.last.p3, segments.last.tangentAt(1));

  /// Offsets a chain of segments to its left, inserting join geometry.
  ///
  /// [offsets] holds one recorded [OffsetPlan] per entry of [segments], in
  /// the same order, so this replays the subdivision recorded when the plan
  /// was made rather than re-deriving it at [target]'s radius.
  List<Cubic> _offsetSide(
    List<Cubic> segments,
    List<OffsetPlan> offsets,
    StrokeProperties target,
    StrokeJoiner joiner, {
    required bool closed,
  }) {
    final result = <Cubic>[];

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final offset = offsets[i].evaluate(target.radius);

      if (offset.isEmpty) {
        continue;
      }

      if (result.isNotEmpty) {
        result.addAll(
          joiner.join(
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
        joiner.join(
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
