import 'dart:math' as math;

import '../../otf/table/glyph/flag.dart';
import '../../otf/table/glyph/header.dart';
import '../../otf/table/glyph/simple.dart';
import '../../utils/misc.dart';
import '../../utils/otf.dart';
import 'generic_glyph_base.dart';

/// Turns a glyph's contours into a TrueType `glyf` entry.
extension GlyphTrueTypeEncoding on GenericGlyph {
  SimpleGlyph toSimpleTrueTypeGlyph() {
    final points = pointList;
    final isOnCurveList = this.isOnCurveList;
    final endPoints = this.endPoints;

    final absX = [for (final p in points) p.x.toInt()];
    final absY = [for (final p in points) p.y.toInt()];

    final relX = absToRelCoordinates(absX);
    final relY = absToRelCoordinates(absY);

    final flags = [
      for (var i = 0; i < points.length; i++)
        SimpleGlyphFlag.createForPoint(relX[i], relY[i], isOnCurveList[i]),
    ];

    // TODO: compact flags: repeat & not short same flag

    return SimpleGlyph(
      GlyphHeader(
        endPoints.length,
        absX.fold<int>(kInt32Max, math.min),
        absY.fold<int>(kInt32Max, math.min),
        absX.fold<int>(kInt32Min, math.max),
        absY.fold<int>(kInt32Min, math.max),
      ),
      endPoints,
      [],
      flags,
      points,
    );
  }
}
