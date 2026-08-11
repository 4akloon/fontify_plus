import '../../otf/cff/char_string.dart';
import '../../otf/cff/char_string_optimizer.dart';
import '../../utils/logger.dart';
import '../../utils/otf.dart';
import '../outline.dart';
import 'generic_glyph_base.dart';

/// Turns a glyph's contours into CFF charstring commands.
extension GlyphCharStringEncoding on GenericGlyph {
  /// Turns this glyph's contours into CFF charstring commands.
  List<CharStringCommand> toCharStringCommands(CharStringOptimizer optimizer) =>
      toCharStringCommandsForMasters([this], optimizer).single;

  /// Encodes every master of one glyph into structurally identical command
  /// streams — same operators, same operand counts, in the same order.
  ///
  /// The masters must already be point-compatible; `checkMastersCompatible`
  /// is what establishes that. What this adds is that the *encoding* of those
  /// compatible points is also common: every operator choice below is made
  /// from all masters at once rather than from each master's own coordinates,
  /// because the shorthand forms encode a dropped delta as an implicit zero
  /// and would otherwise discard a movement one master makes and another does
  /// not.
  ///
  /// With a single master every joint test reduces to that master's own, so
  /// this reproduces the previous encoder exactly.
  List<List<CharStringCommand>> toCharStringCommandsForMasters(
    List<GenericGlyph> masters,
    CharStringOptimizer optimizer,
  ) {
    if (masters.isEmpty) {
      throw ArgumentError('At least one master is required');
    }

    for (final master in masters) {
      master._checkOutlines();
    }

    // Every point accessor rebuilds its list per call, so each is read once.
    final pointLists = [for (final master in masters) master.pointList];
    final pointCount = pointLists.first.length;

    for (final points in pointLists) {
      if (points.length != pointCount) {
        throw ArgumentError(
          'Masters must share a point count: $pointCount vs ${points.length}',
        );
      }
    }

    // One relative-coordinate pair per master, all the same length.
    final rel = [
      for (final points in pointLists)
        (
          x: absToRelCoordinates([for (final p in points) p.x.toInt()]),
          y: absToRelCoordinates([for (final p in points) p.y.toInt()]),
        ),
    ];

    // Structure — which points are on-curve, where contours end — is shared,
    // so it is read from the first master only. `endPoints` is consumed by the
    // loop below, which is safe precisely because the getter is a fresh list.
    final isOnCurveList = masters.first.isOnCurveList;
    final endPoints = masters.first.endPoints;

    final commandLists = [
      for (var m = 0; m < masters.length; m++) <CharStringCommand>[],
    ];

    /// The flat delta list of the [count]-point segment starting at [i], for
    /// each master.
    List<List<int>> deltasAt(int i, int count) => [
      for (final r in rel)
        [
          for (var p = 0; p < count; p++) ...[r.x[i + p], r.y[i + p]],
        ],
    ];

    void emit(CharStringForm form, List<List<int>> deltas) {
      for (var m = 0; m < masters.length; m++) {
        commandLists[m].add(
          CharStringCommand(form.operator, [
            for (final index in form.operandIndices)
              CharStringOperand(deltas[m][index]),
          ]),
        );
      }
    }

    var isContourStart = true;

    for (var i = 0; i < pointCount; i++) {
      if (isContourStart) {
        final deltas = deltasAt(i, 1);
        emit(movetoForm(deltas), deltas);
        isContourStart = false;
        continue;
      }

      if (!isOnCurveList[i] && !isOnCurveList[i + 1]) {
        final deltas = deltasAt(i, 3);
        emit(curvetoForm(deltas), deltas);
        i += 2;
      } else {
        final deltas = deltasAt(i, 1);
        emit(linetoForm(deltas), deltas);
      }

      if (endPoints.isNotEmpty && endPoints.first == i) {
        endPoints.removeAt(0);
        isContourStart = true;
      }
    }

    return optimizer.optimizeMasters(commandLists);
  }

  void _checkOutlines() {
    for (final outline in outlines) {
      if (outline.hasQuadCurves) {
        // NOTE: what about doing it implicitly?
        throw UnsupportedError('CharString outlines must contain cubic curves');
      }

      // The encoder below reads one flag past each curve's start, so a contour
      // ending off-curve runs off the point list or steals the next contour's
      // first point. CFF also closes a path with a straight line, so a curve's
      // end point can never be left implicit.
      if (outline.isOnCurveList.isNotEmpty && !outline.isOnCurveList.last) {
        throw UnsupportedError(
          'CharString contours must end with an on-curve point',
        );
      }

      if (outline.fillRule == FillRule.evenodd) {
        logger.logOnce(
          Level.warning,
          'Some of the outlines are using even-odd fill rule. Make sure using '
          'a non-zero winding number fill rule for OpenType outlines.',
        );
      }
    }
  }
}
