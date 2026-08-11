import 'dart:async';

import 'package:fontify_plus/src/common/glyph/glyph_masters.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:test/test.dart';

/// Runs [body] with `print` captured instead of written to stdout.
///
/// Matches `test/src/utils/logger_test.dart`'s helper of the same name —
/// duplicated rather than imported, following the precedent in
/// `test/src/otf/debugger_test.dart`, since importing one test file from
/// another is not this codebase's pattern.
List<String> capturePrints(void Function() body) {
  final lines = <String>[];

  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );

  return lines;
}

const _plus =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/></svg>';

const _strokedSvg = _plus;

// One shape at 1, one at 1.5 — the "hairline detail against thicker main
// strokes" the warning's docs describe.
const _mixedWidthSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/>'
    '<path d="M4 4L8 4" stroke="#000" stroke-width="1" '
    'stroke-linecap="round"/></svg>';

const _curved =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12" stroke="#000" '
    'stroke-width="1.5" stroke-linecap="round"/></svg>';

const _filled =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M4 4H20V20H4Z" fill="#000"/></svg>';

// Not `const`: the constructor validates with a body (throwing
// `ArgumentError`), which a const constructor cannot do.
final _range = StrokeWidthRange(1.33, 2);

void main() {
  group('GlyphMasterBuilder', () {
    test('gives both masters the same point count', () {
      for (final source in [_plus, _curved]) {
        final masters = GlyphMasterBuilder(_range).fromSvg('icon', source);

        expect(
          masters.min.pointList.length,
          masters.max.pointList.length,
          reason: 'masters differ in point count',
        );
        expect(masters.min.isOnCurveList, masters.max.isOnCurveList);
      }
    });

    test('the thick master really is thicker', () {
      final masters = GlyphMasterBuilder(_range).fromSvg('icon', _curved);

      // Same centreline, more ink: the wider master's box is at least as wide
      // and its points are not all identical.
      expect(masters.max.metrics.width, greaterThan(masters.min.metrics.width));
    });

    test('a fill is identical in both masters', () {
      final masters = GlyphMasterBuilder(_range).fromSvg('icon', _filled);

      expect(masters.min.pointList, masters.max.pointList);
    });

    test('rejects a range that is not ascending and positive', () {
      expect(() => StrokeWidthRange(2, 1.33), throwsArgumentError);
      expect(() => StrokeWidthRange(0, 2), throwsArgumentError);
      expect(() => StrokeWidthRange(1.5, 1.5), throwsArgumentError);
    });

    test('an SVG mixing stroke widths is named in a warning', () {
      // The axis overrides stroke-width absolutely, so an icon drawing a
      // detail at 1 and its main strokes at 1.5 loses that hierarchy. Losing
      // it silently is what this prevents.
      final records = capturePrints(
        () => GlyphMasterBuilder(_range).fromSvg('mixed', _mixedWidthSvg),
      );

      expect(records.join('\n'), contains('mixed'));
      expect(records.join('\n'), contains('1.0'));
      expect(records.join('\n'), contains('1.5'));
    });

    test('a single authored width warns about nothing', () {
      final records = capturePrints(
        () => GlyphMasterBuilder(_range).fromSvg('plain', _strokedSvg),
      );

      expect(records, isEmpty);
    });

    test('two mixed-width files are each named in their own warning', () {
      // Each file's message carries its own name, so this cannot tell
      // `logger.w` apart from `logger.logOnce` (the two messages differ and
      // so are never deduplicated either way) — but it does pin the
      // "collapsing across an icon set would hide every file but the first"
      // property the CHANGELOG describes: building an icon set must not
      // lose either file's warning.
      final records = capturePrints(() {
        GlyphMasterBuilder(_range).fromSvg('first', _mixedWidthSvg);
        GlyphMasterBuilder(_range).fromSvg('second', _mixedWidthSvg);
      });

      final joined = records.join('\n');

      expect(joined, contains('first'));
      expect(joined, contains('second'));
    });

    test('the same name warns every time, not only the first', () {
      // This is what actually distinguishes `logger.w` from `logger.logOnce`:
      // with the file's name baked into the message, two *different* names
      // never collide in `logOnce`'s dedup set regardless of which method is
      // used (see the test above), so only two calls that would produce the
      // exact same message can tell them apart.
      final records = capturePrints(() {
        GlyphMasterBuilder(_range).fromSvg('same', _mixedWidthSvg);
        GlyphMasterBuilder(_range).fromSvg('same', _mixedWidthSvg);
      });

      expect(records, hasLength(2));
    });
  });
}
