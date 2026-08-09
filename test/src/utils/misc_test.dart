import 'dart:math' as math;

import 'package:fontify_plus/src/utils/misc.dart';
import 'package:test/test.dart';

void main() {
  group('combineHashCode', () {
    test('is deterministic', () {
      expect(combineHashCode(1, 2), combineHashCode(1, 2));
    });

    test('is order-sensitive', () {
      expect(combineHashCode(1, 2), isNot(combineHashCode(2, 1)));
    });

    test('distinguishes different inputs', () {
      expect(combineHashCode(1, 2), isNot(combineHashCode(1, 3)));
    });
  });

  group('MockableDateTime', () {
    tearDown(() => MockableDateTime.mockedDate = null);

    test('falls back to the real clock when unset', () {
      final before = DateTime.now();
      final now = MockableDateTime.now();
      final after = DateTime.now();

      expect(
        now.isAfter(before) || now.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        now.isBefore(after) || now.isAtSameMomentAs(after),
        isTrue,
      );
    });

    test('returns the mocked date once set', () {
      final fixed = DateTime.utc(2020, 1, 1);
      MockableDateTime.mockedDate = fixed;

      expect(MockableDateTime.now(), fixed);
    });
  });

  group('PointExt', () {
    test('toIntPoint truncates toward zero', () {
      expect(const math.Point(1.9, -1.9).toIntPoint(), const math.Point(1, -1));
    });

    test('toDoublePoint converts both components', () {
      expect(
        const math.Point(1, 2).toDoublePoint(),
        const math.Point(1.0, 2.0),
      );
    });

    test('getReflectionOf mirrors its argument across the receiver', () {
      // pivot.getReflectionOf(p) is 2*pivot - p: mirroring (0,0) across the
      // pivot (1,1) lands on (2,2).
      const pivot = math.Point<num>(1, 1);
      const origin = math.Point<num>(0, 0);

      expect(pivot.getReflectionOf(origin), const math.Point(2, 2));
    });

    test('getReflectionOf is its own inverse about the same pivot', () {
      const pivot = math.Point<num>(1, 1);
      const p = math.Point<num>(3, 5);

      expect(pivot.getReflectionOf(pivot.getReflectionOf(p)), p);
    });
  });

  group('constants', () {
    test('kInt32Max and kInt32Min bound a signed 32-bit integer', () {
      expect(kInt32Max, 0x7FFFFFFF);
      expect(kInt32Min, -0x80000000);
    });

    test('the private use area matches the range Unicode defines', () {
      expect(kUnicodePrivateUseAreaStart, 0xE000);
      expect(kUnicodePrivateUseAreaEnd, 0xF8FF);
    });
  });
}
