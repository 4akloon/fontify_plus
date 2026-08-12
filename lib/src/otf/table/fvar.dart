import 'dart:typed_data';

import '../../common/stroke_width_range.dart';
import 'abstract.dart';

const _kHeaderSize = 16;
const _kAxisRecordSize = 20;

/// This table always writes exactly one axis, `wght`.
const _kAxisCount = 1;

/// Converts to the 16.16 fixed point `fvar` stores axis values in.
int _fixed(double value) => (value * 65536).round();

/// The `fvar` table: the axes a variable font can be instanced along.
///
/// One axis, `wght`, whose values are literal stroke widths — so
/// `Icon(icon, weight: 1.33)` asks for a stroke width of 1.33, matching the
/// design system's own table rather than a rescaling of it.
class FontVariationsTable extends FontTable {
  FontVariationsTable(super.entry, this.range, this.axisNameID)
    : super.fromTableRecordEntry();

  factory FontVariationsTable.create(
    StrokeWidthRange range, {
    required int axisNameID,
  }) => FontVariationsTable(null, range, axisNameID);

  final StrokeWidthRange range;
  final int axisNameID;

  @override
  int get size => _kHeaderSize + _kAxisRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, 1) // majorVersion
      ..setUint16(2, 0) // minorVersion
      ..setUint16(4, _kHeaderSize) // axesArrayOffset
      ..setUint16(6, 2) // reserved, required to be 2
      ..setUint16(8, _kAxisCount) // axisCount
      ..setUint16(10, _kAxisRecordSize) // axisSize
      ..setUint16(12, 0) // instanceCount
      // The spec's instanceSize formula applies unconditionally, not only
      // when instanceCount > 0 — HarfBuzz's fvar sanitizer checks it that
      // way and drops the whole table if it's short, even with no instances.
      ..setUint16(14, _kAxisCount * 4 + 4); // instanceSize

    const tag = 'wght';

    for (var i = 0; i < tag.length; i++) {
      byteData.setUint8(_kHeaderSize + i, tag.codeUnitAt(i));
    }

    byteData
      ..setInt32(_kHeaderSize + 4, _fixed(range.min))
      // The default sits at the maximum on purpose: a default inside the range
      // needs deltas for a region on each side of it.
      ..setInt32(_kHeaderSize + 8, _fixed(range.max))
      ..setInt32(_kHeaderSize + 12, _fixed(range.max))
      ..setUint16(_kHeaderSize + 16, 0) // flags: the axis is not hidden
      ..setUint16(_kHeaderSize + 18, axisNameID);
  }
}
