import 'dart:math' as math;
import 'dart:typed_data';

import '../../common/codable/binary.dart';
import '../../common/generic_glyph.dart';
import '../../utils/misc.dart';
import '../../utils/otf.dart';

import 'abstract.dart';
import 'hhea.dart';
import 'table_record_entry.dart';

const _kLongHorMetricSize = 4;

class LongHorMetric implements BinaryCodable {
  LongHorMetric(this.advanceWidth, this.lsb);

  factory LongHorMetric.fromByteData(ByteData byteData, int offset) {
    return LongHorMetric(
      byteData.getUint16(offset),
      byteData.getInt16(offset + 2),
    );
  }

  /// [advanceWidthOverride], when given, replaces the width that would
  /// otherwise be derived from [metrics] — used when a glyph must advance by
  /// a fixed amount (e.g. a full em) regardless of how much of it its own
  /// ink fills. [lsb] always tracks the glyph's real [GenericGlyphMetrics.xMin]
  /// so it stays equal to `glyf.xMin`, which TrueType requires.
  factory LongHorMetric.createForGlyph(
    GenericGlyphMetrics metrics,
    int unitsPerEm, {
    int? advanceWidthOverride,
  }) {
    if (advanceWidthOverride != null) {
      return LongHorMetric(advanceWidthOverride, metrics.xMin);
    }

    if (metrics.width == 0) {
      return LongHorMetric(unitsPerEm ~/ 3, metrics.xMin);
    }

    return LongHorMetric(metrics.width, metrics.xMin);
  }

  final int advanceWidth;
  final int lsb;

  int getRsb(int xMax, int xMin) => advanceWidth - (lsb + xMax - xMin);

  @override
  int get size => _kLongHorMetricSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, advanceWidth)
      ..setInt16(2, lsb);
  }
}

class HorizontalMetricsTable extends FontTable {
  HorizontalMetricsTable(
    super.entry,
    this.hMetrics,
    this.leftSideBearings,
  ) : super.fromTableRecordEntry();

  factory HorizontalMetricsTable.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
    HorizontalHeaderTable hhea,
    int numGlyphs,
  ) {
    final hMetrics = List.generate(
      hhea.numberOfHMetrics,
      (i) => LongHorMetric.fromByteData(
        byteData,
        entry.offset + _kLongHorMetricSize * i,
      ),
    );
    final offset = entry.offset + _kLongHorMetricSize * hhea.numberOfHMetrics;
    final leftSideBearings = List.generate(
      numGlyphs - hhea.numberOfHMetrics,
      (i) => byteData.getInt16(offset + 2 * i),
    );

    return HorizontalMetricsTable(entry, hMetrics, leftSideBearings);
  }

  /// [advanceWidthOverrides], when given, must have one entry per glyph in
  /// [glyphMetricsList]; a non-null entry fixes that glyph's advance width
  /// (see [LongHorMetric.createForGlyph]).
  factory HorizontalMetricsTable.create(
    List<GenericGlyphMetrics> glyphMetricsList,
    int unitsPerEm, {
    List<int?>? advanceWidthOverrides,
  }) {
    final hMetrics = List.generate(
      glyphMetricsList.length,
      (i) => LongHorMetric.createForGlyph(
        glyphMetricsList[i],
        unitsPerEm,
        advanceWidthOverride: advanceWidthOverrides?[i],
      ),
    );

    return HorizontalMetricsTable(null, hMetrics, []);
  }

  final List<LongHorMetric> hMetrics;
  final List<int> leftSideBearings;

  @override
  int get size =>
      hMetrics.length * _kLongHorMetricSize + leftSideBearings.length * 2;

  int get advanceWidthMax =>
      hMetrics.fold<int>(0, (p, v) => math.max(p, v.advanceWidth));

  int get minLeftSideBearing =>
      hMetrics.fold<int>(kInt32Max, (p, v) => math.min(p, v.lsb));

  int getMinRightSideBearing(List<GenericGlyphMetrics> glyphMetricsList) {
    var minRsb = kInt32Max;

    for (var i = 0; i < glyphMetricsList.length; i++) {
      final m = glyphMetricsList[i];
      final rsb = hMetrics[i].getRsb(m.xMax, m.xMin);

      minRsb = math.min(minRsb, rsb);
    }

    return minRsb;
  }

  int getMaxExtent(List<GenericGlyphMetrics> glyphMetricsList) {
    var maxExtent = kInt32Min;

    for (var i = 0; i < glyphMetricsList.length; i++) {
      final m = glyphMetricsList[i];
      final extent = hMetrics[i].lsb + (m.xMax - m.xMin);

      maxExtent = math.max(maxExtent, extent);
    }

    return maxExtent;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    for (final hMetric in hMetrics) {
      hMetric.encodeToBinary(byteData.sublistView(offset, hMetric.size));
      offset += hMetric.size;
    }

    for (final lsb in leftSideBearings) {
      byteData.setUint16(offset, lsb);
      offset += 2;
    }
  }
}
