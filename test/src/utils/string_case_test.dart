import 'package:fontify_plus/src/utils/string_case.dart';
import 'package:test/test.dart';

void main() {
  group('splitWords', () {
    test('splits on hyphens', () {
      expect(splitWords('arrow-up'), ['arrow', 'up']);
    });

    test('splits on underscores', () {
      expect(splitWords('arrow_up'), ['arrow', 'up']);
    });

    test('splits on spaces', () {
      expect(splitWords('arrow up'), ['arrow', 'up']);
    });

    test('splits on camelCase humps', () {
      expect(splitWords('arrowUp'), ['arrow', 'Up']);
    });

    test('splits on PascalCase humps', () {
      expect(splitWords('ArrowUp'), ['Arrow', 'Up']);
    });

    test('treats an all-uppercase string as a single word', () {
      // Otherwise an acronym like "SVG" would be read as three one-letter
      // words instead of one.
      expect(splitWords('SVG'), ['SVG']);
    });

    test('returns nothing for an empty string', () {
      expect(splitWords(''), isEmpty);
    });

    test('drops separators with nothing between them', () {
      expect(splitWords('arrow--up'), ['arrow', 'up']);
    });

    test('handles a single word with no separators or humps', () {
      expect(splitWords('arrow'), ['arrow']);
    });
  });

  group('String.camelCase', () {
    test('joins hyphenated words into lowerCamelCase', () {
      expect('arrow-up'.camelCase, 'arrowUp');
    });

    test('joins snake_case words into lowerCamelCase', () {
      expect('arrow_up'.camelCase, 'arrowUp');
    });

    test('joins space-separated words into lowerCamelCase', () {
      expect('arrow up'.camelCase, 'arrowUp');
    });

    test('lowercases the first word even if it was capitalised', () {
      expect('Arrow-Up'.camelCase, 'arrowUp');
    });

    test('keeps a name with a numeric suffix intact', () {
      // "alert_02" must not have its digits reinterpreted; camelCase only
      // marks word boundaries, it does not parse the trailing number.
      expect('alert_02'.camelCase, 'alert02');
    });

    test('does not insert a boundary before an already-lowercase run', () {
      expect('more_vertical'.camelCase, 'moreVertical');
    });

    test('returns an empty string for an empty input', () {
      expect(''.camelCase, '');
    });

    test('is idempotent on an already-camelCase string', () {
      expect('arrowUp'.camelCase, 'arrowUp');
    });

    test('the all-caps heuristic only covers a fully uppercase input', () {
      // splitWords' "is all caps" check looks at the whole string, so an
      // acronym mixed with lowercase text — unlike a bare "SVG" — still splits
      // on every hump. A real but narrow limitation, not exercised by the
      // sanitize-then-camelCase icon names this exists for.
      expect('SVG-icon'.camelCase, 'sVGIcon');
    });

    test('treats a standalone all-caps input as one word', () {
      expect('SVG'.camelCase, 'svg');
    });
  });
}
