import 'package:fontify_plus/src/common/glyph/glyph_masters.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:test/test.dart';

const _plus =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/></svg>';

const _curved =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12" stroke="#000" '
    'stroke-width="1.5" stroke-linecap="round"/></svg>';

const _filled =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M4 4H20V20H4Z" fill="#000"/></svg>';

// Not `const`: the constructor validates with a body (throwing
// `ArgumentError`), which a const constructor cannot do.
final _range = StrokeWidthRange(1.33, 2);

void main() {
  group('glyphMastersFromSvg', () {
    test('gives both masters the same point count', () {
      for (final source in [_plus, _curved]) {
        final masters = glyphMastersFromSvg('icon', source, _range);

        expect(
          masters.min.pointList.length,
          masters.max.pointList.length,
          reason: 'masters differ in point count',
        );
        expect(masters.min.isOnCurveList, masters.max.isOnCurveList);
      }
    });

    test('the thick master really is thicker', () {
      final masters = glyphMastersFromSvg('icon', _curved, _range);

      // Same centreline, more ink: the wider master's box is at least as wide
      // and its points are not all identical.
      expect(masters.max.metrics.width, greaterThan(masters.min.metrics.width));
    });

    test('a fill is identical in both masters', () {
      final masters = glyphMastersFromSvg('icon', _filled, _range);

      expect(masters.min.pointList, masters.max.pointList);
    });

    test('rejects a range that is not ascending and positive', () {
      expect(() => StrokeWidthRange(2, 1.33), throwsArgumentError);
      expect(() => StrokeWidthRange(0, 2), throwsArgumentError);
      expect(() => StrokeWidthRange(1.5, 1.5), throwsArgumentError);
    });
  });
}
