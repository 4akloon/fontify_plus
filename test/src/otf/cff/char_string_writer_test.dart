import 'package:fontify_plus/src/otf/cff/char_string_command.dart';
import 'package:fontify_plus/src/otf/cff/char_string_writer.dart';
import 'package:test/test.dart';

void main() {
  group('CharStringWriter', () {
    test('writes each command as its operands followed by its operator', () {
      const writer = CharStringWriter(isCFF1: false);
      final bytes = writer.writeCommands([CharStringCommand.hmoveto(5)]);

      // hmoveto(5): one 1-byte operand (139+5=144), then the operator (22+139
      // encoded per the standard 1-byte integer bias — checked via decoding
      // instead of hand-computing the bias).
      expect(bytes.lengthInBytes, 2);
      expect(bytes.getUint8(1), 22); // hmoveto's operator byte
    });

    test('CFF1 with a glyph width writes it as a leading operand', () {
      const writer = CharStringWriter(isCFF1: true);
      final withWidth = writer.writeCommands([
        CharStringCommand.hmoveto(5),
      ], glyphWidth: 500);
      final withoutWidth = const CharStringWriter(isCFF1: true).writeCommands(
        [CharStringCommand.hmoveto(5)],
      );

      expect(withWidth.lengthInBytes, greaterThan(withoutWidth.lengthInBytes));
    });

    test('CFF2 ignores a glyph width even if one is given', () {
      const writer = CharStringWriter(isCFF1: false);
      final withWidth = writer.writeCommands([
        CharStringCommand.hmoveto(5),
      ], glyphWidth: 500);
      final withoutWidth = writer.writeCommands([CharStringCommand.hmoveto(5)]);

      expect(withWidth.lengthInBytes, withoutWidth.lengthInBytes);
    });

    test('a glyph width of null writes no leading operand even for CFF1', () {
      const writer = CharStringWriter(isCFF1: true);
      final withNullWidth = writer.writeCommands([
        CharStringCommand.hmoveto(5),
      ]);
      final direct = const CharStringWriter(
        isCFF1: false,
      ).writeCommands([CharStringCommand.hmoveto(5)]);

      expect(withNullWidth.lengthInBytes, direct.lengthInBytes);
    });

    test('concatenates multiple commands in order', () {
      const writer = CharStringWriter(isCFF1: false);
      final bytes = writer.writeCommands([
        CharStringCommand.hmoveto(5),
        CharStringCommand.rlineto([1, 2]),
      ]);

      // hmoveto (1 operand byte + 1 operator byte) + rlineto (2 operand bytes
      // + 1 operator byte).
      expect(bytes.lengthInBytes, 2 + 3);
    });

    test('writes nothing for an empty command list', () {
      const writer = CharStringWriter(isCFF1: false);

      expect(writer.writeCommands([]).lengthInBytes, 0);
    });
  });
}
