import 'dart:typed_data';

import 'flag.dart';

/// Which axis a coordinate pass is reading or writing.
///
/// A glyph stores all its x deltas and then all its y deltas, encoded by the
/// same rules against different flag bits — so the two passes are one piece of
/// code parameterized by the axis.
enum GlyphAxis {
  x,
  y;

  /// Whether this axis's delta is stored in one unsigned byte.
  bool isShort(SimpleGlyphFlag flag) =>
      this == GlyphAxis.x ? flag.xShortVector : flag.yShortVector;

  /// For a short delta this is its sign; otherwise it means the delta is zero.
  bool isSameOrPositive(SimpleGlyphFlag flag) =>
      this == GlyphAxis.x ? flag.xIsSameOrPositive : flag.yIsSameOrPositive;
}

/// Reads [count] relative coordinates for [axis], with the offset past them.
(List<int> coordinates, int offset) readCoordinates(
  ByteData byteData,
  int startOffset,
  List<SimpleGlyphFlag> flags,
  int count,
  GlyphAxis axis,
) {
  final coordinates = <int>[];
  var offset = startOffset;

  for (var i = 0; i < count; i++) {
    final flag = flags[i];
    final same = axis.isSameOrPositive(flag);

    if (axis.isShort(flag)) {
      coordinates.add((same ? 1 : -1) * byteData.getUint8(offset++));
      continue;
    }

    if (same) {
      coordinates.add(0);
      continue;
    }

    coordinates.add(byteData.getInt16(offset));
    offset += 2;
  }

  return (coordinates, offset);
}

/// Writes [count] relative coordinates for [axis], returning the offset past
/// them.
int writeCoordinates(
  ByteData byteData,
  int startOffset,
  List<SimpleGlyphFlag> flags,
  List<int> coordinates,
  int count,
  GlyphAxis axis,
) {
  var offset = startOffset;

  for (var i = 0; i < count; i++) {
    final flag = flags[i];

    if (axis.isShort(flag)) {
      // The sign lives in the flag, so only the magnitude is stored.
      byteData.setUint8(offset++, coordinates[i].abs());
      continue;
    }

    // A "same" flag on a long delta means zero, which takes no bytes.
    if (!axis.isSameOrPositive(flag)) {
      byteData.setInt16(offset, coordinates[i]);
      offset += 2;
    }
  }

  return offset;
}
