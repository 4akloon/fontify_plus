import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';

void main() {
  group('StrokeProperties', () {
    test('radius is half the width', () {
      expect(const StrokeProperties(width: 3).radius, 1.5);
      expect(const StrokeProperties(width: 0).radius, 0);
    });

    test('defaults match SVG initial values', () {
      const stroke = StrokeProperties(width: 1);

      expect(stroke.cap, LineCap.butt);
      expect(stroke.join, LineJoin.miter);
      expect(stroke.miterLimit, 4);
    });

    test('toString names every field that affects geometry', () {
      const stroke = StrokeProperties(
        width: 2,
        cap: LineCap.round,
        join: LineJoin.bevel,
        miterLimit: 7,
      );

      final description = stroke.toString();

      expect(description, contains('2'));
      expect(description, contains('LineCap.round'));
      expect(description, contains('LineJoin.bevel'));
      expect(description, contains('7'));
    });
  });

  group('LineCap', () {
    test('covers exactly what SVG defines', () {
      expect(LineCap.values, [LineCap.butt, LineCap.round, LineCap.square]);
    });
  });

  group('LineJoin', () {
    test('covers exactly what SVG defines', () {
      expect(LineJoin.values, [LineJoin.miter, LineJoin.round, LineJoin.bevel]);
    });
  });
}
