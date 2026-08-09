# Glyph Sizing

How icons occupy the em square affects how they look at a given `Icon` size.

## Default: artboard mapping

By default, each icon's SVG viewBox maps straight onto the em square. An icon
drawn to fill its 16×16 viewBox fills the em; one drawn at half that size
fills half of it. `Icon(MyIcons.thing, size: n)` then covers the same area the
SVG does at *n* logical pixels — the font is a drop-in replacement for the
original SVG assets.

Leave normalization off for icons exported from a single design file where
relative sizes are intentional.

## `--normalize` / `normalize: true`

When enabled, each glyph is scaled individually until its own longest side
fills the em square, then centred. That discards how much of its artboard the
icon was drawn to occupy — which is design information. A full-bleed circle gets
shrunk and a small arrow gets blown up until they match, so the arrow can end up
larger than the circle even though the artwork says otherwise.

- CLI: `--normalize`
- API: `normalize: true`

Use it only when icons come from mismatched sources whose viewBoxes disagree and
forcing a uniform size is the lesser evil. For a cohesive icon set from one
design file, keep it off.
