import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/script/script_record.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptRecord', () {
    test('size is fixed at 6 bytes', () {
      final record = ScriptRecord('latn', 0);

      expect(record.size, 6);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final record = ScriptRecord('latn', 8);
      final bytes = ByteData(record.size);

      record.encodeToBinary(bytes);
      final decoded = ScriptRecord.fromByteData(bytes, 0);

      expect(decoded.scriptTag, 'latn');
      expect(decoded.scriptOffset, 8);
    });
  });
}
