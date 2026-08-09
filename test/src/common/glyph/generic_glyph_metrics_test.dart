import 'package:fontify_plus/src/common/glyph/generic_glyph_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('GenericGlyphMetrics', () {
    test('exposes the bounds it was constructed with', () {
      final metrics = GenericGlyphMetrics(1, 5, 2, 8);

      expect(metrics.xMin, 1);
      expect(metrics.xMax, 5);
      expect(metrics.yMin, 2);
      expect(metrics.yMax, 8);
    });

    test('width and height are the extents\' differences', () {
      final metrics = GenericGlyphMetrics(1, 5, 2, 8);

      expect(metrics.width, 4);
      expect(metrics.height, 6);
    });

    test('.empty is a zero-sized box at the origin', () {
      final metrics = GenericGlyphMetrics.empty();

      expect(metrics.width, 0);
      expect(metrics.height, 0);
    });

    test('.square spans the full em from the origin', () {
      final metrics = GenericGlyphMetrics.square(1000);

      expect(metrics.xMin, 0);
      expect(metrics.yMin, 0);
      expect(metrics.width, 1000);
      expect(metrics.height, 1000);
    });
  });
}
