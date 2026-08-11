import 'dart:math' as math;

import '../../otf/table/glyph/flag.dart';
import '../../otf/table/glyph/header.dart';
import '../../otf/table/glyph/simple.dart';
import '../../utils/misc.dart';
import '../../utils/otf.dart';
import 'generic_glyph_base.dart';

/// A repeat count is one byte, so a flag can stand for at most this many
/// further points.
const _kMaxFlagRepeat = 255;

/// Below this a run costs the same either way: two identical flag bytes, or
/// one flag byte plus a count.
const _kMinProfitableRun = 3;

/// Marks runs of identical flags so they encode as one byte plus a count.
///
/// TrueType lets a flag byte stand for the points that follow it. Icon
/// outlines are full of such runs — long stretches of on-curve points whose
/// deltas all fit in a byte — so this is most of what a `glyf` table can be
/// shrunk by without touching the geometry.
///
/// The returned list still holds one entry per point, which is the convention
/// [SimpleGlyph] expects: the first entry of a run carries the count and the
/// rest repeat it.
List<SimpleGlyphFlag> _compactRuns(List<SimpleGlyphFlag> flags) {
  final result = <SimpleGlyphFlag>[];

  var start = 0;

  while (start < flags.length) {
    final flag = flags[start];

    var length = 1;

    while (start + length < flags.length &&
        length <= _kMaxFlagRepeat &&
        flags[start + length].hasSameBits(flag)) {
      length++;
    }

    result.addAll(
      List.filled(
        length,
        length >= _kMinProfitableRun ? flag.repeated(length - 1) : flag,
      ),
    );

    start += length;
  }

  return result;
}

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

    final flags = _compactRuns([
      for (var i = 0; i < points.length; i++)
        SimpleGlyphFlag.createForPoint(relX[i], relY[i], isOnCurveList[i]),
    ]);

    return SimpleGlyph(
      header: GlyphHeader(
        numberOfContours: endPoints.length,
        xMin: absX.fold<int>(kInt32Max, math.min),
        yMin: absY.fold<int>(kInt32Max, math.min),
        xMax: absX.fold<int>(kInt32Min, math.max),
        yMax: absY.fold<int>(kInt32Min, math.max),
      ),
      endPtsOfContours: endPoints,
      instructions: [],
      flags: flags,
      pointList: points,
    );
  }
}
