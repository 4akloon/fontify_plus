import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/coverage.dart';
import 'package:fontify_plus/src/otf/table/lookup/ligature_substitution_subtable.dart';
import 'package:fontify_plus/src/otf/table/lookup/substitution_subtable.dart';
import 'package:test/test.dart';

void main() {
  group('SubstitutionSubtable.fromByteData', () {
    test('dispatches lookup type 4 to LigatureSubstitutionSubtable', () {
      const subtable = LigatureSubstitutionSubtable(
        1,
        6,
        0,
        [],
        kDefaultCoverageTable,
      );
      final bytes = ByteData(subtable.size);
      subtable.encodeToBinary(bytes);

      final decoded = SubstitutionSubtable.fromByteData(bytes, 0, 4);

      expect(decoded, isA<LigatureSubstitutionSubtable>());
    });

    test('returns null for an unsupported lookup type', () {
      final decoded = SubstitutionSubtable.fromByteData(ByteData(0), 0, 99);

      expect(decoded, isNull);
    });
  });
}
