// A variable CFF2 table must carry a vstore, a Top DICT entry pointing at
// it, and charstrings that actually blend. A table that merely parses proves
// nothing here: a font whose axis is ignored renders perfectly.
import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/dict_operator.dart' as op;
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:test/test.dart';

/// A triangle over a 10x10 viewBox, matching cff2_test.dart's fixture.
///
/// [path] lets a second master trace a different-sized triangle while
/// keeping the same M/L/L/Z command structure, which is what keeps the two
/// masters' point counts and on-curve patterns compatible — a prerequisite
/// `toCharStringCommandsForMasters` enforces.
GenericGlyph _triangle([String path = 'M0 0 L10 0 L10 10 Z']) =>
    GenericGlyph.fromSvg(
      'icon',
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<path d="$path"/></svg>',
    );

/// Whether raw charstring [bytes] contain the `blend` operator.
///
/// Byte value 16 (`blend.b0`) is not unique to the operator: it can also
/// turn up as one of a multi-byte operand's trailing bytes (for instance the
/// second byte of a `247..250`-led two-byte number). A bare
/// `bytes.contains(16)` would therefore false-positive on an operand that
/// merely contains the byte value 16, so this instead walks the Type2
/// charstring number encoding — the same leading-byte rules
/// `CFFOperand.fromByteData` decodes — skipping exactly as many bytes as
/// each operand declares, and only treats a byte as the operator it is once
/// every preceding operand has been fully consumed.
bool _hasBlendOperator(Uint8List bytes) {
  var i = 0;

  while (i < bytes.length) {
    final b0 = bytes[i];

    if (b0 == 28) {
      i += 3; // shortint number: leading byte + 2
    } else if (b0 == 255) {
      i += 5; // Fixed 16.16 number: leading byte + 4
    } else if (b0 >= 32 && b0 <= 246) {
      i += 1; // single-byte number, -107..107
    } else if (b0 >= 247 && b0 <= 254) {
      i += 2; // two-byte number, +/-108..1131
    } else if (b0 == blend.b0) {
      return true;
    } else if (b0 == 12) {
      i += 2; // escape: a two-byte operator, not a number
    } else {
      i += 1; // every other charstring operator is one byte
    }
  }

  return false;
}

void main() {
  group('CFF2Table.create with masters', () {
    test(
      'a two-master glyph set produces a vstore and a Top DICT entry '
      'pointing at it',
      () {
        final table = CFF2Table.create([
          [_triangle(), _triangle('M0 0 L13 0 L13 12 Z')],
          [_triangle(), _triangle()],
        ]);

        expect(table.vstoreData, isNotNull);

        final vstoreEntry = table.topDict.getEntryForOperator(op.vstore);
        expect(vstoreEntry, isNotNull);
        expect(vstoreEntry!.operandList.single.value, isNot(0));
      },
    );

    test(
      'the static path — one master per glyph — carries neither a vstore '
      'nor a Top DICT entry for one',
      () {
        final table = CFF2Table.create([
          [_triangle()],
          [_triangle()],
        ]);

        expect(table.vstoreData, isNull);
        expect(table.topDict.getEntryForOperator(op.vstore), isNull);
      },
    );

    test(
      'a glyph whose masters differ blends; a glyph whose masters are '
      'identical does not',
      () {
        final table = CFF2Table.create([
          [_triangle(), _triangle('M0 0 L13 0 L13 12 Z')],
          [_triangle(), _triangle()],
        ]);

        final charStrings = table.charStringsData.data;

        expect(_hasBlendOperator(charStrings[0]), isTrue);
        expect(_hasBlendOperator(charStrings[1]), isFalse);
      },
    );

    test(
      "the table's declared size matches what encodeToBinary actually "
      'writes with a vstore in the layout',
      () {
        // This is what catches a vstore counted in size but laid out at the
        // wrong offset: a mismatch throws (typically a RangeError) rather
        // than silently writing the wrong number of bytes.
        final table = CFF2Table.create([
          [_triangle(), _triangle('M0 0 L13 0 L13 12 Z')],
          [_triangle(), _triangle()],
        ]);

        expect(
          () => table.encodeToBinary(ByteData(table.size)),
          returnsNormally,
        );
      },
    );
  });
}
