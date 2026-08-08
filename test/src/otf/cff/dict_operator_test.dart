import 'package:fontify_plus/src/otf/cff/dict_operator.dart' hide escape;
import 'package:fontify_plus/src/otf/cff/dict_operator.dart' as ops show escape;
import 'package:test/test.dart';

void main() {
  group('dict operator constants', () {
    test('every named operator has a display name', () {
      final named = [
        fontMatrix,
        charStrings,
        fdArray,
        fdSelect,
        vstore,
        version,
        notice,
        copyright,
        fullName,
        familyName,
        weight,
        fontBBox,
        charset,
        encoding,
        nominalWidthX,
        private,
        blueValues,
        otherBlues,
        familyBlues,
        familyOtherBlues,
        stdHW,
        stdVW,
        ops.escape,
        subrs,
        vsindex,
        blend,
        bcd,
        blueScale,
        blueShift,
        blueFuzz,
        stemSnapH,
        stemSnapV,
        languageGroup,
        expansionFactor,
      ];

      for (final operator in named) {
        expect(
          dictOperatorNames.containsKey(operator),
          isTrue,
          reason: '$operator has no display name',
        );
      }
    });

    test('the display name map has no duplicate operators', () {
      expect(
        dictOperatorNames.keys.toSet(),
        hasLength(dictOperatorNames.length),
      );
    });

    test('dictOperatorNames cannot be modified', () {
      expect(
        () => dictOperatorNames[charStrings] = 'changed',
        throwsUnsupportedError,
      );
    });
  });
}
