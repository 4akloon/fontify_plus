import 'package:fontify_plus/src/utils/otf/revision.dart';
import 'package:test/test.dart';

void main() {
  group('Revision', () {
    test('major and minor default to zero when null', () {
      const revision = Revision(null, null);

      expect(revision.major, 0);
      expect(revision.minor, 0);
    });

    test('int32value packs major into the high word', () {
      expect(const Revision(1, 0).int32value, 0x00010000);
    });

    test('int32value packs minor into the low word', () {
      expect(const Revision(0, 5).int32value, 0x00000005);
    });

    test('fromInt32 is the inverse of int32value', () {
      const original = Revision(2, 500);

      expect(Revision.fromInt32(original.int32value), original);
    });

    test('equal major/minor pairs are equal', () {
      expect(const Revision(1, 0), const Revision(1, 0));
    });

    test('equal revisions have equal hash codes', () {
      expect(const Revision(1, 0).hashCode, const Revision(1, 0).hashCode);
    });

    test('differing minor makes revisions unequal', () {
      expect(const Revision(1, 0), isNot(const Revision(1, 1)));
    });

    test('is not equal to an unrelated type', () {
      // ignore: unrelated_type_equality_checks
      expect(const Revision(1, 0) == 'not a revision', isFalse);
    });
  });
}
