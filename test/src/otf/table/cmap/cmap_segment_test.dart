import 'package:fontify_plus/src/otf/table/cmap/cmap_segment.dart';
import 'package:test/test.dart';

void main() {
  group('CmapSegment.idDelta', () {
    test('is the difference between the starting glyph and char codes', () {
      expect(
        const CmapSegment(startCode: 10, endCode: 20, startGlyphID: 3).idDelta,
        -7,
      );
    });
  });

  group('generateSegments', () {
    test('groups consecutive char codes into one segment', () {
      final segments = generateSegments([10, 11, 12]);

      expect(segments, hasLength(1));
      expect(segments.single.startCode, 10);
      expect(segments.single.endCode, 12);
    });

    test('starts a new segment at a gap', () {
      final segments = generateSegments([10, 11, 20, 21]);

      expect(segments, hasLength(2));
      expect(segments[0].startCode, 10);
      expect(segments[0].endCode, 11);
      expect(segments[1].startCode, 20);
      expect(segments[1].endCode, 21);
    });

    test('offsets the starting glyph ID by one for .notdef', () {
      // Glyph 0 is always .notdef and is never in charCodeList, so the first
      // real glyph's ID is 1, not 0.
      final segments = generateSegments([10]);

      expect(segments.single.startGlyphID, 1);
    });

    test('returns nothing for an empty list', () {
      expect(generateSegments([]), isEmpty);
    });

    test('a single char code produces a single-entry segment', () {
      final segments = generateSegments([42]);

      expect(segments.single.startCode, 42);
      expect(segments.single.endCode, 42);
    });
  });
}
