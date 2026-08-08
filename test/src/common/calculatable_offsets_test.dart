import 'package:fontify_plus/src/common/calculatable_offsets.dart';
import 'package:test/test.dart';

class _NoOverride extends CalculatableOffsets {}

class _Tracking extends CalculatableOffsets {
  bool recalculated = false;

  @override
  void recalculateOffsets() => recalculated = true;
}

void main() {
  group('CalculatableOffsets', () {
    test('the default implementation does nothing and does not throw', () {
      expect(_NoOverride().recalculateOffsets, returnsNormally);
    });

    test('a subclass can override it', () {
      final tracking = _Tracking()..recalculateOffsets();

      expect(tracking.recalculated, isTrue);
    });
  });
}
