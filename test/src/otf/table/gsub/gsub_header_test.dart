import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/gsub/gsub_header.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphSubstitutionTableHeader.create', () {
    test('always declares version 1.0', () {
      final header = GlyphSubstitutionTableHeader.create();

      expect(header.majorVersion, 1);
      expect(header.minorVersion, 0);
      expect(header.isV10, isTrue);
    });

    test('size is 10 bytes for version 1.0', () {
      final header = GlyphSubstitutionTableHeader.create();

      expect(header.size, 10);
    });
  });

  group('GlyphSubstitutionTableHeader round trip', () {
    test(
      'round-trips a version-1.0 header through encodeToBinary and fromByteData',
      () {
        final header = GlyphSubstitutionTableHeader.create()
          ..scriptListOffset = 10
          ..featureListOffset = 20
          ..lookupListOffset = 30;
        final bytes = ByteData(header.size);

        header.encodeToBinary(bytes);

        final decoded = GlyphSubstitutionTableHeader.fromByteData(
          bytes,
          TableRecordEntry(
            'GSUB',
            checkSum: 0,
            offset: 0,
            length: bytes.lengthInBytes,
          ),
        );

        expect(decoded.isV10, isTrue);
        expect(decoded.scriptListOffset, 10);
        expect(decoded.featureListOffset, 20);
        expect(decoded.lookupListOffset, 30);
        expect(decoded.featureVariationsOffset, isNull);
      },
    );

    test(
      'round-trips a version-1.1 header, including featureVariationsOffset',
      () {
        final header = GlyphSubstitutionTableHeader(
          majorVersion: 1,
          minorVersion: 1,
          scriptListOffset: 10,
          featureListOffset: 20,
          lookupListOffset: 30,
          featureVariationsOffset: 40,
        );
        final bytes = ByteData(header.size);

        header.encodeToBinary(bytes);

        final decoded = GlyphSubstitutionTableHeader.fromByteData(
          bytes,
          TableRecordEntry(
            'GSUB',
            checkSum: 0,
            offset: 0,
            length: bytes.lengthInBytes,
          ),
        );

        expect(decoded.isV10, isFalse);
        expect(decoded.size, 14);
        expect(decoded.featureVariationsOffset, 40);
      },
    );
  });
}
