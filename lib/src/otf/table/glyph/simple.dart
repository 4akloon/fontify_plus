import 'dart:math' as math;
import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import 'flag.dart';
import 'header.dart';
import 'simple_glyph_coordinates.dart';

/// A TrueType glyph made of contours, as opposed to a composite of other
/// glyphs.
class SimpleGlyph implements BinaryCodable {
  const SimpleGlyph({
    required this.header,
    required this.endPtsOfContours,
    required this.instructions,
    required this.flags,
    required this.pointList,
  });

  factory SimpleGlyph.empty() => const SimpleGlyph(
    header: GlyphHeader(
      numberOfContours: 0,
      xMin: 0,
      yMin: 0,
      xMax: 0,
      yMax: 0,
    ),
    endPtsOfContours: [],
    instructions: [],
    flags: [],
    pointList: [],
  );

  factory SimpleGlyph.fromByteData(
    ByteData byteData,
    GlyphHeader header,
    int glyphOffset,
  ) {
    var offset = glyphOffset + header.size;

    final endPtsOfContours = [
      for (var i = 0; i < header.numberOfContours; i++)
        byteData.getUint16(offset + i * 2),
    ];
    offset += header.numberOfContours * 2;

    final instructionLength = byteData.getUint16(offset);
    offset += 2;

    final instructions = [
      for (var i = 0; i < instructionLength; i++) byteData.getUint8(offset + i),
    ];
    offset += instructionLength;

    final numberOfPoints = _getNumberOfPoints(endPtsOfContours);
    final flags = <SimpleGlyphFlag>[];

    for (var i = 0; i < numberOfPoints; i++) {
      final flag = SimpleGlyphFlag.fromByteData(byteData, offset);
      offset += flag.size;
      flags.add(flag);

      for (var j = 0; j < flag.repeatTimes; j++) {
        flags.add(flag);
      }

      i += flag.repeatTimes;
    }

    final (xCoordinates, afterX) = readCoordinates(
      byteData,
      offset,
      flags,
      numberOfPoints,
      GlyphAxis.x,
    );
    final (yCoordinates, _) = readCoordinates(
      byteData,
      afterX,
      flags,
      numberOfPoints,
      GlyphAxis.y,
    );

    final xAbs = relToAbsCoordinates(xCoordinates);
    final yAbs = relToAbsCoordinates(yCoordinates);

    return SimpleGlyph(
      header: header,
      endPtsOfContours: endPtsOfContours,
      instructions: instructions,
      flags: flags,
      pointList: [
        for (var i = 0; i < xAbs.length; i++) math.Point<num>(xAbs[i], yAbs[i]),
      ],
    );
  }

  final GlyphHeader header;
  final List<int> endPtsOfContours;
  final List<int> instructions;
  final List<SimpleGlyphFlag> flags;

  final List<math.Point<num>> pointList;

  bool get isEmpty => header.numberOfContours == 0;

  @override
  int get size => isEmpty ? 0 : header.size + _descriptionSize;

  int get _descriptionSize =>
      endPtsOfContours.length * 2 +
      (2 + instructions.length) +
      _flagsSize +
      _coordinatesSize;

  int get _coordinatesSize {
    var coordinatesSize = 0;

    for (final flag in flags) {
      for (final axis in GlyphAxis.values) {
        coordinatesSize += axis.isShort(flag)
            ? 1
            : (axis.isSameOrPositive(flag) ? 0 : 2);
      }
    }

    return coordinatesSize;
  }

  int get _flagsSize {
    var flagsSize = 0;

    for (var i = 0; i < flags.length; i++) {
      final flag = flags[i];

      flagsSize += flag.size;
      i += flag.repeatTimes;
    }

    return flagsSize;
  }

  static int _getNumberOfPoints(List<int> endPtsOfContours) =>
      endPtsOfContours.isNotEmpty ? endPtsOfContours.last + 1 : 0;

  @override
  void encodeToBinary(ByteData byteData) {
    header.encodeToBinary(byteData);
    var offset = header.size;

    for (var i = 0; i < header.numberOfContours; i++) {
      byteData.setUint16(offset + i * 2, endPtsOfContours[i]);
    }
    offset += header.numberOfContours * 2;

    byteData.setUint16(offset, instructions.length);
    offset += 2;

    for (var i = 0; i < instructions.length; i++) {
      byteData.setUint8(offset + i, instructions[i]);
    }
    offset += instructions.length;

    final numberOfPoints = _getNumberOfPoints(endPtsOfContours);

    for (var i = 0; i < numberOfPoints; i++) {
      final flag = flags[i];
      flag.encodeToBinary(byteData.sublistView(offset, flag.size));

      offset += flag.size;
      i += flag.repeatTimes;
    }

    final xRel = absToRelCoordinates([for (final p in pointList) p.x.toInt()]);
    final yRel = absToRelCoordinates([for (final p in pointList) p.y.toInt()]);

    offset = writeCoordinates(
      byteData,
      offset,
      flags,
      xRel,
      numberOfPoints,
      GlyphAxis.x,
    );

    writeCoordinates(
      byteData,
      offset,
      flags,
      yRel,
      numberOfPoints,
      GlyphAxis.y,
    );
  }
}
