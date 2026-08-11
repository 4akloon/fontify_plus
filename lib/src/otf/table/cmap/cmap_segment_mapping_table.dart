import 'dart:math' as math;
import 'dart:typed_data';

import 'cmap_data.dart';
import 'cmap_format.dart';
import 'cmap_segment.dart';

/// Format 4: runs of consecutive codes within the BMP.
///
/// The one subtable every consumer understands, so it is written even when
/// format 12 already covers the same glyphs.
class CmapSegmentMappingToDeltaValuesTable extends CmapData {
  CmapSegmentMappingToDeltaValuesTable(
    super.format, {
    required this.length,
    required this.language,
    required this.segCount,
    required this.searchRange,
    required this.entrySelector,
    required this.rangeShift,
    required this.endCode,
    required this.reservedPad,
    required this.startCode,
    required this.idDelta,
    required this.idRangeOffset,
    required this.glyphIdArray,
  });

  factory CmapSegmentMappingToDeltaValuesTable.fromByteData(
    ByteData byteData,
    int startOffset,
  ) {
    final length = byteData.getUint16(startOffset + 2);
    final segCount = byteData.getUint16(startOffset + 6) ~/ 2;

    var offset = startOffset + 14;

    List<int> readWords(int count, {bool signed = false}) {
      final values = List.generate(
        count,
        (i) => signed
            ? byteData.getInt16(offset + 2 * i)
            : byteData.getUint16(offset + 2 * i),
      );

      offset += 2 * count;

      return values;
    }

    final endCode = readWords(segCount);

    final reservedPad = byteData.getUint16(offset);
    offset += 2;

    final startCode = readWords(segCount);
    final idDelta = readWords(segCount, signed: true);
    final idRangeOffset = readWords(segCount);
    final glyphIdArray = readWords(((startOffset + length) - offset) >> 1);

    return CmapSegmentMappingToDeltaValuesTable(
      byteData.getUint16(startOffset),
      length: length,
      language: byteData.getUint16(startOffset + 4),
      segCount: segCount,
      searchRange: byteData.getUint16(startOffset + 8),
      entrySelector: byteData.getUint16(startOffset + 10),
      rangeShift: byteData.getUint16(startOffset + 12),
      endCode: endCode,
      reservedPad: reservedPad,
      startCode: startCode,
      idDelta: idDelta,
      idRangeOffset: idRangeOffset,
      glyphIdArray: glyphIdArray,
    );
  }

  factory CmapSegmentMappingToDeltaValuesTable.create(
    List<CmapSegment> segmentList,
  ) {
    final segCount = segmentList.length;

    final entrySelector = (math.log(segCount) / math.ln2).floor();
    final searchRange = 2 * math.pow(2, entrySelector).toInt();

    return CmapSegmentMappingToDeltaValuesTable(
      kCmapFormat4,

      /// Eight 2-byte variable
      /// Four 2-byte arrays of [segCount] length
      /// glyphIdArray is zero length
      length: 16 + 4 * 2 * segCount,
      language: 0, // Roman language
      segCount: segCount,
      searchRange: searchRange,
      entrySelector: entrySelector,
      rangeShift: 2 * segCount - searchRange,
      endCode: [for (final segment in segmentList) segment.endCode],
      reservedPad: 0,
      startCode: [for (final segment in segmentList) segment.startCode],
      idDelta: [for (final segment in segmentList) segment.idDelta],
      idRangeOffset: List.filled(segCount, 0),
      glyphIdArray: const [], // Ignoring glyphIdArray
    );
  }

  final int length;
  final int language;
  final int segCount;
  final int searchRange;
  final int entrySelector;
  final int rangeShift;
  final List<int> endCode;
  final int reservedPad;
  final List<int> startCode;
  final List<int> idDelta;
  final List<int> idRangeOffset;
  final List<int> glyphIdArray;

  @override
  int get size => length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, length)
      ..setUint16(4, language)
      ..setUint16(6, segCount * 2)
      ..setUint16(8, searchRange)
      ..setUint16(10, entrySelector)
      ..setUint16(12, rangeShift);

    var offset = 14;

    void writeWords(Iterable<int> values) {
      for (final value in values) {
        byteData.setUint16(offset, value);
        offset += 2;
      }
    }

    writeWords(endCode);
    writeWords([reservedPad]);
    writeWords(startCode);
    writeWords(idDelta);
    writeWords(idRangeOffset);
    writeWords(glyphIdArray);
  }
}
