import 'dart:math';

import '../utils/bezier.dart';
import '../utils/misc.dart';

/// How shapes with more than one closed outlines are filled.
///
/// * CharStrings must always be the nonzero
/// * TrueType is either always nonzero
/// or evenodd/nonzero according to OVERLAP_SIMPLE flag
/// (depending on rasterizer implementation)
/// * SVG can be both
enum FillRule { nonzero, evenodd }

/// One closed contour, stored the way both target formats want it.
///
/// The representation is deliberately not a segment list: points and their
/// on-curve flags are parallel arrays because that is exactly how TrueType's
/// `glyf` stores a contour, and it is what the charstring encoder walks. A
/// segment-based path would have to be flattened back into this shape by both
/// encoders, so it would buy expressiveness at the cost of a conversion on
/// every write.
///
/// The two flags below record which of four states the arrays are in. Both
/// encoders require a specific one, and the conversions between them are the
/// methods on this class.
class Outline {
  Outline({
    required this.pointList,
    required this.isOnCurveList,
    required bool hasCompactCurves,
    required bool hasQuadCurves,
    required this.fillRule,
  }) : _hasCompactCurves = hasCompactCurves,
       _hasQuadCurves = hasQuadCurves;

  final List<Point<num>> pointList;
  final List<bool> isOnCurveList;
  final FillRule fillRule;

  /// Indicates weather curves are compact (midpoints and endpoint are implicit)
  bool _hasCompactCurves;
  bool get hasCompactCurves => _hasCompactCurves;

  /// Indicates weather outline contains quadratic or cubic curves
  bool _hasQuadCurves;
  bool get hasQuadCurves => _hasQuadCurves;

  /// Deep copy of an outline
  Outline copy() {
    return Outline(
      pointList: [...pointList],
      isOnCurveList: [...isOnCurveList],
      hasCompactCurves: _hasCompactCurves,
      hasQuadCurves: _hasQuadCurves,
      fillRule: fillRule,
    );
  }

  /// Decompacts implicit points of quadratic curves (midpoints and end points)
  void decompactImplicitPoints() {
    if (!hasCompactCurves) {
      return;
    }

    if (!hasQuadCurves) {
      throw UnsupportedError('Only quadratic curves supported');
    }

    // Starting with 2, because first point can't be a CP and we need 2 of them
    for (var i = 2; i < pointList.length; i++) {
      // Two control points in a row
      if (!isOnCurveList[i - 1] && !isOnCurveList[i]) {
        final c0 = pointList[i - 1];
        final c1 = pointList[i];

        // Calculating midpoint
        final midpoint = (c0 + c1) * .5;

        // Adding midpoint to the list and moving to the next point
        pointList.insert(i, midpoint);
        isOnCurveList.insert(i, true);
        i++;
      }
    }

    // Last point is CP - duplicating start point
    if (!isOnCurveList.last) {
      isOnCurveList.add(true);
      pointList.add(pointList.first);
    }

    _hasCompactCurves = false;
  }

  /// Compacts implicit points of quadratic curves (midpoints and end points)
  void compactImplicitPoints() {
    if (!hasQuadCurves) {
      throw UnsupportedError('Only quadratic curves supported');
    }

    if (hasCompactCurves) {
      return;
    }

    // Starting with 2, because first point can't be a CP and we need 2 of them
    for (var i = 2; i < pointList.length; i++) {
      // Two control points in a row
      if (!isOnCurveList[i - 1] &&
          i + 1 < pointList.length &&
          !isOnCurveList[i + 1]) {
        final c0 = pointList[i - 1];
        final p0 = pointList[i];
        final c1 = pointList[i + 1];

        // Calculating midpoint
        final midpoint = (c0 + c1) * .5;

        // Point on curve equals calculated midpoint
        if (midpoint.toIntPoint() == p0.toIntPoint()) {
          pointList.removeAt(i);
          isOnCurveList.removeAt(i);
        }
      }
    }

    // Last point and end point are same
    if (pointList.length > 1 &&
        pointList.first.toIntPoint() == pointList.last.toIntPoint()) {
      pointList.removeLast();
      isOnCurveList.removeLast();
    }

    _hasCompactCurves = true;
  }

  /// Converts every cubic bezier to quadratic ones.
  ///
  /// TrueType's `glyf` stores quadratics only, so a contour that came from SVG
  /// — which is cubic — has to be approximated before it can be written. The
  /// result stays within [tolerance] of the original, which defaults to half a
  /// font unit: below the integer grid the coordinates are rounded to anyway.
  ///
  /// A cubic segment usually becomes more than one quadratic, so the contour
  /// grows a few points.
  void cubicToQuad({
    double tolerance = kQuadraticApproximationTolerance,
  }) {
    if (hasQuadCurves) {
      return;
    }

    if (hasCompactCurves) {
      throw UnsupportedError("Outline mustn't contain compact curves");
    }

    final points = <Point<num>>[pointList.first];
    final isOnCurve = <bool>[true];

    var i = 0;

    while (i < pointList.length - 1) {
      if (isOnCurveList[i + 1]) {
        // A straight segment carries over unchanged.
        points.add(pointList[i + 1]);
        isOnCurve.add(true);
        i++;
        continue;
      }

      if (i + 2 >= pointList.length || isOnCurveList[i + 2]) {
        throw StateError('Cubic segment must have two control points');
      }

      // The last segment of a closed contour ends back at its start, which is
      // left implicit.
      final end = i + 3 < pointList.length ? pointList[i + 3] : pointList.first;

      final quadratics = cubicCurveToQuadratics(
        pointList[i],
        pointList[i + 1],
        pointList[i + 2],
        end,
        tolerance,
      );

      for (final quadratic in quadratics) {
        points.addAll([quadratic.control, quadratic.end]);
        isOnCurve.addAll([false, true]);
      }

      i += 3;
    }

    pointList
      ..clear()
      ..addAll(points);
    isOnCurveList
      ..clear()
      ..addAll(isOnCurve);

    _hasQuadCurves = true;
  }

  /// Converts every quadratic bezier to a cubic one.
  ///
  /// Assumes the contour is already decompacted (see
  /// [decompactImplicitPoints]) and so ends on-curve: a contour ending
  /// off-curve closes back to its own start without that point ever being
  /// written down, and this only reconstructs it by looking one point ahead —
  /// which requires that point to exist.
  void quadToCubic() {
    if (hasCompactCurves) {
      throw UnsupportedError('Outline mustn\'t contain compact curves');
    }

    if (!hasQuadCurves) {
      return;
    }

    // Starting with 1, because first point can't be a CP
    for (var i = 1; i < pointList.length; i++) {
      if (isOnCurveList[i]) {
        continue;
      }

      final qp0 = pointList[i - 1];
      final qp1 = pointList[i];
      final qp2 = i + 1 < pointList.length ? pointList[i + 1] : pointList.first;

      pointList.replaceRange(i, i + 1, quadCurveToCubic(qp0, qp1, qp2));
      isOnCurveList.insert(i, false);
      i++;
    }

    _hasQuadCurves = false;
  }
}
