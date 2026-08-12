import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/post/post_script_table_header.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

void main() {
  group('PostScriptTableHeader.create', () {
    test('carries the given version and zeroes every other field', () {
      final header = PostScriptTableHeader.create(const Revision(2, 0));

      expect(header.version.major, 2);
      expect(header.version.minor, 0);
      expect(header.italicAngle, 0);
      expect(header.underlinePosition, 0);
      expect(header.underlineThickness, 0);
      expect(header.isFixedPitch, 0);
    });

    test('size is fixed at 32 bytes', () {
      final header = PostScriptTableHeader.create(const Revision(3, 0));

      expect(header.size, 32);
    });
  });

  group('PostScriptTableHeader round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final header = PostScriptTableHeader.create(const Revision(3, 0));
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);

      final decoded = PostScriptTableHeader.fromByteData(
        bytes,
        TableRecordEntry(
          'post',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded.version.major, 3);
      expect(decoded.version.minor, 0);
      expect(decoded.italicAngle, 0);
      expect(decoded.underlinePosition, 0);
      expect(decoded.underlineThickness, 0);
    });
  });
}
