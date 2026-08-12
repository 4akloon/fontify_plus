import 'dart:io';

import 'package:fontify_plus/fontify_plus.dart';
import 'package:test/test.dart';

/// The order `example/lib/my_icons.dart` assigns codepoints in, and so the
/// order the checked-in font's glyphs were built in.
///
/// `runFontJob` reads `example/svg` through an unsorted `Directory.listSync`,
/// which returns filesystem enumeration order, not alphabetical order — it is
/// `[arrow_right, plus, check, menu]` here, confirmed against the generated
/// class, and does not match a sorted listing. That order is a property of
/// whatever filesystem last generated the fixture, not of this repository, so
/// freezing the sequence itself — rather than re-deriving it from a directory
/// listing — is what keeps this gate from depending on which filesystem the
/// test happens to run on (this checkout's local disk, or CI's).
const _glyphOrder = ['arrow_right', 'plus', 'check', 'menu'];

/// The example font is checked in, so it doubles as a fixture: whatever the
/// pipeline produces for `example/svg` must still be exactly what shipped.
///
/// This is the gate for the plan/evaluate refactor. It touches the hot path of
/// every existing user, not only those who enable a stroke axis, so "the tests
/// still pass" is not enough — the bytes have to be the same.
void main() {
  test('regenerating the example font reproduces it byte for byte', () {
    const fontPath = 'example/fonts/my_icons.otf';
    final expected = File(fontPath).readAsBytesSync();

    // `head` stamps created/modified into every font. Reuse the fixture's
    // timestamps so regeneration is byte-identical (same path as runFontJob
    // when rewriting an existing .otf).
    final fixtureFont = readFromFile(fontPath);

    final result = svgToOtf(
      svgMap: {
        for (final name in _glyphOrder)
          name: File('example/svg/$name.svg').readAsStringSync(),
      },
      fontName: 'My Icons',
      created: fixtureFont.head.created,
      modified: fixtureFont.head.modified,
    );

    final actual = OTFWriter().write(result.font).buffer.asUint8List();

    expect(actual.length, expected.length, reason: 'font size changed');
    expect(actual, orderedEquals(expected));
  });
}
