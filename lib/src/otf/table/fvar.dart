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
///
/// The axis default is written from [StrokeWidthRange.max], or from the
/// separately supplied [defaultWidth] when there is one. Callers are expected
/// to supply only those two placements, and this table does not check that
/// they did — see [FontVariationsTable.create].
///
/// The expectation is not a stylistic preference. The default is the origin of
/// normalized design space, so every width on the far side of it from a
/// variation region needs a region of its own: a default at the maximum keeps
/// the font at one region and one delta per varying value, an interior default
/// costs a second of each, and those are the only two layouts the `CFF2`
/// variation store encodes. A default the masters do not sit at would produce
/// an axis whose interpolation the outlines cannot follow.
class FontVariationsTable extends FontTable {
  FontVariationsTable(
    super.entry,
    this.range,
    this.defaultWidth,
    this.axisNameID,
  ) : super.fromTableRecordEntry();

  /// Builds the table for [range], defaulting the axis to [defaultWidth] when
  /// one is given and to [StrokeWidthRange.max] when it is not.
  ///
  /// Assumes [defaultWidth], if non-null, is already validated by the caller:
  /// finite, inside [range], and distinct from both of its ends. Nothing here
  /// re-checks that. A table encoder is not a boundary the value arrives
  /// through — it is handed an already-decided font description — and the
  /// rules are enforced once, where a caller can be told what went wrong in
  /// its own vocabulary. Repeating them here would be one more copy to keep in
  /// step, reachable only after those checks had already let a bad value
  /// through.
  ///
  /// Not validating is not the same as accepting silently, and here the two
  /// bad inputs part company. A non-finite width throws out of the 16.16
  /// conversion — a bare `UnsupportedError: Infinity or NaN toInt`, which
  /// names the arithmetic and not the parameter, so read it as an unvalidated
  /// input rather than a defect in this table. A finite width outside [range],
  /// or equal to an endpoint, does *not* throw: it encodes an axis whose
  /// default coordinate the outlines' masters do not sit at, and the font only
  /// goes wrong at render time. That one is the reason the boundary checks
  /// exist.
  factory FontVariationsTable.create(
    StrokeWidthRange range, {
    double? defaultWidth,
    required int axisNameID,
  }) => FontVariationsTable(null, range, defaultWidth, axisNameID);

  final StrokeWidthRange range;

  /// The width the axis defaults to, or null to default to [range]'s maximum.
  ///
  /// Deliberately not a field on [StrokeWidthRange]: the range is what the
  /// axis *spans*, and it is consumed by the geometry pipeline, which plans
  /// every outline at its maximum and cares about nothing else. Where the
  /// default sits changes only which instance a font picker lands on first,
  /// and how many variation regions pay for it — so it travels alongside the
  /// range rather than inside it, and code that only needs the span is not
  /// made to reason about the default.
  final double? defaultWidth;

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
      ..setInt32(_kHeaderSize + 8, _fixed(defaultWidth ?? range.max))
      ..setInt32(_kHeaderSize + 12, _fixed(range.max))
      ..setUint16(_kHeaderSize + 16, 0) // flags: the axis is not hidden
      ..setUint16(_kHeaderSize + 18, axisNameID);
  }
}
