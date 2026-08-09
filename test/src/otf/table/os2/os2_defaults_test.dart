import 'package:fontify_plus/src/otf/table/os2/os2_defaults.dart';
import 'package:test/test.dart';

void main() {
  group('kDefaultPANOSE', () {
    test('has exactly 10 entries, as the PANOSE spec requires', () {
      expect(kDefaultPANOSE, hasLength(10));
    });
  });

  group('sub/superscript and strikeout ratios', () {
    test('are all fractions between 0 and 1', () {
      const ratios = [
        kDefaultSubscriptRelativeXsize,
        kDefaultSubscriptRelativeYsize,
        kDefaultSubscriptRelativeYoffset,
        kDefaultSuperscriptRelativeYoffset,
        kDefaultStrikeoutRelativeSize,
        kDefaultStrikeoutRelativeOffset,
      ];

      for (final ratio in ratios) {
        expect(ratio, greaterThan(0));
        expect(ratio, lessThan(1));
      }
    });
  });
}
