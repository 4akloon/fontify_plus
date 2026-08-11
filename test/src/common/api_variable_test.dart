import 'package:fontify_plus/src/common/api.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

const _strokedSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/></svg>';

void main() {
  group('svgToOtf with strokeWidthRange', () {
    test('a range without stroke outlining is an error, not a warning', () {
      // There is nothing to vary: outlineStrokes: false treats path data as
      // fill geometry, and a fill does not depend on stroke width. Silently
      // producing a font whose axis moves nothing is the worst outcome.
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          outlineStrokes: false,
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        ),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            contains('outlineStrokes'),
          ),
        ),
      );
    });

    test('a range with TrueType outlines is an error', () {
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          useOpenType: false,
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        ),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            contains('useOpenType'),
          ),
        ),
      );
    });

    test('a range with the defaults left null builds normally', () {
      // outlineStrokes: null and useOpenType: null mean "use the default",
      // which is true for both — validation must not mistake "unset" for
      // "false".
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        ),
        returnsNormally,
      );
    });

    test('builds a variable font with both masters', () {
      final result = svgToOtf(
        svgMap: {'a': _strokedSvg},
        strokeWidthRange: StrokeWidthRange(1.33, 2),
      );

      expect(result.font.tableMap.containsKey(kFvarTag), isTrue);
      expect(result.font.tableMap.containsKey(kCFF2Tag), isTrue);
    });

    test('without a range nothing about the output changes', () {
      final result = svgToOtf(svgMap: {'a': _strokedSvg});

      expect(result.font.tableMap.containsKey(kFvarTag), isFalse);
      expect(result.font.tableMap.containsKey(kCFFTag), isTrue);
    });
  });
}
