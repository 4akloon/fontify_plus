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
  ///
  /// Tries a cubic approximation first even when this piece was recorded as a
  /// chord. The chord is what the planning distance had to emit — typically
  /// an inner wall whose curvature collapsed at that width — but a narrower
  /// evaluation of the same piece is often a well-behaved cubic. Freezing the
  /// chord made every narrower master inherit a polygonal inner wall
  /// (account-setting-03 at 1.5 from a plan built at 3.0).
  Cubic evaluate(double distance) =>
      approximateOffset(curve, distance) ?? offsetChord(curve, distance);
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
