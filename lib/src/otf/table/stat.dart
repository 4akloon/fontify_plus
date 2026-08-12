import 'dart:typed_data';

import '../../common/stroke_width_range.dart';
import 'abstract.dart';

const _kHeaderSize = 20;
const _kAxisRecordSize = 8;
const _kAxisValueSize = 12;

/// This table always writes exactly one axis, `wght`.
const _kAxisCount = 1;

/// ...and two axis values for it: the range's minimum and maximum.
const _kAxisValueCount = 2;

/// Offset, from the start of the table, to the design axes array.
///
/// The array immediately follows the header, so this is just its size.
const _kDesignAxesOffset = _kHeaderSize;

/// Offset, from the start of the table, to the axis value offsets array.
///
/// The array immediately follows the design axes array.
const _kOffsetToAxisValueOffsets = _kDesignAxesOffset + _kAxisRecordSize;

/// Size, in bytes, of the axis value offsets array itself.
const _kAxisValueOffsetsArraySize = _kAxisValueCount * 2;

/// Converts to the 16.16 fixed point `STAT` axis values are stored in.
///
/// A duplicate of `fvar`'s identical helper: both tables converting
/// independently is fine, but lift this into `lib/src/utils/otf/` if a third
/// table needs it too.
int _fixed(double value) => (value * 65536).round();

/// The `STAT` table: style-attributes metadata every variable font must
/// carry per the OpenType spec. FreeType tolerates its absence, but OTS and
/// CoreText do not, so it is not optional in practice.
///
/// Declares the same `wght` axis `fvar` does, plus format 1 axis value
/// records naming its two endpoints — the only values this font actually
/// distinguishes, since every width between them is reached by
/// interpolation rather than by a named stop.
class StyleAttributesTable extends FontTable {
  StyleAttributesTable(super.entry, this.range, this.axisNameID)
    : super.fromTableRecordEntry();

  factory StyleAttributesTable.create(
    StrokeWidthRange range, {
    required int axisNameID,
  }) => StyleAttributesTable(null, range, axisNameID);

  final StrokeWidthRange range;
  final int axisNameID;

  @override
  int get size =>
      _kHeaderSize +
      _kAxisRecordSize +
      _kAxisValueOffsetsArraySize +
      _kAxisValueCount * _kAxisValueSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, 1) // majorVersion
      ..setUint16(2, 2) // minorVersion
      // The size of a design axis record. Unlike `fvar`'s axisSize, the spec
      // does not pin this to a single value for all time -- future minor
      // versions may extend the record -- but OTS unconditionally checks it
      // against the current record size and drops the table if it's short,
      // so it still cannot be left at zero.
      ..setUint16(4, _kAxisRecordSize) // designAxisSize
      ..setUint16(6, _kAxisCount) // designAxisCount
      ..setUint32(8, _kDesignAxesOffset) // designAxesOffset
      ..setUint16(12, _kAxisValueCount) // axisValueCount
      ..setUint32(14, _kOffsetToAxisValueOffsets) // offsetToAxisValueOffsets
      // The fallback name used if every axis value's own name is elided.
      // Name ID 2 (Font Subfamily) is unconditionally written as "Regular"
      // by this package's `name` table, so the reference always resolves.
      ..setUint16(18, 2); // elidedFallbackNameID

    const tag = 'wght';

    for (var i = 0; i < tag.length; i++) {
      byteData.setUint8(_kDesignAxesOffset + i, tag.codeUnitAt(i));
    }

    byteData
      ..setUint16(_kDesignAxesOffset + 4, axisNameID)
      // No preferred ordering among axes: there is only the one.
      ..setUint16(_kDesignAxesOffset + 6, 0); // axisOrdering

    // The Offset16 entries below are relative to the start of this array
    // (offsetToAxisValueOffsets itself), not to the start of the table --
    // getting that base wrong produces a table that still parses, but with
    // every AxisValue pointer landing on the wrong bytes.
    const firstAxisValueOffset = _kAxisValueOffsetsArraySize;
    const secondAxisValueOffset = firstAxisValueOffset + _kAxisValueSize;

    byteData
      ..setUint16(_kOffsetToAxisValueOffsets, firstAxisValueOffset)
      ..setUint16(_kOffsetToAxisValueOffsets + 2, secondAxisValueOffset);

    const axisValuesStart =
        _kOffsetToAxisValueOffsets + _kAxisValueOffsetsArraySize;

    _encodeAxisValue(byteData, axisValuesStart, range.min);
    _encodeAxisValue(byteData, axisValuesStart + _kAxisValueSize, range.max);
  }

  /// Writes a format 1 `AxisValue` record naming a single point on the
  /// (only) axis, reusing [axisNameID] as its display name: the endpoints
  /// have no separate names of their own, and pointing at the axis label
  /// keeps the `name` table to one added record.
  void _encodeAxisValue(ByteData byteData, int offset, double value) {
    byteData
      ..setUint16(offset, 1) // format
      ..setUint16(offset + 2, 0) // axisIndex: the only axis, wght
      ..setUint16(offset + 4, 0) // flags
      ..setUint16(offset + 6, axisNameID) // valueNameID
      ..setInt32(offset + 8, _fixed(value));
  }
}
