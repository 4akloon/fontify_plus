import 'dart:typed_data';

import 'tags.dart';

/// Epoch for OpenType's LONGDATETIME.
final _longDateTimeStart = DateTime.parse('1904-01-01T00:00:00.000Z');

/// OpenType's own scalar types, on top of what [ByteData] already offers.
extension OTFByteDateExt on ByteData {
  int getFixed(int offset) => getUint16(offset);

  void setFixed(int offset, int value) => setUint16(offset, value);

  int getFWord(int offset) => getInt16(offset);

  void setFWord(int offset, int value) => setInt16(offset, value);

  int getUFWord(int offset) => getUint16(offset);

  void setUFWord(int offset, int value) => setUint16(offset, value);

  Uint8List getByteList(int offset, int length) => Uint8List.fromList(
        [for (var i = 0; i < length; i++) getUint8(offset + i)],
      );

  void setByteList(int offset, Uint8List list) {
    for (var i = 0; i < list.length; i++) {
      setUint8(offset + i, list[i]);
    }
  }

  String getTag(int offset) =>
      convertTagToString(Uint8List.view(buffer, offset, 4));

  void setTag(int offset, String tag) {
    var currentOffset = offset;

    convertStringToTag(tag).forEach((b) => setUint8(currentOffset++, b));
  }

  DateTime getDateTime(int offset) =>
      _longDateTimeStart.add(Duration(seconds: getInt64(offset)));

  void setDateTime(int offset, DateTime dateTime) =>
      setInt64(offset, dateTime.difference(_longDateTimeStart).inSeconds);

  /// A view of [length] bytes starting at [offset], or to the end when
  /// [length] is omitted.
  ByteData sublistView(int offset, [int? length]) => ByteData.sublistView(
        this,
        offset,
        length == null ? null : offset + length,
      );
}
