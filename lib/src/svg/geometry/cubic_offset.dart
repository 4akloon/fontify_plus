import 'cubic.dart';
import 'offset_approximation.dart';
import 'offset_plan.dart';

/// Recursion cap, as a backstop behind the degeneracy check.
const _maxDepth = 8;

/// How close `distance * curvature` may come to 1 before the offset is treated
/// as degenerate.
///
/// The offset curve's speed is proportional to `1 - distance * curvature`, so
/// at 1 it stalls and beyond it reverses: the true offset grows a cusp and
/// doubles back on itself. No cubic tracks that, and subdividing only produces
/// more segments that each fail the same way.
const _degenerateCurvature = 0.95;

/// Parameters at which curvature is sampled when testing for degeneracy.
const _curvatureSamples = 8;

/// Approximates the offset of a cubic as a chain of cubics.
///
/// The offset of a cubic is not itself a cubic — it is generally a curve of
/// much higher degree — so it has to be approximated. Doing that directly beats
/// flattening the source to a polyline and refitting: the end points and end
/// tangents of the offset are known exactly, so only the control point
/// distances need solving, and the result tracks the true offset with far fewer
/// segments than fitting to sampled points ever recovers.
class CubicOffsetter {
  const CubicOffsetter({required this.distance, required this.tolerance});

  /// How far to the left of the source curve the offset runs. Negative offsets
  /// run to the right.
  final double distance;

  /// How far the result may stray from the true offset.
  final double tolerance;

  /// The offset of [curve], subdivided for this offsetter's own distance.
  List<Cubic> offset(Cubic curve) => plan(curve).evaluate(distance);

  /// How [curve] subdivides at this offsetter's distance, for replay at any
  /// other distance.
  OffsetPlan plan(Cubic curve) {
    final pieces = <OffsetPiece>[];

    _plan(curve, pieces, 0);

    return OffsetPlan(pieces);
  }

  void _plan(Cubic curve, List<OffsetPiece> out, int depth) {
    final candidate = approximateOffset(curve, distance);

    if (candidate != null &&
        (depth >= _maxDepth ||
            maxOffsetDeviation(curve, candidate, distance) <= tolerance)) {
      out.add(OffsetPiece(curve, chord: false));
      return;
    }

    // Inside a turn tighter than the offset itself there is no curve to
    // converge on. This is the normal case at a rounded corner narrower than
    // the stroke, not an error: the inner wall folds over itself and the
    // nonzero rule absorbs the overlap, so take the best approximation and
    // stop. Only stop when the *whole* piece has collapsed — a wave that
    // tightens at one end (alien-02's scallops) must still split, or the
    // healthy half becomes one chord and the outline goes triangular.
    if (_isFullyCollapsed(curve)) {
      out.add(OffsetPiece(curve, chord: candidate == null));
      return;
    }

    if (depth >= _maxDepth) {
      // No usable approximation and no budget left: fall back to the chord so
      // the contour stays closed rather than dropping a piece of the outline.
      out.add(OffsetPiece(curve, chord: true));
      return;
    }

    final (left, right) = curve.splitAt(0.5);

    _plan(left, out, depth + 1);
    _plan(right, out, depth + 1);
  }

  /// Whether offsetting [curve] collapses along its entire length.
  bool _isFullyCollapsed(Cubic curve) {
    for (var i = 0; i <= _curvatureSamples; i++) {
      final curvature = curve.curvatureAt(i / _curvatureSamples);

      if (distance * curvature < _degenerateCurvature) {
        return false;
      }
    }

    return true;
  }
}
