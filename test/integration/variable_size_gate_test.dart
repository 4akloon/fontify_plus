import 'dart:io';
import 'dart:typed_data';

import 'package:fontify_plus/fontify_plus.dart';
import 'package:test/test.dart';

bool _pyftsubsetInstalled() {
  final result = Process.runSync('which', ['pyftsubset']);
  return result.exitCode == 0;
}

final _hasPyftsubset = _pyftsubsetInstalled();

/// Icons from the shipped example — real icon-set scale, not toy glyphs.
Map<String, String> _exampleSvgs() {
  final names = ['arrow_right', 'plus', 'check', 'menu'];
  return {
    for (final name in names)
      name: File('example/svg/$name.svg').readAsStringSync(),
  };
}

Uint8List _encode(OpenTypeFont font) =>
    OTFWriter().write(font).buffer.asUint8List();

Future<Uint8List> _pyftsubset(Uint8List fontBytes, List<int> codePoints) async {
  final dir = await Directory.systemTemp.createTemp('fontify_size_gate_');
  final input = File('${dir.path}/font.otf');
  final output = File('${dir.path}/subset.otf');
  await input.writeAsBytes(fontBytes);

  final unicodes = codePoints.map((c) => c.toRadixString(16)).join(',');
  final result = await Process.run('pyftsubset', [
    input.path,
    '--unicodes=$unicodes',
    '--output-file=${output.path}',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'pyftsubset failed: ${result.stderr}',
    );
  }

  return output.readAsBytes();
}

/// Midway between the range's ends, so the third master is as far from both
/// endpoints as it can be — the worst case for the extra region's cost.
const _interiorDefault = 1.665;

/// One name for every font here, because every ratio below divides one of
/// these files by another and the `name` table rides along in both.
///
/// This is not cosmetic. `fontName` lands in `name` several times over, so
/// two fixtures whose names differ in length differ in size for a reason that
/// has nothing to do with outlines: naming the three-master font
/// `'… Interior Default'` inflated the whole-file `name` table by 198 B
/// against a real variation-data delta of 240 B, i.e. it nearly doubled the
/// measured cost. Give these fonts different names again and every ceiling in
/// this file moves without a byte of encoder change.
const _fontName = 'Size Gate Variable';

void main() {
  late Uint8List staticBytes;
  late Uint8List variableBytes;
  late Uint8List interiorDefaultBytes;
  late List<int> iconCodePoints;

  setUpAll(() {
    final svgs = _exampleSvgs();
    final staticResult = svgToOtf(svgMap: svgs, fontName: _fontName);
    final variableResult = svgToOtf(
      svgMap: svgs,
      fontName: _fontName,
      strokeWidthRange: StrokeWidthRange(1.33, 2),
    );
    final interiorDefaultResult = svgToOtf(
      svgMap: svgs,
      fontName: _fontName,
      strokeWidthRange: StrokeWidthRange(1.33, 2),
      defaultStrokeWidth: _interiorDefault,
    );

    staticBytes = _encode(staticResult.font);
    variableBytes = _encode(variableResult.font);
    interiorDefaultBytes = _encode(interiorDefaultResult.font);
    iconCodePoints = [
      for (final glyph in variableResult.glyphList) glyph.metadata.charCode!,
    ];
  });

  test('variable font is at most 1.5x the static whole-file size', () {
    final limit = staticBytes.length * 1.5;
    expect(
      variableBytes.length,
      lessThanOrEqualTo(limit),
      reason:
          'variable ${variableBytes.length} B vs static ${staticBytes.length} B '
          '(limit ${limit.toStringAsFixed(0)} B)',
    );
  });

  test(
    'subset variable font is at most 1.5x the subset static whole-file size',
    () async {
      // Phase 0 measured charstring bytes only because three toy glyphs left
      // fixed tables dominating whole-file ratios. At real icon-set scale the
      // shipped file is what matters — do not "fix" this back to charstrings.
      final staticSubset = await _pyftsubset(staticBytes, iconCodePoints);
      final variableSubset = await _pyftsubset(variableBytes, iconCodePoints);

      final limit = staticSubset.length * 1.5;
      expect(
        variableSubset.length,
        lessThanOrEqualTo(limit),
        reason:
            'subset variable ${variableSubset.length} B vs static '
            '${staticSubset.length} B (limit ${limit.toStringAsFixed(0)} B)',
      );
    },
    skip: _hasPyftsubset
        ? null
        : 'pyftsubset not installed — install fonttools',
  );

  // An interior default adds a third master and a second variation region, so
  // it is measured against the two-master font, not the static one: the
  // static-vs-variable ratio above already covers the cost of having an axis
  // at all, and what is new here is only the marginal cost of the extra
  // region. Measured on these four icons with the default at the range's
  // midpoint, all three fonts sharing [_fontName]: 1.0884x whole-file
  // (2716 B -> 2956 B), 1.1478x subset (1624 B -> 1864 B). The ceiling is
  // 1.3x — the worst measured ratio rounded up to the next tenth, plus
  // another tenth of headroom, the same measure-round-up-then-margin rule the
  // 1.5x gates above were set by. A third master that started costing as much
  // as the second one did trips this.
  //
  // Do not "harmonize" these two gates onto the static baseline the 1.5x ones
  // use. Against the static font the three-master build already measures
  // 1.4079x subset, so a static-relative 1.5x ceiling would sit on about 6%
  // of headroom: it passes today and goes red on the next unrelated encoder
  // change, with no number anywhere explaining why 1.5x was fine for two
  // masters and not for three. Either baseline is defensible; only this one
  // leaves room to work in.
  const interiorDefaultLimitFactor = 1.3;

  test(
    'interior-default variable font is at most 1.3x the two-master '
    'whole-file size',
    () {
      final limit = variableBytes.length * interiorDefaultLimitFactor;
      expect(
        interiorDefaultBytes.length,
        lessThanOrEqualTo(limit),
        reason:
            'interior-default ${interiorDefaultBytes.length} B vs two-master '
            '${variableBytes.length} B (limit ${limit.toStringAsFixed(0)} B)',
      );
    },
  );

  test(
    'subset interior-default variable font is at most 1.3x the subset '
    'two-master whole-file size',
    () async {
      final variableSubset = await _pyftsubset(variableBytes, iconCodePoints);
      final interiorDefaultSubset = await _pyftsubset(
        interiorDefaultBytes,
        iconCodePoints,
      );

      final limit = variableSubset.length * interiorDefaultLimitFactor;
      expect(
        interiorDefaultSubset.length,
        lessThanOrEqualTo(limit),
        reason:
            'subset interior-default ${interiorDefaultSubset.length} B vs '
            'subset two-master ${variableSubset.length} B '
            '(limit ${limit.toStringAsFixed(0)} B)',
      );
    },
    skip: _hasPyftsubset
        ? null
        : 'pyftsubset not installed — install fonttools',
  );
}
