import 'cubic.dart';
import 'offset_approximation.dart';

/// One emitted offset segment: which piece of the source curve it covers, and
/// which approximation was chosen for it.
class OffsetPiece {
  const OffsetPiece(this.curve, {required this.chord});

  /// The already-subdivided piece of the source curve.
  final Cubic curve;

  /// Whether the approximation collapsed to the chord between the offset end
  /// points.
  final bool chord;

  /// The offset of [curve] at [distance].
  Cubic evaluate(double distance) {
    if (chord) {
      return offsetChord(curve, distance);
    }

    // Planned as a curve, so a curve is what the point count expects. The
    // approximation can still decline at a distance it was not planned for;
    // the chord keeps the contour closed and, being one cubic either way,
    // leaves the point count alone.
    return approximateOffset(curve, distance) ?? offsetChord(curve, distance);
  }
}

/// How one source cubic was cut up when offset at a reference distance.
///
/// Subdivision depth depends on the offset distance, so re-deriving it per
/// width would give each master its own point count and make them
/// un-interpolatable. Recording it once and replaying it makes point
/// compatibility a property of construction.
class OffsetPlan {
  const OffsetPlan(this.pieces);

  /// The pieces the source curve was cut into, in order along the curve.
  final List<OffsetPiece> pieces;

  /// The offset at [distance], replaying the recorded subdivision rather
  /// than re-deriving it.
  List<Cubic> evaluate(double distance) => [
    for (final piece in pieces) piece.evaluate(distance),
  ];
}
