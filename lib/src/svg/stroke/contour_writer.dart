import '../geometry/cubic.dart';
import '../geometry/tolerances.dart';

/// How far a control point may sit off the chord before the segment stops
/// counting as straight.
const _kStraightTolerance = kCurveTolerance / 4;

/// Serializes closed contours as SVG path data.
class ContourWriter {
  const ContourWriter();

  String write(List<List<Cubic>> contours) {
    final buffer = StringBuffer();

    for (final contour in contours) {
      if (contour.isEmpty) {
        continue;
      }

      final start = contour.first.p0;
      buffer.write('M${_coordinate(start.x)} ${_coordinate(start.y)}');

      for (final segment in contour) {
        _writeSegment(buffer, segment);
      }

      buffer.write('Z');
    }

    return buffer.toString();
  }

  void _writeSegment(StringBuffer buffer, Cubic segment) {
    if (_isStraight(segment)) {
      buffer
          .write('L${_coordinate(segment.p3.x)} ${_coordinate(segment.p3.y)}');
      return;
    }

    buffer.write(
      'C${_coordinate(segment.p1.x)} ${_coordinate(segment.p1.y)} '
      '${_coordinate(segment.p2.x)} ${_coordinate(segment.p2.y)} '
      '${_coordinate(segment.p3.x)} ${_coordinate(segment.p3.y)}',
    );
  }

  /// Whether a cubic's controls lie on its chord, so it can be written as a
  /// line.
  ///
  /// Joins and caps produce plenty of straight pieces; spending six coordinates
  /// on each would undo much of what offsetting curves directly buys.
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

      if (perpendicular > _kStraightTolerance || along < 0 || along > length) {
        return false;
      }
    }

    return true;
  }

  /// Trims float noise so the emitted path data stays readable and compact.
  String _coordinate(double value) {
    final rounded = double.parse(value.toStringAsFixed(4));

    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }
}
