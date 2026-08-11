import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/language_system.dart';
import 'package:test/test.dart';

void main() {
  group('LanguageSystemRecord', () {
    test('size is fixed at 6 bytes', () {
      final record = LanguageSystemRecord('ENG ', 0);

      expect(record.size, 6);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final record = LanguageSystemRecord('ENG ', 12);
      final bytes = ByteData(record.size);

      record.encodeToBinary(bytes);
      final decoded = LanguageSystemRecord.fromByteData(bytes, 0);

      expect(decoded.langSysTag, 'ENG ');
      expect(decoded.langSysOffset, 12);
    });
  });

  group('LanguageSystemTable', () {
    test('size is 6 bytes plus 2 per feature index', () {
      const table = LanguageSystemTable(
        lookupOrder: 0,
        requiredFeatureIndex: 0xFFFF,
        featureIndexCount: 2,
        featureIndices: [0, 1],
      );

      expect(table.size, 10);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      const table = LanguageSystemTable(
        lookupOrder: 0,
        requiredFeatureIndex: 0xFFFF,
        featureIndexCount: 1,
        featureIndices: [0],
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = LanguageSystemTable.fromByteData(bytes, 0);

      expect(decoded.requiredFeatureIndex, 0xFFFF);
      expect(decoded.featureIndexCount, 1);
      expect(decoded.featureIndices, [0]);
    });
  });
}
