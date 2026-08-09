import 'package:fontify_plus/src/svg/geometry/tolerances.dart';
import 'package:test/test.dart';

void main() {
  group('tolerances', () {
    test('the curve tolerance is well under a font unit at 1000 upem', () {
      // Icons are authored in a 16- or 24-unit viewBox and scaled onto the em
      // square. If this ever grew past about 0.024 the error would exceed one
      // font unit and start showing.
      expect(kCurveTolerance * (1000 / 24), lessThan(1));
    });

    test('the epsilons are far below the curve tolerance', () {
      // They guard numerical noise, not visible error. If they ever came close
      // to the tolerance, real geometry would be silently discarded as noise.
      expect(kPointEpsilon, lessThan(kCurveTolerance / 1e6));
      expect(kZeroLength, lessThanOrEqualTo(kPointEpsilon));
      expect(kZeroLengthSquared, lessThanOrEqualTo(kPointEpsilon));
    });

    test('all are positive', () {
      for (final tolerance in [
        kCurveTolerance,
        kPointEpsilon,
        kZeroLength,
        kZeroLengthSquared,
      ]) {
        expect(tolerance, greaterThan(0));
      }
    });
  });
}
