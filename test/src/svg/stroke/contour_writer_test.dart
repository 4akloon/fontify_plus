import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/stroke/contour_writer.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const _writer = ContourWriter();

void main() {
  group('ContourWriter', () {
    test('writes nothing for no contours', () {
      expect(_writer.write([]), isEmpty);
    });

    test('skips an empty contour', () {
      expect(_writer.write([[]]), isEmpty);
    });

    test('opens with a move and closes with Z', () {
      final data = _writer.write([
        [Cubic.line(Vector2(1, 2), Vector2(3, 4))],
      ]);

      expect(data, startsWith('M1 2'));
      expect(data, endsWith('Z'));
    });

    test('writes a straight segment as a line, not a curve', () {
      // Joins and caps produce plenty of straight pieces; six coordinates
      // each would undo much of what offsetting curves directly buys.
      final data = _writer.write([
        [Cubic.line(Vector2(0, 0), Vector2(10, 0))],
      ]);

      expect(data, contains('L10 0'));
      expect(data, isNot(contains('C')));
    });

    test('writes a curved segment as a cubic', () {
      final data = _writer.write([
        [Cubic(Vector2(0, 0), Vector2(0, 5), Vector2(10, 5), Vector2(10, 0))],
      ]);

      expect(data, contains('C'));
    });

    test('treats a control point off the chord as curved', () {
      // On the chord but past the end point: the segment doubles back, so it
      // is not a straight run from p0 to p3.
      final data = _writer.write([
        [Cubic(Vector2(0, 0), Vector2(20, 0), Vector2(5, 0), Vector2(10, 0))],
      ]);

      expect(data, contains('C'));
    });

    test('writes each contour as its own closed subpath', () {
      final data = _writer.write([
        [Cubic.line(Vector2(0, 0), Vector2(1, 0))],
        [Cubic.line(Vector2(5, 5), Vector2(6, 5))],
      ]);

      expect('M'.allMatches(data), hasLength(2));
      expect('Z'.allMatches(data), hasLength(2));
    });

    test('trims float noise to whole numbers where it can', () {
      final data = _writer.write([
        [Cubic.line(Vector2(0, 0), Vector2(2.00000001, 3.5))],
      ]);

      expect(data, contains('L2 3.5'));
    });

    test('keeps four decimals of a genuinely fractional coordinate', () {
      final data = _writer.write([
        [Cubic.line(Vector2(0, 0), Vector2(1.23456789, 0))],
      ]);

      expect(data, contains('1.2346'));
    });

    test('a degenerate segment is written as a line', () {
      final point = Vector2(4, 4);
      final data = _writer.write([
        [Cubic(point, point, point, point)],
      ]);

      expect(data, 'M4 4L4 4Z');
    });
  });
}
