# Exporting icons from Figma

This guide covers how to get icons out of Figma so they render correctly as font
glyphs, and how to diagnose the cases that go wrong.

## The one rule that explains everything

**A font glyph is a filled region. There is no stroke in a font.**

TrueType and CFF outlines describe a closed area to fill. The format has no
concept of line weight, caps or joins. So when an SVG says "draw this line 1.33
units thick", nothing in the font file can carry that instruction.

Almost every icon-font problem is a consequence of this single fact.

## What outline-style icons look like

Icon sets drawn in an outline style — Hugeicons, Lucide, Feather, most Figma
icon libraries — export like this:

```svg
<svg viewBox="0 0 16 16" fill="none">
  <path d="M8 2.66667V13.3333M13.3333 8H2.66666"
        stroke="currentColor" stroke-width="1.33"
        stroke-linecap="round" stroke-linejoin="round" />
</svg>
```

Note `fill="none"` and `stroke="..."`. The `d` attribute is the *centreline* of
the stroke — an infinitely thin path with zero area. Filled directly, it is
invisible.

fontify_plus converts these automatically: it computes the region the stroke
covers and fills that instead. This is on by default (`--outline-strokes`).

## Recommended Figma export settings

Export each icon as SVG with:

- **Include "id" attribute** — off. It adds noise and is unused.
- **Outline text** — on, if any icon contains text.
- **Simplify stroke** — off. Leave the stroke as a stroke; fontify_plus handles
  it and gets better geometry from the original than from Figma's approximation.

Then, per icon frame:

- Give the frame a **square** aspect (16×16, 20×20, 24×24). Non-square frames
  still work, but glyph normalization centres on the em square and a square
  source keeps optical alignment predictable.
- Keep every icon in a set at the **same** frame size. Mixing 16×16 and 24×24 in
  one font makes the normalizer scale them differently.
- Name layers with the icon name. The filename becomes the glyph name and the
  generated Dart field, so `arrow_up_01.svg` becomes `ZeelyIcons.arrowUp01`.

## If you prefer to outline in Figma instead

You can bake the stroke into a filled shape before exporting. Select the icon
and:

1. **Object → Outline Stroke** (`⌘⇧O` on macOS). The stroke becomes a filled
   shape.
2. **Object → Flatten** (`⌘E`) to merge the resulting shapes into one path.

The export then contains `fill` geometry and no `stroke`, and fontify_plus
passes it through unchanged.

This is not required. It is worth doing when you want the exported SVG to be
self-describing, or when an icon uses a stroke effect fontify_plus does not
model (see [Limitations](#limitations)).

## Converting

```bash
dart run fontify_plus <svg-dir> assets/fonts/MyIcons.otf \
  -o lib/src/my_icons.dart \
  -c MyIcons \
  --font-name "My Icons"
```

Then register the font in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: My Icons
      fonts:
        - asset: assets/fonts/MyIcons.otf
```

## Diagnosing bad output

### Icons are blank or invisible

The stroke was not converted. Check that you have not passed
`--no-outline-strokes`, and that the SVG actually carries a `stroke` attribute
rather than expressing weight some other way.

### Parts of an icon are missing

Shape elements were discarded. `<circle>`, `<rect>`, `<line>`, `<polyline>` and
`<polygon>` are converted to paths by default.

### An icon renders as a filled blob

Two contours that should cut a hole are wound the same way, so the nonzero rule
fills both. This usually means the source SVG relies on `fill-rule="evenodd"` for
a shape whose subpaths run in the same direction. Reverse the inner subpath in
Figma, or outline and flatten the icon before exporting.

### Icons look off-centre relative to each other

Frame sizes differ across the set. Normalization scales each glyph to fit, so a
24×24 icon and a 16×16 icon end up with different effective stroke weights.
Re-export the set at one uniform frame size.

### Strokes look too thin or too thick after conversion

Stroke width is interpreted in viewBox units, and glyph normalization then scales
the whole icon. If one icon has a much larger viewBox than the rest, its stroke
shrinks proportionally. Uniform frame sizes fix this.

## Limitations

fontify_plus models stroke geometry, not stroke *painting*. `stroke-dasharray`
is honoured — the stroke is cut into dashes and each dash is outlined as its
own contour. The following are not supported, and an icon using them should be
outlined in Figma before export:

- `stroke-dashoffset` — parsed but then dropped by `vector_graphics_compiler`
  before fontify_plus ever sees it, not by this package. The dash pattern
  always starts at the beginning of the path regardless of the value.
- Non-scaling strokes (`vector-effect="non-scaling-stroke"`).
- Gradients, patterns and opacity. A glyph is a single-colour region; colour
  comes from Flutter at render time.
- Clipping paths and masks.

Colour is deliberately not supported: the whole point of an icon font is that
the icon takes its colour from the surrounding text style.
