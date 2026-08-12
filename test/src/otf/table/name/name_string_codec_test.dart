import 'package:fontify_plus/src/otf/table/name/name_record.dart';
import 'package:fontify_plus/src/otf/table/name/name_string_codec.dart';
import 'package:test/test.dart';

void main() {
  group('encoderFor / decoderFor', () {
    test('Windows records use UTF-16BE', () {
      const record = NameRecord.template(
        platformID: 3,
        encodingID: 1,
        languageID: 0x0409,
      );

      expect(encoderFor(record)('A'), [0x00, 0x41]);
      expect(decoderFor(record)([0x00, 0x41]), 'A');
    });

    test('non-Windows records use plain code units', () {
      const record = NameRecord.template(
        platformID: 1,
        encodingID: 0,
        languageID: 0,
      );

      expect(encoderFor(record)('A'), [0x41]);
      expect(decoderFor(record)([0x41]), 'A');
    });

    test('round-trips a string through the matching pair', () {
      const record = NameRecord.template(
        platformID: 3,
        encodingID: 1,
        languageID: 0x0409,
      );
      const text = 'Hello';

      expect(decoderFor(record)(encoderFor(record)(text)), text);
    });
  });
}
