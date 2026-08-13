import 'dart:io';

import 'package:fontify_plus/fontify_plus.dart';
import 'package:test/test.dart';

/// The order `example/lib/my_icons.dart` assigns codepoints in, and so the
/// order the checked-in font's glyphs were built in.
///
/// `runFontJob` sorts SVG names before handing out PUA codepoints, so this
/// is alphabetical — not `Directory.listSync` order. Frozen here so the
/// comparison does not re-list the directory.
const _glyphOrder = ['arrow_right', 'check', 'menu', 'plus'];

/// Matches `example/fontify_plus.yaml` — the shipped example is a variable
/// font so the gallery can show `Icon(..., weight: …)`.
final _exampleRange = StrokeWidthRange(0.5, 3);

/// The example font is checked in, so it doubles as a fixture: whatever the
/// pipeline produces for `example/svg` must still be exactly what shipped.
void main() {
  test('regenerating the example font reproduces it byte for byte', () {
    const fontPath = 'example/fonts/my_icons.otf';
    final expected = File(fontPath).readAsBytesSync();

    // head only — full readFromFile warns on unread fvar/STAT (#12).
    final timestamps = tryReadHeadTimestamps(fontPath)!;

    final result = svgToOtf(
      svgMap: {
        for (final name in _glyphOrder)
          name: File('example/svg/$name.svg').readAsStringSync(),
      },
      fontName: 'My Icons',
      strokeWidthRange: _exampleRange,
      created: timestamps.created,
      modified: timestamps.modified,
    );

    final actual = OTFWriter().write(result.font).buffer.asUint8List();

    expect(actual.length, expected.length, reason: 'font size changed');
    expect(actual, orderedEquals(expected));
  });
}
