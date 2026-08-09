import 'package:fontify_plus/src/utils/class_gen/icon_name_allocator.dart';
import 'package:test/test.dart';

void main() {
  group('IconNameAllocator', () {
    test('camelCases a hyphenated name', () {
      expect(IconNameAllocator().allocate('arrow-up'), 'arrowUp');
    });

    test('strips a file extension', () {
      expect(IconNameAllocator().allocate('arrow-up.svg'), 'arrowUp');
    });

    test('camelCases path segments separated by slashes', () {
      final allocator = IconNameAllocator();

      expect(allocator.allocate('a/x'), 'aX');
      expect(allocator.allocate('b/x'), 'bX');
    });

    test('falls back to "unnamed" when nothing legal survives', () {
      expect(IconNameAllocator().allocate('123'), 'unnamed');
    });

    test('gives distinct names to distinct icons', () {
      final allocator = IconNameAllocator();

      expect(allocator.allocate('arrow-up'), 'arrowUp');
      expect(allocator.allocate('arrow-down'), 'arrowDown');
    });

    test('disambiguates a name that collides with an earlier one', () {
      final allocator = IconNameAllocator();

      allocator.allocate('alert');
      expect(allocator.allocate('alert'), 'alert2');
    });

    test('keeps disambiguating past the second collision', () {
      final allocator = IconNameAllocator();

      allocator.allocate('alert');
      allocator.allocate('alert');
      expect(allocator.allocate('alert'), 'alert3');
    });

    test('does not read an existing trailing digit as a collision counter', () {
      // "alert_02" becomes "alert02" — a name of its own, not a claim on the
      // slot "alert2". A later, unrelated collision between two "alert" icons
      // must still land on "alert2": a naive implementation that read the "02"
      // as a counter and continued from it would skip straight to "alert3".
      final allocator = IconNameAllocator();

      expect(allocator.allocate('alert_02'), 'alert02');
      expect(allocator.allocate('alert'), 'alert');
      expect(allocator.allocate('alert'), 'alert2');
    });

    test('the disambiguating suffix has no separator, to stay camelCase', () {
      final allocator = IconNameAllocator();

      allocator.allocate('arrow-up');
      final second = allocator.allocate('arrow-up');

      expect(second, isNot(contains('_')));
      expect(second, isNot(contains('-')));
    });

    test('allocations of the same allocator do not repeat', () {
      final allocator = IconNameAllocator();
      final names = [
        allocator.allocate('a'),
        allocator.allocate('a'),
        allocator.allocate('a'),
      ];

      expect(names.toSet(), hasLength(3));
    });

    test('different allocators track collisions independently', () {
      expect(
        IconNameAllocator().allocate('alert'),
        IconNameAllocator().allocate('alert'),
      );
    });
  });
}
