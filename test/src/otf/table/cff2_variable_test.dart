// A variable CFF2 table must carry a vstore, a Top DICT entry pointing at
// it, and charstrings that actually blend. A table that merely parses proves
// nothing here: a font whose axis is ignored renders perfectly.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/dict_operator.dart' as op;
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/utils/otf.dart';
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

/// A [segmentCount]-segment zigzag, offset by [dy] every other point.
///
/// Every segment moves by a constant, nonzero dx and an alternating,
/// nonzero dy, so the encoder emits a uniform run of two-operand `rlineto`
/// commands with nothing to collapse into a `vmoveto`/`hlineto` shorthand —
/// which is what lets the optimizer's same-operator merge run all the way
/// out to its stack limit. Two calls with different [dy] make masters whose
/// every segment actually differs, so every merged command really blends
/// rather than folding back to the no-op-blend shortcut.
GenericGlyph _zigzag(int segmentCount, int dy) {
  final points = [
    for (var i = 0; i <= segmentCount; i++)
      math.Point<num>(i * 3, dy * (i % 2)),
  ];

  return GenericGlyph(
    [
      Outline(
        points,
        List.filled(points.length, true),
        false,
        false,
        FillRule.nonzero,
      ),
    ],
    math.Rectangle<num>(0, 0, segmentCount * 3, dy),
    GenericGlyphMetadata(name: 'zigzag'),
  );
}

/// One decoded charstring operator, plus how many operand tokens the walk
/// in [_decodeOperators] saw immediately before it — the argument-stack
/// depth right as that operator runs (every operator this package's encoder
/// emits, including `blend`'s consumer, clears the stack it read from).
class _DecodedOperator {
  const _DecodedOperator(this.byte, this.precedingOperandCount);

  final int byte;
  final int precedingOperandCount;
}

/// Decodes raw charstring [bytes] into its operators, in order.
///
/// Numbers and operators share the byte-value space, so telling them apart
/// requires walking the Type2 charstring number encoding rather than
/// scanning for byte values directly — the same leading-byte rules
/// `CFFOperand.fromByteData` decodes, plus charstrings' own `255` (Fixed
/// 16.16) that DICTs don't use: `28` (3-byte shortint), `29` (5-byte int32 —
/// `CFFOperand._encodeInt` emits this for any value outside -32768..32767,
/// which a large enough coordinate can reach), `32..246` (1 byte), `247..254`
/// (2 bytes), `255` (5 bytes). Everything else is an operator: `12` is
/// two bytes (escape), every other operator is one byte.
///
/// This does NOT decode `30` (a DICT real number, never emitted into a
/// charstring by this package) or the trailing hint-mask bytes `hintmask`/
/// `cntrmask` (19/20) carry — this package's encoder never emits stem hints,
/// so those two operators never appear in output this decoder is asked to
/// read. Either one appearing would desync the walk.
List<_DecodedOperator> _decodeOperators(Uint8List bytes) {
  final operators = <_DecodedOperator>[];
  var i = 0;
  var operandCount = 0;

  while (i < bytes.length) {
    final b0 = bytes[i];

    if (b0 == 28) {
      i += 3; // shortint
      operandCount++;
    } else if (b0 == 29) {
      i += 5; // int32
      operandCount++;
    } else if (b0 == 255) {
      i += 5; // Fixed 16.16
      operandCount++;
    } else if (b0 >= 32 && b0 <= 246) {
      i += 1; // -107..107
      operandCount++;
    } else if (b0 >= 247 && b0 <= 254) {
      i += 2; // +/-108..1131
      operandCount++;
    } else {
      operators.add(_DecodedOperator(b0, operandCount));
      operandCount = 0;
      i += b0 == 12 ? 2 : 1; // escape is two bytes, every other op is one
    }
  }

  return operators;
}

/// Whether raw charstring [bytes] contain the `blend` operator.
bool _hasBlendOperator(Uint8List bytes) =>
    _decodeOperators(bytes).any((decoded) => decoded.byte == blend.b0);

/// The highest argument-stack depth any operator in [bytes] runs with.
int _maxOperandRun(Uint8List bytes) => _decodeOperators(bytes).fold(
  0,
  (max, decoded) =>
      decoded.precedingOperandCount > max ? decoded.precedingOperandCount : max,
);

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

        // The operand being non-zero only rules out the entry being
        // unwritten; it says nothing about whether it points at the right
        // place. Round-tripping through the package's own reader is what
        // actually proves the offset lands on real region data.
        final bytes = ByteData(table.size);
        table.encodeToBinary(bytes);

        final decoded = CFF2Table.fromByteData(
          bytes,
          TableRecordEntry(kCFF2Tag, 0, 0, bytes.lengthInBytes),
        );
        expect(
          decoded
              .vstoreData!
              .store
              .variationRegionList
              .regions
              .single
              .peakCoord,
          0xC000,
        );
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

    test(
      'a many-segment two-master glyph never emits more than 513 operands '
      'for one operator',
      () {
        // 513 is the CFF2 interpreter's argument-stack ceiling
        // (char_string_limits.dart). The optimizer is only told to respect
        // it once cff2_builder.dart wires the real region count into
        // CharStringOptimizer; passing regionCount: 0 here instead (as
        // CharStringOptimizer(false) alone would) lets a merged command
        // grow to 512 pre-blend operands, which blend then expands to
        // 512 * (1 + 1) + 1 = 1025 — double the ceiling — and nothing
        // downstream of the optimizer would catch that.
        final table = CFF2Table.create([
          [_zigzag(300, 5), _zigzag(300, 7)],
        ]);

        final maxRun = _maxOperandRun(table.charStringsData.data.single);

        expect(maxRun, lessThanOrEqualTo(513));
        // And it actually reaches the ceiling this glyph was sized to hit,
        // rather than passing by staying comfortably under it.
        expect(maxRun, 513);
      },
    );

    test(
      'more than two masters is rejected — the store this builder attaches '
      'only ever encodes one region',
      () {
        final varies = _triangle('M0 0 L13 0 L13 12 Z');
        final variesMore = _triangle('M0 0 L16 0 L16 14 Z');

        expect(
          () => CFF2Table.create([
            [_triangle(), varies, variesMore],
          ]),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('singleRegionVariationStore'),
            ),
          ),
        );
      },
    );

    test('a glyph with no masters at all is rejected, not divided by zero', () {
      expect(
        () => CFF2Table.create([[]]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at least one master'),
          ),
        ),
      );
    });
  });
}
