# Variable Stroke Width

fontify_plus can emit an **OpenType variable font** whose `wght` axis is the
icon's stroke width in the SVG's own units — not a 100–900 weight scale.
`Icon(MyIcons.home, size: 16, weight: 1.33)` asks Flutter to render the
geometry the designer drew at stroke width 1.33.

## Configure the range

Only **two** numbers are configured: the minimum and maximum stroke width.
Every width between them is reproduced by interpolation between two masters
built at those endpoints. Intermediate stops are not emitted and would not add
reachable widths.

The **maximum** is the default instance: `Icon` without `weight` draws the
thickest width, matching `fvar`'s default and the metrics the font is built
from.

### YAML

```yaml
fontify_plus:
  defaults:
    stroke_width_range: [1.33, 2]
  fonts:
    icons:
      input_svg_dir: assets/icons/
      output_font_file: fonts/icons.otf
```

`stroke_width_range` may live in `defaults` or per font set. There is no
built-in default — the range sets both the variation's magnitude and how
deeply every glyph is subdivided.

### CLI

```sh
fontify_plus assets/svg/ fonts/icons.otf \
  --stroke-width-range=1.33,2 \
  --output-class-file=lib/icons.dart
```

### Dart API

```dart
final result = svgToOtf(
  svgMap: {'home': await File('home.svg').readAsString()},
  strokeWidthRange: StrokeWidthRange(1.33, 2),
);

final source = generateFlutterClass(
  glyphList: result.glyphList,
  className: 'MyIcons',
  familyName: result.font.familyName,
  fontFileName: 'icons.otf',
  strokeWidthRange: StrokeWidthRange(1.33, 2),
);
```

The generated class comment documents the axis when `strokeWidthRange` is
passed to `generateFlutterClass` (or when the CLI/YAML path sets a range).

## Use in Flutter

Register the font in `pubspec.yaml` as for any icon font, then:

```dart
Icon(MyIcons.home, size: 16, weight: 1.33)
```

For widgets that do not take `Icon.weight`, pass the same axis value through
`FontVariation`:

```dart
Text(
  String.fromCharCode(MyIcons.home.codePoint),
  style: TextStyle(
    fontFamily: MyIcons.iconFontFamily,
    fontSize: 16,
    fontVariations: [FontVariation('wght', 1.33)],
  ),
)
```

State the width at each use site (or in your theme). The generator does **not**
emit a size→width helper — that belongs in app theming, not generated code.

## Requirements and warnings

Variable output needs:

- `outline_strokes` on (`outlineStrokes: true`, `--outline-strokes`, default)
- `opentype` on (`useOpenType: true`, `--opentype`, default)

Pairing `stroke_width_range` with `outline_strokes: false` or `opentype: false`
is rejected before generation starts.

If one SVG file mixes several authored `stroke-width` values, the axis overrides
them all with a single range and a warning names the file and every width found.

Omitting `stroke_width_range` / `strokeWidthRange` leaves output **byte-identical**
to a static font.

## Why only two masters

Stroke outlining is planned once at the maximum width; the same subdivision
decisions are replayed at the minimum. Offset control points are affine in the
stroke width, so linear interpolation between the two masters reproduces every
intermediate width. Named `fvar` instances are not written — they would add data
without adding widths the axis cannot already reach.

## Honest caveats

**`usWeightClass` is pinned to 400** while the axis spans literal widths such as
1.33–2.0. Flutter selects icon fonts by family, so rendering is unaffected;
generic font tooling may report the family oddly.

**Animating `weight`** may rasterize a fresh glyph atlas entry per frame, because
Flutter keys the atlas on (typeface, variation, size). Measure before animating
stroke width in motion.

**Read path:** this package writes `fvar` and `STAT` but does not read them back.
`OpenTypeFont.fromByteData` on a variable font produced here returns `fvar` and
`stat` as null and a read-modify-write round trip drops the axis. Tracked in
[issue #12](https://github.com/4akloon/fontify_plus/issues/12).

**Interpolation accuracy:** both masters match their own endpoint exactly. On
interpolated widths, Phase 0 toy glyphs measured up to **2 font units** worst
deviation at 1000 units per em (~0.048 px on a 24 px icon) — see
[tool/variable_prototype/README.md](../tool/variable_prototype/README.md).
On this package's example icons, independent checks against lerped master
coordinates put the worst residual at about **0.91 font units** at 1000 upem.

## Related

- [Stroked icons](stroked_icons.md) — why outlining exists and stays on.
- [CLI & Config](cli.md) — flags and yaml keys.
- [API Usage](api.md) — `svgToOtf` and `generateFlutterClass` parameters.
