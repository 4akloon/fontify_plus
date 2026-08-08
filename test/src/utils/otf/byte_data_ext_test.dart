import 'dart:typed_data';

import 'package:fontify_plus/src/utils/otf/byte_data_ext.dart';
import 'package:test/test.dart';

void main() {
  group('Fixed / FWord / UFWord', () {
    test('Fixed round-trips through 16-bit storage', () {
      final bytes = ByteData(2)..setFixed(0, 1234);

      expect(bytes.getFixed(0), 1234);
    });

    test('FWord round-trips a negative value', () {
      final bytes = ByteData(2)..setFWord(0, -100);

      expect(bytes.getFWord(0), -100);
    });

    test('UFWord round-trips a positive value', () {
      final bytes = ByteData(2)..setUFWord(0, 65000);

      expect(bytes.getUFWord(0), 65000);
    });
  });

  group('getByteList / setByteList', () {
    test('round-trips a byte list at an offset', () {
      final bytes = ByteData(6);
      bytes.setByteList(2, Uint8List.fromList([1, 2, 3, 4]));

      expect(bytes.getByteList(2, 4), [1, 2, 3, 4]);
    });

    test('leaves bytes outside the range untouched', () {
      final bytes = ByteData(4)..setUint8(0, 0xFF);
      bytes.setByteList(1, Uint8List.fromList([1, 2, 3]));

      expect(bytes.getUint8(0), 0xFF);
    });
  });

  group('getTag / setTag', () {
    test('round-trips a four-character tag', () {
      final bytes = ByteData(4)..setTag(0, 'glyf');

      expect(bytes.getTag(0), 'glyf');
    });

    test('writes starting at the given offset', () {
      final bytes = ByteData(8)..setTag(4, 'name');

      expect(bytes.getTag(4), 'name');
    });
  });

  group('getDateTime / setDateTime', () {
    test('round-trips a UTC date through LONGDATETIME', () {
      final date = DateTime.utc(2024, 3, 15, 12, 30);
      final bytes = ByteData(8)..setDateTime(0, date);

      expect(bytes.getDateTime(0), date);
    });

    test('the LONGDATETIME epoch is 1904-01-01', () {
      final bytes = ByteData(8)..setInt64(0, 0);

      expect(bytes.getDateTime(0), DateTime.utc(1904, 1, 1));
    });
  });

  group('sublistView', () {
    test('views from an offset to the end when length is omitted', () {
      final bytes = ByteData(10)..setUint8(4, 42);
      final view = bytes.sublistView(4);

      expect(view.lengthInBytes, 6);
      expect(view.getUint8(0), 42);
    });

    test('views exactly the given length', () {
      final bytes = ByteData(10);
      final view = bytes.sublistView(2, 3);

      expect(view.lengthInBytes, 3);
    });

    test('a write through the view is visible in the original', () {
      final bytes = ByteData(10);
      bytes.sublistView(2, 4).setUint8(0, 99);

      expect(bytes.getUint8(2), 99);
    });
  });
}
