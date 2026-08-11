import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/table/cmap.dart';
import 'package:fontify_plus/src/otf/table/gsub.dart';
import 'package:fontify_plus/src/otf/table/head.dart';
import 'package:fontify_plus/src/otf/table/hhea.dart';
import 'package:fontify_plus/src/otf/table/hmtx.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

const _kUnitsPerEm = 1000;

List<GenericGlyphMetrics> _metricsList() => [
  GenericGlyphMetrics.empty(),
  GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
];

List<GenericGlyph> _fullGlyphList() => [
  GenericGlyph.empty(),
  GenericGlyph.empty()..metadata.charCode = 0xE001,
];

OS2Table _built({int version = kOS2Version5}) {
  final hmtx = HorizontalMetricsTable.create(_metricsList(), _kUnitsPerEm);
  final head = HeaderTable.create(
    _metricsList(),
    null,
    const Revision(1, 0),
    _kUnitsPerEm,
  );
  final hhea = HorizontalHeaderTable.create(_metricsList(), hmtx, 800, -200);
  final cmap = CharacterToGlyphTable.create(_fullGlyphList());

  return OS2Table.create(
    hmtx,
    head,
    hhea,
    cmap,
    GlyphSubstitutionTable.create(),
    'PfPl',
    version: version,
  );
}

void main() {
  group('OS2Table.size', () {
    test('is 78 bytes for a version-0 table', () {
      expect(_built(version: kOS2Version0).size, 78);
    });

    test('is 86 bytes for a version-1 table', () {
      expect(_built(version: kOS2Version1).size, 86);
    });

    test('is 96 bytes for a version-4 table', () {
      expect(_built(version: kOS2Version4).size, 96);
    });

    test('is 100 bytes for a version-5 table', () {
      expect(_built(version: kOS2Version5).size, 100);
    });
  });

  group('OS2Table.create', () {
    test('delegates to buildOS2Table', () {
      expect(_built().version0.achVendID, 'PfPl');
    });
  });

  group('OS2Table.fromByteData', () {
    test('round-trips a built table through encodeToBinary', () {
      final table = _built();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = OS2Table.fromByteData(
        bytes,
        TableRecordEntry(
          'OS/2',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded.version, table.version);
      expect(decoded.version0.achVendID, table.version0.achVendID);
    });
  });
}
