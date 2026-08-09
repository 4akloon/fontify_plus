# Glyph Sizing

How icons occupy the em square affects how they look at a given `Icon` size.

## Default: normalize each glyph

By default each glyph is scaled so its own longest side fills the em square,
then centred. Icons from different viewBoxes (12 / 24 / 32, mixed sources)
then look the same size at a given `Icon` size.

That discards how much of its artboard an icon was drawn to occupy. A
full-bleed circle and a small arrow both end up filling the em, so the arrow
can look larger than design intended.

- CLI: `--normalize` (default)
- API: `normalize: true` (default)

## `--no-normalize` / `normalize: false`

When disabled, each icon's SVG viewBox maps straight onto the em square. An
icon drawn to fill its 16×16 viewBox fills the em; one drawn at half that
size fills half of it. `Icon(MyIcons.thing, size: n)` then covers the same
area the SVG does at *n* logical pixels.

Use this for a cohesive set from one design file where relative sizes are
intentional and every icon shares a viewBox. Mismatched viewBox heights log
a warning.
