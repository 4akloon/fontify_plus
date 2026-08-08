import 'package:fontify_plus/src/svg/stroke/sub_path.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// [Vector2] is float32-backed, so seven significant digits is the ceiling.
const _kEpsilon = 1e-5;

List<SubPath> build(String pathData) => SubPathBuilder().build(pathData);

void main() {
  group('SubPath', () {
    test('end is the start until a segment is added', () {
      final subPath = SubPath(Vector2(3, 4));

      expect(subPath.end, subPath.start);
      expect(subPath.closed, isFalse);
    });

    test('reversedSegments walks the contour backwards', () {
      final subPath = build('M0 0 L10 0 L10 10').single;
      final reversed = subPath.reversedSegments;

      expect(reversed, hasLength(subPath.segments.length));
      expect(reversed.first.p0.distanceTo(subPath.end), lessThan(_kEpsilon));
      expect(reversed.last.p3.distanceTo(subPath.start), lessThan(_kEpsilon));
    });

    test('reversedSegments does not disturb the original', () {
      final subPath = build('M0 0 L10 0').single;
      final before = subPath.segments.single.p0.clone();

      subPath.reversedSegments;

      expect(subPath.segments.single.p0, before);
    });
  });

  group('SubPathBuilder', () {
    test('reads a line as one segment', () {
      final subPath = build('M0 0 L10 0').single;

      expect(subPath.segments, hasLength(1));
      expect(subPath.start.x, closeTo(0, _kEpsilon));
      expect(subPath.end.x, closeTo(10, _kEpsilon));
      expect(subPath.closed, isFalse);
    });

    test('reads a cubic as one segment with its control points', () {
      final subPath = build('M0 0 C0 5 10 5 10 0').single;
      final segment = subPath.segments.single;

      expect(segment.p1.y, closeTo(5, _kEpsilon));
      expect(segment.p2.x, closeTo(10, _kEpsilon));
      expect(segment.p3.x, closeTo(10, _kEpsilon));
    });

    test('starts a new subpath at every moveTo', () {
      // Two separate strokes with no close in between. Accumulating them into
      // one contour is what used to render an icon as a single zigzag.
      final subPaths = build('M8 2 V13 M13 8 H2');

      expect(subPaths, hasLength(2));
    });

    test('closes a contour by joining the last point back to the first', () {
      final subPath = build('M0 0 L10 0 L10 10 Z').single;

      expect(subPath.closed, isTrue);
      expect(subPath.segments, hasLength(3));
      expect(
        subPath.segments.last.p3.distanceTo(subPath.start),
        lessThan(_kEpsilon),
      );
    });

    test('adds no closing segment when the path already ends at its start', () {
      final subPath = build('M0 0 L10 0 L10 10 L0 0 Z').single;

      expect(subPath.closed, isTrue);
      expect(subPath.segments, hasLength(3));
    });

    test('drops zero-length line segments', () {
      // A repeated point carries no geometry, and offsetting it would divide
      // by its own length.
      final subPath = build('M0 0 L0 0 L10 0').single;

      expect(subPath.segments, hasLength(1));
    });

    test('discards a subpath with no segments', () {
      expect(build('M5 5'), isEmpty);
    });

    test('returns nothing for empty path data', () {
      expect(build(''), isEmpty);
    });

    test('keeps subpaths in document order', () {
      final subPaths = build('M0 0 L1 0 M100 100 L101 100');

      expect(subPaths.first.start.x, closeTo(0, _kEpsilon));
      expect(subPaths.last.start.x, closeTo(100, _kEpsilon));
    });
  });
}
