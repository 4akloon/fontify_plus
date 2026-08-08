import '../../otf/cff/char_string.dart';
import '../../otf/cff/char_string_optimizer.dart';
import '../../utils/logger.dart';
import '../../utils/otf.dart';
import '../outline.dart';
import 'generic_glyph_base.dart';

/// Turns a glyph's contours into CFF charstring commands.
extension GlyphCharStringEncoding on GenericGlyph {
  List<CharStringCommand> toCharStringCommands(CharStringOptimizer optimizer) {
    _checkOutlines();

    final commandList = <CharStringCommand>[];

    final isOnCurveList = this.isOnCurveList;
    final endPoints = this.endPoints;
    final points = pointList;

    final relX = absToRelCoordinates([for (final p in points) p.x.toInt()]);
    final relY = absToRelCoordinates([for (final p in points) p.y.toInt()]);

    var isContourStart = true;

    for (var i = 0; i < relX.length; i++) {
      if (isContourStart) {
        commandList.add(shortestMoveto(relX[i], relY[i]));
        isContourStart = false;
        continue;
      }

      if (!isOnCurveList[i] && !isOnCurveList[i + 1]) {
        commandList.add(
          shortestCurveto([
            for (var p = 0; p < 3; p++) ...[relX[i + p], relY[i + p]],
          ]),
        );
        i += 2;
      } else {
        commandList.add(shortestLineto(relX[i], relY[i]));
      }

      if (endPoints.isNotEmpty && endPoints.first == i) {
        endPoints.removeAt(0);
        isContourStart = true;
      }
    }

    return optimizer.optimize(commandList);
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
