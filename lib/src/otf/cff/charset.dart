part of fontify_plus.otf.cff;

const _kFormat0 = 0;
const _kFormat1 = 1;
const _kFormat2 = 2;

const _kRange1Size = 3;

abstract class CharsetEntry implements BinaryCodable {
  const CharsetEntry(this.format);

  static CharsetEntry? fromByteData(ByteData bd, int glyphCount) {
    final format = bd.getUint8(0);
    final byteData = bd.sublistView(1);

    switch (format) {
      case _kFormat1:
        return _CharsetEntryFormat1.fromByteData(byteData, glyphCount);
      case _kFormat0:
      case _kFormat2:
      default:
        debuggerOTF.debugUnsupportedTableFormat('charsets', format);
    }

    return null;
  }

  final int format;
}

class _CharsetEntryFormat1 extends CharsetEntry {
  _CharsetEntryFormat1(super.format, this.rangeList);

  factory _CharsetEntryFormat1.fromByteData(ByteData byteData, int glyphCount) {
    final rangeList = <_Range1>[];

    var offset = 0;

    for (var i = 0; i < glyphCount - 1;) {
      final range = _Range1.fromByteData(
        byteData.sublistView(offset, _kRange1Size),
      );

      rangeList.add(range);

      i += 1 + range.nLeft;
      offset += range.size;
    }

    return _CharsetEntryFormat1(_kFormat1, rangeList);
  }

  factory _CharsetEntryFormat1.create(List<int> sIdList) {
    final rangeList = <_Range1>[];

    if (sIdList.isNotEmpty) {
      var prevSid = sIdList.first;
      var count = 1;

      int getNleft() => count - 1;

      void saveRange() {
        rangeList.add(_Range1(prevSid - count + 1, getNleft()));
        count = 0;
      }

      for (var i = 1; i < sIdList.length; i++) {
        final sId = sIdList[i];
        final willOverflow = getNleft() + 1 > kUint8Max;

        if (willOverflow || prevSid + 1 != sId) {
          saveRange();
        }

        prevSid = sId;
        count++;
      }

      saveRange();
    }

    return _CharsetEntryFormat1(_kFormat1, rangeList);
  }

  final List<_Range1> rangeList;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint8(0, format);

    for (var i = 0; i < rangeList.length; i++) {
      rangeList[i].encodeToBinary(
        byteData.sublistView(1 + i * _kRange1Size, _kRange1Size),
      );
    }
  }

  @override
  int get size => 1 + rangeList.length * _kRange1Size;
}

class _Range1 implements BinaryCodable {
  const _Range1(this.sId, this.nLeft);

  factory _Range1.fromByteData(ByteData byteData) {
    return _Range1(byteData.getUint16(0), byteData.getUint8(2));
  }

  final int sId;
  final int nLeft;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, sId)
      ..setUint8(2, nLeft);
  }

  @override
  int get size => _kRange1Size;
}
