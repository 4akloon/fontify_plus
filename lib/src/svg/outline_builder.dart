import 'dart:math' as math;

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import '../common/outline.dart';
import 'geometry/cubic.dart';
import 'geometry/tolerances.dart';

/// How far a control point may sit off the chord before the segment stops
/// counting as straight.
const _kStraightTolerance = kCurveTolerance / 4;

/// Builds [Outline]s from `vector_graphics_compiler` path commands.
///
/// [height] is the viewport height. vgc has already folded the viewBox
/// minimum into the coordinates, so flipping onto the font's y-up axis is a
/// plain subtraction.
List<Outline> outlinesFromCommands(
  Iterable<vg.PathCommand> commands, {
  required double height,
  required FillRule fillRule,
}) {
  final contours = _ContourAccumulator(height, fillRule);

  for (final command in commands) {
    switch (command) {
      case vg.MoveToCommand(:final x, :final y):
        // A moveTo starts a new subpath. Without flushing here, a path such as
        // "M8 2V13 M13 8H2" — two separate strokes, no Z — accumulates into a
        // single outline and renders as one zigzag contour.
        contours
          ..flush()
          ..addOnCurve(x, y);
      case vg.LineToCommand(:final x, :final y):
        contours.addOnCurve(x, y);
      case vg.CubicToCommand(
        :final x1,
        :final y1,
        :final x2,
        :final y2,
        :final x3,
        :final y3,
      ):
        contours
          ..addOffCurve(x1, y1)
          ..addOffCurve(x2, y2)
          ..addOnCurve(x3, y3);
      case vg.CloseCommand():
        // The closing segment is implicit: the start point is not repeated.
        contours.flush();
    }
  }

  return contours.finish();
}

/// Builds [Outline]s from the closed cubic contours the stroke outliner emits.
///
/// The fill rule is always [FillRule.nonzero]. Overlapping walls are merged by
/// the nonzero rule rather than by a boolean union, which is what lets crossing
/// subpaths be emitted without a clipping pass; inheriting `evenodd` from the
/// source path would punch those overlaps back out as holes.
List<Outline> outlinesFromContours(
  List<List<Cubic>> contours, {
  required double height,
}) {
  final accumulator = _ContourAccumulator(height, FillRule.nonzero);

  for (final contour in contours) {
    if (contour.isEmpty) {
      continue;
    }

    accumulator
      ..flush()
      ..addOnCurve(contour.first.p0.x, contour.first.p0.y);

    for (final segment in contour) {
      if (_isStraight(segment)) {
        accumulator.addOnCurve(segment.p3.x, segment.p3.y);
        continue;
      }

      accumulator
        ..addOffCurve(segment.p1.x, segment.p1.y)
        ..addOffCurve(segment.p2.x, segment.p2.y)
        ..addOnCurve(segment.p3.x, segment.p3.y);
    }

    // The outliner closes a ring by joining its last segment back to the
    // first, so the final point repeats the start. A contour's closing
    // segment is implicit: keeping the repeat costs a point in every stroked
    // contour and would not match what `outlinesFromCommands` emits for `Z`.
    accumulator.dropRepeatedStart();
  }

  return accumulator.finish();
}

/// Whether a cubic's controls lie on its chord, so it carries no curvature.
///
/// Joins and caps produce plenty of straight pieces; spending three points on
/// each would triple the point count of every stroked glyph.
bool _isStraight(Cubic segment) {
  final chord = segment.p3 - segment.p0;
  final length = chord.length;

  if (length <= kPointEpsilon) {
    return true;
  }

  final direction = chord / length;

  for (final control in [segment.p1, segment.p2]) {
    final offset = control - segment.p0;
    final along = offset.dot(direction);
    final perpendicular = (offset - direction * along).length;

    // The bounds carry the same slack as the perpendicular test. A cubic with
    // flat ends (p1 == p0, p2 == p3) computes `along` for p2 as
    // |chord|^2 / |chord|, which lands an ulp above `length` about half the
    // time; without slack such a segment is called curved and costs three
    // points instead of one — the exact blow-up this test exists to prevent.
    if (perpendicular > _kStraightTolerance ||
        along < -_kStraightTolerance ||
        along > length + _kStraightTolerance) {
      return false;
    }
  }

  return true;
}

/// Collects points into contours, flipping y as they arrive.
class _ContourAccumulator {
  _ContourAccumulator(this._height, this._fillRule);

  final double _height;
  final FillRule _fillRule;

  final _outlines = <Outline>[];
  final _points = <math.Point<num>>[];
  final _isOnCurve = <bool>[];

  void addOnCurve(double x, double y) => _add(x, y, true);

  void addOffCurve(double x, double y) => _add(x, y, false);

  /// Ends the current contour, if it holds any points.
  void flush() {
    if (_points.isEmpty) {
      return;
    }

    _outlines.add(
      Outline([..._points], [..._isOnCurve], false, false, _fillRule),
    );

    _points.clear();
    _isOnCurve.clear();
  }

  /// Drops the open contour's last point when it repeats the first.
  ///
  /// Only an on-curve point is a candidate: an off-curve control that happens
  /// to land on the start is a real control point, not a closing repeat.
  void dropRepeatedStart() {
    // Below three points there is no contour left to shorten: dropping from
    // two to one would hand the encoders a single-point outline.
    if (_points.length < 3 || !_isOnCurve.last) {
      return;
    }

    // Only a contour closed by a straight line may leave its last point
    // implicit. CFF closes a charstring path with a straight line, so when the
    // closing segment is a curve its end point has to be written down. The
    // charstring encoder needs it for a second reason too: it walks one flat
    // point list across every contour and reads one flag past each curve's
    // start, so a contour ending off-curve either runs off the end or steals
    // the next contour's first point.
    if (!_isOnCurve[_points.length - 2]) {
      return;
    }

    final first = _points.first;
    final last = _points.last;

    if ((first.x - last.x).abs() <= kPointEpsilon &&
        (first.y - last.y).abs() <= kPointEpsilon) {
      _points.removeLast();
      _isOnCurve.removeLast();
    }
  }

  /// Flushes whatever is open and returns every contour collected.
  List<Outline> finish() {
    flush();
    return _outlines;
  }

  void _add(double x, double y, bool onCurve) {
    _points.add(math.Point<num>(x, _height - y));
    _isOnCurve.add(onCurve);
  }
}
