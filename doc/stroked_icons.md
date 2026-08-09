# Stroked Icons

A font glyph is a filled region. The format has no concept of stroke width,
line caps, or joins — only enclosed area matters.

## Centreline strokes

Outline-style icon sets (Figma, Lucide, Feather, Hugeicons, and similar) export
paths that describe the *centreline* of a stroke. Filled as-is, such a path
encloses zero area and renders invisible:

```svg
<svg viewBox="0 0 16 16" fill="none">
  <path d="M8 2.66667V13.3333M13.3333 8H2.66666"
        stroke="currentColor" stroke-width="1.33" stroke-linecap="round" />
</svg>
```

## Default outlining

`svgToOtf` converts each stroked path into the filled region the stroke covers
before encoding. This is on by default (`outlineStrokes: true` on the API,
`--outline-strokes` on the CLI).

Honoured stroke attributes:

- `stroke-width`
- `stroke-linecap`
- `stroke-linejoin`
- `stroke-miterlimit`
- `stroke-dasharray` (including values inherited from an ancestor `<g>`)

A dashed stroke is cut into its dashes and each dash is outlined separately.

`stroke-dashoffset` is parsed upstream but has no effect: `vector_graphics_compiler`
drops it before fontify_plus sees the path, so the dash pattern always starts at
the beginning of the path regardless of the value.

## Opting out

If your SVG paths are already fill geometry (not centreline strokes), disable
outlining:

- CLI: `--no-outline-strokes`
- API: `outlineStrokes: false`

This treats path data as fill outlines, matching behaviour from older versions
of fontify_plus.
