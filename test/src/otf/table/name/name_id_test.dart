import 'package:fontify_plus/src/otf/table/name/name_id.dart';
import 'package:test/test.dart';

void main() {
  group('kNameIDmap', () {
    test('every NameID value has a wire value', () {
      for (final id in NameID.values) {
        expect(kNameIDmap.getValueForKey(id), isNotNull, reason: '$id');
      }
    });

    test('deliberately skips 7 and 9', () {
      expect(kNameIDmap.values, isNot(contains(7)));
      expect(kNameIDmap.values, isNot(contains(9)));
    });

    test('wire values are pairwise distinct', () {
      expect(kNameIDmap.values.toSet(), hasLength(NameID.values.length));
    });

    test('fontFamily is name ID 1, the one most consumers read', () {
      expect(kNameIDmap.getValueForKey(NameID.fontFamily), 1);
    });
  });
}
