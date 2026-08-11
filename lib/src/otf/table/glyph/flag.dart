import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';

const _kOnCurvePointValue = 0x01;
const _kXshortVectorValue = 0x02;
const _kYshortVectorValue = 0x04;
const _kRepeatFlagValue = 0x08;
const _kXisSameValue = 0x10;
const _kYisSameValue = 0x20;
const _kOverlapSimpleValue = 0x40;
const _kReservedValue = 0x80;

class SimpleGlyphFlag implements BinaryCodable {
  const SimpleGlyphFlag({
    required this.onCurvePoint,
    required this.xShortVector,
    required this.yShortVector,
    required this.repeat,
    required this.xIsSameOrPositive,
    required this.yIsSameOrPositive,
    required this.overlapSimple,
    required this.reserved,
  });

  factory SimpleGlyphFlag.fromIntValue(int flag, [int? repeatTimes]) {
    return SimpleGlyphFlag(
      onCurvePoint: checkBitMask(flag, _kOnCurvePointValue),
      xShortVector: checkBitMask(flag, _kXshortVectorValue),
      yShortVector: checkBitMask(flag, _kYshortVectorValue),
      repeat: repeatTimes,
      xIsSameOrPositive: checkBitMask(flag, _kXisSameValue),
      yIsSameOrPositive: checkBitMask(flag, _kYisSameValue),
      overlapSimple: checkBitMask(flag, _kOverlapSimpleValue),
      reserved: checkBitMask(flag, _kReservedValue),
    );
  }

  factory SimpleGlyphFlag.fromByteData(ByteData byteData, int offset) {
    final flag = byteData.getUint8(offset);
    final repeatFlag = checkBitMask(flag, _kRepeatFlagValue);
    final repeatTimes = repeatFlag ? byteData.getUint8(offset + 1) : null;

    return SimpleGlyphFlag.fromIntValue(flag, repeatTimes);
  }

  factory SimpleGlyphFlag.createForPoint({
    required int x,
    required int y,
    required bool isOnCurve,
  }) {
    final xIsShort = isShortInteger(x);
    final yIsShort = isShortInteger(y);

    return SimpleGlyphFlag(
      onCurvePoint: isOnCurve,
      xShortVector: xIsShort,
      yShortVector: yIsShort,
      repeat: null,
      // 1 if short and positive, 0 otherwise
      xIsSameOrPositive: xIsShort && !x.isNegative,
      yIsSameOrPositive: yIsShort && !y.isNegative,
      overlapSimple: false,
      reserved: false,
    );
  }

  final bool onCurvePoint;
  final bool xShortVector;
  final bool yShortVector;
  final int? repeat;
  final bool xIsSameOrPositive;
  final bool yIsSameOrPositive;
  final bool overlapSimple;
  final bool reserved;

  Map<int, bool> get _valueForMaskMap => {
    _kOnCurvePointValue: onCurvePoint,
    _kXshortVectorValue: xShortVector,
    _kYshortVectorValue: yShortVector,
    _kXisSameValue: xIsSameOrPositive,
    _kYisSameValue: yIsSameOrPositive,
    _kOverlapSimpleValue: overlapSimple,
    _kReservedValue: reserved,
    _kRepeatFlagValue: isRepeating,
  };

  bool get isRepeating => repeat != null;

  int get repeatTimes => repeat ?? 0;

  /// Whether [other] encodes to the same byte, repetition aside.
  ///
  /// Two such flags can share one byte plus a count instead of one byte each.
  bool hasSameBits(SimpleGlyphFlag other) =>
      (intValue | _kRepeatFlagValue) == (other.intValue | _kRepeatFlagValue);

  /// This flag, standing for itself and [times] further points.
  SimpleGlyphFlag repeated(int times) => SimpleGlyphFlag(
    onCurvePoint: onCurvePoint,
    xShortVector: xShortVector,
    yShortVector: yShortVector,
    repeat: times,
    xIsSameOrPositive: xIsSameOrPositive,
    yIsSameOrPositive: yIsSameOrPositive,
    overlapSimple: overlapSimple,
    reserved: reserved,
  );

  int get intValue {
    var value = 0;

    _valueForMaskMap.forEach((mask, flagIsSet) {
      value |= flagIsSet ? mask : 0;
    });

    return value;
  }

  @override
  int get size => 1 + (isRepeating ? 1 : 0);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint8(0, intValue);

    if (isRepeating) {
      byteData.setUint8(1, repeatTimes);
    }
  }
}
