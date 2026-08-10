# Variable font prototype (Phase 0)

Throwaway Python + fontTools scripts used to decide, before any package code
is written, which static outline format — CFF or TrueType (`glyf`) — survives
merging into a variable font with a `wght` axis driving stroke width. Nothing
here is shipped; it only produces the static "master" fonts that later Phase 0
steps feed into `fontTools.varLib` to build and inspect an actual variable
font.

## The three glyphs

Each prototype glyph is built at several stroke widths and is engineered to
stay *point-compatible* across those widths — same number of contours, same
number of points per contour, in the same order — which is the hard
requirement `varLib.build` imposes on every master:

- **`dot`** — a plain filled circle. `width` is accepted and ignored, so
  every master produces byte-identical outline data. This is the trivial
  case: all interpolation deltas are zero. Useful as a sanity check that the
  harness itself works.
- **`plus`** — a stroked cross (`stroke-width`, round caps) with only
  straight segments along its spine. Straight strokes never get subdivided
  differently as the width changes, so the outline stays compatible at any
  width.
- **`ring`** — a circular stroke, pre-offset by `glyphs.py` itself into two
  filled contours (outer circle radius `8 + width/2`, inner circle radius
  `8 - width/2`, non-zero become even-odd fill) instead of relying on
  `fontify_plus`'s stroke-to-fill conversion. Both contours are always drawn
  as four cubic arcs regardless of radius, so the point count per contour
  never changes with `width`. This is the one that actually exercises curve
  interpolation between masters, and the one most likely to break if the
  compatibility assumption above is wrong.

## Running

From this directory, in order:

1. `python3 build_masters.py`

   Renders each glyph's SVG at widths `1.33`, `1.5`, and `2.0` into
   `out/svg_{width}/`, then runs `dart run bin/fontify_plus.dart` (from the
   repo root) against each width to produce
   `out/static_{width}_{cff,glyf}.otf` — six static fonts in total. Uses
   `--no-normalize` because normalization scales each glyph by its own ink
   box, which differs between masters and would break point compatibility
   before `varLib` ever sees the fonts; `--no-opentype` selects the `glyf`
   backend, its absence the `cff` backend.

2. Verify point compatibility before doing anything else with the masters:

   ```bash
   python3 - <<'PY'
   from fontTools.ttLib import TTFont
   a = TTFont('out/static_1.33_glyf.otf')
   b = TTFont('out/static_2.0_glyf.otf')
   for name in a.getGlyphOrder():
       ga, gb = a['glyf'][name], b['glyf'][name]
       pa = 0 if ga.numberOfContours == 0 else len(ga.coordinates)
       pb = 0 if gb.numberOfContours == 0 else len(gb.coordinates)
       print(f"{name:10} {pa:4} {pb:4} {'OK' if pa == pb else 'MISMATCH'}")
   PY
   ```

   Every row must print `OK`. A `MISMATCH` means the glyph choice above is
   wrong and must be fixed before any later Phase 0 step runs — an
   incompatible master pair would silently invalidate everything downstream.

3. Later Phase 0 scripts (not yet written) merge the masters with
   `fontTools.varLib` and inspect the resulting variable font to decide
   between CFF and `glyf`.

`out/` is generated and gitignored; nothing under it is committed.

## Results

_(Filled in by the task that runs the CFF vs. glyf comparison.)_
