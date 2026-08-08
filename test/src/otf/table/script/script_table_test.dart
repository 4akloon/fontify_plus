import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/language_system.dart';
import 'package:fontify_plus/src/otf/table/script/script_record.dart';
import 'package:fontify_plus/src/otf/table/script/script_table.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

const _kLangSys = LanguageSystemTable(0, 0xFFFF, 1, [0]);

void main() {
  group('ScriptTable.size', () {
    test('is 4 bytes plus the default and listed lang-sys tables', () {
      final table = ScriptTable(4, 0, [], [], _kLangSys);

      expect(table.size, 4 + _kLangSys.size);
    });

    test('adds each listed lang-sys record and table', () {
      final record = LanguageSystemRecord('ENG ', 0);
      final table = ScriptTable(4, 1, [record], [_kLangSys], _kLangSys);

      expect(table.size, 4 + record.size + _kLangSys.size * 2);
    });
  });

  group('ScriptTable round trip', () {
    test(
      'round-trips a default-only table through encodeToBinary and fromByteData',
      () {
        final table = ScriptTable(4, 0, [], [], _kLangSys);
        final scriptRecord = ScriptRecord('latn', 0);
        final bytes = ByteData(table.size);

        table.encodeToBinary(bytes);
        final decoded = ScriptTable.fromByteData(bytes, 0, scriptRecord);

        expect(decoded.langSysCount, 0);
        expect(decoded.defaultLangSys!.featureIndices, [0]);
      },
    );

    test('round-trips a table with a listed lang system', () {
      final record = LanguageSystemRecord('ENG ', 0);
      final table = ScriptTable(4, 1, [record], [_kLangSys], _kLangSys);
      final scriptRecord = ScriptRecord('latn', 0);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = ScriptTable.fromByteData(bytes, 0, scriptRecord);

      expect(decoded.langSysCount, 1);
      expect(decoded.langSysRecords.single.langSysTag, 'ENG ');
      expect(decoded.langSysTables.single.featureIndices, [0]);
      expect(decoded.defaultLangSys!.featureIndices, [0]);
    });

    test('reads the table at the record\'s scriptOffset', () {
      final table = ScriptTable(4, 0, [], [], _kLangSys);
      final scriptRecord = ScriptRecord('latn', 10);
      final bytes = ByteData(10 + table.size);

      table.encodeToBinary(bytes.sublistView(10, table.size));
      final decoded = ScriptTable.fromByteData(bytes, 0, scriptRecord);

      expect(decoded.defaultLangSys!.featureIndices, [0]);
    });
  });
}
