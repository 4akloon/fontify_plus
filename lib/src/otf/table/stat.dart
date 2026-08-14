import 'dart:typed_data';

import '../../common/stroke_width_range.dart';
import 'abstract.dart';

const _kHeaderSize = 20;
const _kAxisRecordSize = 8;
const _kAxisValueSize = 12;

/// This table always writes exactly one axis, `wght`.
const _kAxisCount = 1;

/// Offset, from the start of the table, to the design axes array.
///
/// The array immediately follows the header, so this is just its size.
const _kDesignAxesOffset = _kHeaderSize;

/// Offset, from the start of the table, to the axis value offsets array.
///
/// The array immediately follows the design axes array. Everything after it
/// moves with the axis value count, but this offset does not — which is why
/// it stays a constant while the rest are computed.
const _kOffsetToAxisValueOffsets = _kDesignAxesOffset + _kAxisRecordSize;

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
/// Declares the same `wght` axis `fvar` does, plus one format 1 axis value
/// record per width this font actually distinguishes: its two endpoints, and
/// the [defaultWidth] between them when there is one. Every other width is
/// reached by interpolation rather than by a named stop, so it gets no
/// record.
class StyleAttributesTable extends FontTable {
  StyleAttributesTable(
    super.entry,
    this.range,
    this.defaultWidth,
    this.axisNameID,
  ) : super.fromTableRecordEntry();

  /// Builds the table for [range], naming [defaultWidth] as a third axis
  /// value when one is given.
  ///
  /// Assumes [defaultWidth], if non-null, is already validated by the caller:
  /// finite, inside [range], and distinct from both of its ends. Nothing here
  /// re-checks that. A table encoder is not a boundary the value arrives
  /// through — it is handed an already-decided font description — and the
  /// rules are enforced once, where a caller can be told what went wrong in
  /// its own vocabulary. Repeating them here would be one more copy to keep in
  /// step, reachable only after those checks had already let a bad value
  /// through. A default equal to an endpoint would encode two axis values at
  /// the same coordinate, which parses but tells a font picker two names for
  /// one instance.
  factory StyleAttributesTable.create(
    StrokeWidthRange range, {
    double? defaultWidth,
    required int axisNameID,
  }) => StyleAttributesTable(null, range, defaultWidth, axisNameID);

  final StrokeWidthRange range;

  /// The width `fvar` defaults the axis to, when that is not [range]'s
  /// maximum — see `FontVariationsTable.defaultWidth` for why it is threaded
  /// separately from the range rather than folded into it.
  ///
  /// It earns an axis value record of its own because it is the instance a
  /// font picker opens on: without a record, the one width users see first is
  /// the one width `STAT` does not describe.
  final double? defaultWidth;

  final int axisNameID;

  /// The widths that get a format 1 axis value record, in ascending order.
  ///
  /// The offsets array, the table size and the records themselves are all
  /// derived from this one list, so there is no second place that has to be
  /// told the count changed.
  List<double> get _axisValues => [range.min, ?defaultWidth, range.max];

  /// Size, in bytes, of the axis value offsets array itself.
  int get _axisValueOffsetsArraySize => _axisValues.length * 2;

  @override
  int get size =>
      _kHeaderSize +
      _kAxisRecordSize +
      _axisValueOffsetsArraySize +
      _axisValues.length * _kAxisValueSize;

  @override
  void encodeToBinary(ByteData byteData) {
    final axisValues = _axisValues;

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
      ..setUint16(12, axisValues.length) // axisValueCount
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

    // The Offset16 entries written below are relative to the start of their
    // own array (offsetToAxisValueOffsets itself), not to the start of the
    // table -- getting that base wrong produces a table that still parses,
    // but with every AxisValue pointer landing on the wrong bytes. The
    // records follow the array immediately and in the same order, so the
    // first one begins at the array's own size.
    //
    // An odd axis value count makes that array an odd number of Offset16s
    // wide, so the records land on a 2-byte but not 4-byte boundary. `STAT`
    // imposes no alignment on them -- they are reached only through these
    // offsets -- and the table as a whole is padded to four bytes when it is
    // written into the font, so the Fixed values inside stay readable.
    final offsetsArraySize = _axisValueOffsetsArraySize;
    final axisValuesStart = _kOffsetToAxisValueOffsets + offsetsArraySize;

    for (var i = 0; i < axisValues.length; i++) {
      final recordStart = axisValuesStart + i * _kAxisValueSize;

      byteData.setUint16(
        _kOffsetToAxisValueOffsets + i * 2,
        recordStart - _kOffsetToAxisValueOffsets,
      );
      _encodeAxisValue(byteData, recordStart, axisValues[i]);
    }
  }

  /// Writes a format 1 `AxisValue` record naming a single point on the
  /// (only) axis, reusing [axisNameID] as its display name: none of the
  /// widths this table records — neither endpoint, nor an interior
  /// [defaultWidth] — has a name of its own, and pointing every record at the
  /// axis label keeps the `name` table to one added record.
  void _encodeAxisValue(ByteData byteData, int offset, double value) {
    byteData
      ..setUint16(offset, 1) // format
      ..setUint16(offset + 2, 0) // axisIndex: the only axis, wght
      // No flags. ELIDABLE_AXIS_VALUE_NAME (0x0002) would belong on the
      // default instance's record, telling consumers to drop its name from a
      // composed style string -- but every record here shares one nameID with
      // the axis itself, so eliding one of them is a decision about that
      // scheme rather than about this record. Left for whoever gives these
      // values names of their own.
      ..setUint16(offset + 4, 0) // flags
      ..setUint16(offset + 6, axisNameID) // valueNameID
      ..setInt32(offset + 8, _fixed(value));
  }
}
