import 'dart:io';
import 'dart:typed_data';

import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

import '../../../constant.dart';

const _kTestCFF2FontAssetPath = '$kTestAssetsDir/test_cff2_font.otf';

OpenTypeFont readFromFile(String path) {
  final bytes = File(path).readAsBytesSync();

  return OpenTypeFont.fromByteData(ByteData.sublistView(bytes));
}

void main() {
  group('CFFTable.fromByteData', () {
    test('dispatches a CFF2 table to CFF2Table', () {
      final font = readFromFile(_kTestCFF2FontAssetPath);

      expect(font.tableMap[kCFF2Tag], isA<CFF2Table>());
    });

    test('CFF2Table.isCFF1 is false', () {
      final font = readFromFile(_kTestCFF2FontAssetPath);

      expect(font.cff2.isCFF1, isFalse);
    });
  });
}
