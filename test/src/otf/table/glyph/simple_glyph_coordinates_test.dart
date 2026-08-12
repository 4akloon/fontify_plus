import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:fontify_plus/src/otf/table/glyph/simple_glyph_coordinates.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphAxis.isShort / isSameOrPositive', () {
    test('x reads the x-specific bits', () {
      final flag = SimpleGlyphFlag.createForPoint(
        x: 10,
        y: -300,
        isOnCurve: true,
      );

      expect(GlyphAxis.x.isShort(flag), isTrue);
      expect(GlyphAxis.x.isSameOrPositive(flag), isTrue);
    });

    test('y reads the y-specific bits', () {
      final flag = SimpleGlyphFlag.createForPoint(
        x: 10,
        y: -300,
        isOnCurve: true,
      );

      expect(GlyphAxis.y.isShort(flag), isFalse);
      expect(GlyphAxis.y.isSameOrPositive(flag), isFalse);
    });
  });

  group('readCoordinates / writeCoordinates round trip', () {
    test('round-trips a mix of short, long, and zero deltas', () {
      final points = [
        const math.Point<num>(5, -5),
        const math.Point<num>(0, 300),
        const math.Point<num>(-300, 0),
      ];
      final flags = [
        for (final p in points)
          SimpleGlyphFlag.createForPoint(
            x: p.x.toInt(),
            y: p.y.toInt(),
            isOnCurve: true,
          ),
      ];

      final xs = [for (final p in points) p.x.toInt()];
      final ys = [for (final p in points) p.y.toInt()];

      var size = 0;
      for (final flag in flags) {
        size += GlyphAxis.x.isShort(flag)
            ? 1
            : (GlyphAxis.x.isSameOrPositive(flag) ? 0 : 2);
      }
      for (final flag in flags) {
        size += GlyphAxis.y.isShort(flag)
            ? 1
            : (GlyphAxis.y.isSameOrPositive(flag) ? 0 : 2);
      }

      final bytes = ByteData(size);
      final afterX = writeCoordinates(
        bytes,
        0,
        flags,
        xs,
        flags.length,
        GlyphAxis.x,
      );
      writeCoordinates(bytes, afterX, flags, ys, flags.length, GlyphAxis.y);

      final (decodedX, afterReadX) = readCoordinates(
        bytes,
        0,
        flags,
        flags.length,
        GlyphAxis.x,
      );
      final (decodedY, _) = readCoordinates(
        bytes,
        afterReadX,
        flags,
        flags.length,
        GlyphAxis.y,
      );

      expect(decodedX, xs);
      expect(decodedY, ys);
      expect(afterReadX, afterX);
    });

    test('a short negative delta round-trips to the same sign', () {
      final flag = SimpleGlyphFlag.createForPoint(
        x: -100,
        y: 0,
        isOnCurve: true,
      );
      final bytes = ByteData(1);

      writeCoordinates(bytes, 0, [flag], [-100], 1, GlyphAxis.x);
      final (decoded, _) = readCoordinates(bytes, 0, [flag], 1, GlyphAxis.x);

      expect(decoded, [-100]);
    });
  });
}
