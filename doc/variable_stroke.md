# Variable Stroke Width

fontify_plus can emit an **OpenType variable font** whose `wght` axis is the
icon's stroke width in the SVG's own units — not a 100–900 weight scale.
`Icon(MyIcons.home, size: 16, weight: 1.33)` asks Flutter to render the
geometry the designer drew at stroke width 1.33.

## Configure the range

Two numbers set the axis: the minimum and maximum stroke width. Every width
between them is reproduced by interpolation between masters built at the
configured widths — no other stop is emitted, and none would add a reachable
width.

By default the **maximum** is the default instance: `Icon` without `weight`
draws the thickest width, matching `fvar`'s default and the metrics the font
is built from. A third number, `default_stroke_width`, moves that default to a
width strictly inside the range; see
[Default at an interior width](#default-at-an-interior-width) below.

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

## Default at an interior width

Widest-by-default suits an icon set whose thickest drawing is the everyday
one. When the everyday width sits in the middle of the range and the ends are
the exceptional settings, name it explicitly:

```yaml
fontify_plus:
  defaults:
    stroke_width_range: [1.33, 2]
    default_stroke_width: 1.5
```

```sh
fontify_plus assets/svg/ fonts/icons.otf \
  --stroke-width-range=1.33,2 \
  --default-stroke-width=1.5
```

```dart
final result = svgToOtf(
  svgMap: {'home': await File('home.svg').readAsString()},
  strokeWidthRange: StrokeWidthRange(1.33, 2),
  defaultStrokeWidth: 1.5,
);

final source = generateFlutterClass(
  glyphList: result.glyphList,
  className: 'MyIcons',
  familyName: result.font.familyName,
  fontFileName: 'icons.otf',
  strokeWidthRange: StrokeWidthRange(1.33, 2),
  defaultStrokeWidth: 1.5,
);
```

`Icon(MyIcons.home, size: 16)` then draws 1.5, a font picker opens on it, and
the generated class comment names it (`default 1.5`) instead of leaving a
reader to assume the maximum. Pass the same value to `generateFlutterClass`
that you passed to `svgToOtf` — the CLI and YAML paths do this for you.

**Validation.** `default_stroke_width` requires `stroke_width_range` (a width
names a point *on* an axis; with no axis it would be silently dropped) and
must lie **strictly between** the range's ends. Outside them the font would
open at a width no master was drawn at; at either end the extra master would
duplicate the endpoint it sits on, paying for a whole variation region and
telling a font picker two names for one instance. Both mistakes are rejected
before generation starts — by the CLI/YAML resolver, by `svgToOtf`, and again
by `OpenTypeFontBuilder`.

**What changes in the font.** Each icon is built three times rather than
twice, and the axis gets a second variation region (min→default and
default→max) instead of one. `fvar`'s `defaultValue` becomes the interior
width, and `STAT` names **three** stops on the axis rather than two, so a font
tool can label the interior default and not only the two ends. (`fvar` named
instances are still not written — see below.) On this package's
four example icons the third master costs about **12%** more bytes whole-file
and about **17%** more after `pyftsubset` than the same font with the default
left at the maximum — gated in `test/integration/variable_size_gate_test.dart`.

**Metrics are computed from the default instance**, which is now an interior
width rather than the widest one. The consequence is that ink at the *maximum*
width bleeds outside the metrics the font advertises, on **both** sides:
glyphs extend to the left of the origin and past their advance width, and the
tallest ones exceed `head`'s `yMin`/`yMax` box. With a default at the maximum
the overflow is one-sided (thinner strokes only ever pull ink inward). On the
four example icons at `[1.33, 2]` with the default at the midpoint, every icon
crosses its advance box horizontally at the maximum and two of the four dip
below the font-wide `head.yMin` — single-digit font units at 1000 upem, so
sub-pixel at icon sizes, but it is real clipping if your renderer trusts
`head`. Leave the default at the maximum if you need the advertised box to
contain every reachable width.

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
to a static font. Omitting only `default_stroke_width` / `defaultStrokeWidth`
leaves output byte-identical to a two-master variable font built before the
option existed.

## Why two masters, and when a third

Stroke outlining is planned once at the maximum width; the same subdivision
decisions are replayed at every other width. Offset control points are affine
in the stroke width, so linear interpolation between two masters reproduces
every intermediate width, and a two-master font is the whole axis. Named
`fvar` instances are not written — they would add data without adding widths
the axis cannot already reach.

A third master therefore buys no new widths, and is emitted for exactly one
reason: OpenType puts the default instance at a *region boundary*, so a
default at an interior width needs a master there. That is why
`default_stroke_width` is the only thing that adds one, why it must be
strictly inside the range (at an end there is already a master), and why the
axis then has two regions rather than one.

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
