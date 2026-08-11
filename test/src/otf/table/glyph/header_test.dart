import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/glyph/header.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphHeader.isComposite', () {
    test('is false for a non-negative contour count', () {
      final header = GlyphHeader(
        numberOfContours: 1,
        xMin: 0,
        yMin: 0,
        xMax: 10,
        yMax: 10,
      );

      expect(header.isComposite, isFalse);
    });

    test('is true for a negative contour count', () {
      final header = GlyphHeader(
        numberOfContours: -1,
        xMin: 0,
        yMin: 0,
        xMax: 10,
        yMax: 10,
      );

      expect(header.isComposite, isTrue);
    });
  });

  group('GlyphHeader', () {
    test('size is fixed at 10 bytes', () {
      final header = GlyphHeader(
        numberOfContours: 1,
        xMin: 0,
        yMin: 0,
        xMax: 10,
        yMax: 10,
      );

      expect(header.size, 10);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final header = GlyphHeader(
        numberOfContours: 2,
        xMin: -5,
        yMin: -6,
        xMax: 100,
        yMax: 200,
      );
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);
      final decoded = GlyphHeader.fromByteData(bytes, 0);

      expect(decoded.numberOfContours, 2);
      expect(decoded.xMin, -5);
      expect(decoded.yMin, -6);
      expect(decoded.xMax, 100);
      expect(decoded.yMax, 200);
    });
  });
}
