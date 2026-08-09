import 'package:fontify_plus/src/otf/cff/char_string_operator.dart' hide escape;
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart'
    as ops
    show escape;
import 'package:fontify_plus/src/otf/cff/operator.dart';
import 'package:test/test.dart';

void main() {
  group('char string operator constants', () {
    test('are all in the charString context', () {
      final all = [
        hstem,
        vstem,
        vmoveto,
        rlineto,
        hlineto,
        vlineto,
        rrcurveto,
        callsubr,
        ops.escape,
        vsindex,
        blend,
        hstemhm,
        hintmask,
        cntrmask,
        rmoveto,
        hmoveto,
        vstemhm,
        rcurveline,
        rlinecurve,
        vvcurveto,
        hhcurveto,
        callgsubr,
        vhcurveto,
        hvcurveto,
        hflex,
        flex,
        hflex1,
        flex1,
        endchar,
      ];

      for (final operator in all) {
        expect(operator.context, CFFOperatorContext.charString);
      }
    });

    test('flex variants are two-byte (escaped) operators', () {
      for (final operator in [hflex, flex, hflex1, flex1]) {
        expect(operator.size, 2);
      }
    });

    test(
      'every named operator except vstem-adjacent ones has a display name',
      () {
        // hstem has no entry in the map (a pre-existing omission — hstem/vstem
        // hint operators are otherwise unused by this package's charstrings).
        final named = [
          vmoveto,
          rlineto,
          hlineto,
          vlineto,
          rrcurveto,
          callsubr,
          ops.escape,
          vsindex,
          blend,
          hstemhm,
          hintmask,
          cntrmask,
          rmoveto,
          hmoveto,
          vstemhm,
          rcurveline,
          rlinecurve,
          vvcurveto,
          hhcurveto,
          callgsubr,
          vhcurveto,
          hvcurveto,
          hflex,
          flex,
          hflex1,
          flex1,
          endchar,
        ];

        for (final operator in named) {
          expect(
            charStringOperatorNames.containsKey(operator),
            isTrue,
            reason: '$operator has no display name',
          );
        }
      },
    );

    test('cannot be modified', () {
      expect(
        () => charStringOperatorNames[rmoveto] = 'changed',
        throwsUnsupportedError,
      );
    });
  });
}
