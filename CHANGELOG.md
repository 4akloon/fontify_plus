# Changelog

## Unreleased

## 0.6.0

* Variable stroke width: `stroke_width_range` / `--stroke-width-range` /
  `strokeWidthRange` emits a CFF2 font whose `wght` axis is the SVG stroke
  width (e.g. `Icon(..., weight: 1.33)`). See `doc/variable_stroke.md`.
* Configurable default stroke width: `default_stroke_width` /
  `--default-stroke-width` / `defaultStrokeWidth` moves that axis's default
  instance off the range maximum to a width strictly inside the range. The
  axis then carries a third master and two variation regions, `fvar`'s
  `defaultValue` is the interior width, `STAT` names three stops instead of
  two, and the generated `IconData` class comment states the default
  (`default 1.5`) rather than leaving readers to assume the maximum.
  Requires `stroke_width_range`; a value outside the range, or on either
  endpoint, is rejected before generation starts. See
  `doc/variable_stroke.md`.
* **Fix icon codepoints depending on directory listing order.** The input
  SVGs were used in whatever order `Directory.listSync` returned them, and
  charcodes are handed out by position from the Private Use Area, so that
  order *was* the numbering. Listing order is not sorted and not stable: ext4
  returns entries in a hash order derived from the names, and a CI runner
  produced two different orders on two runs of the same commit. Regenerating
  a font could therefore renumber every icon, so a previously generated
  `IconData` constant rendered a different glyph — silently, since the
  codepoints still existed and only their meaning changed. Icons are now
  sorted by name, which also makes a build reproducible across machines.
  **If your icons were numbered on a filesystem that did not return them
  alphabetically, regenerating will renumber them once**; regenerate the
  font and its class together and the two stay in step.
* Fix `stroke_width_range` failing with `IncompatibleMastersException` on a
  large fraction of real icons — about one in five of a chained-cubic set such
  as Hugeicons, at some ranges. Three branches in the stroke joiner decided a
  corner's shape from offset points rather than from the source tangents;
  those points are float32, and the rounding in subtracting two of them scales
  with the corner's distance from the origin, not with the stroke width, so a
  radius-relative threshold did not cancel it and the two masters could take
  different branches at the same corner. The symptom was distinctive: failure
  was not monotonic in the range's width, so an icon could build at
  `[1.4, 1.6]` and fail at `[1.49, 1.51]`. All three branches now read the
  tangents, which do not depend on width. Output for icons that already built
  is unchanged.
* Fix filled-and-stroked paths punching a white gap under CFF nonzero
  winding. A clockwise fill against a counter-clockwise outer stroke cancelled
  in the inner half of the ring (visible on icons like Hugeicons
  `unfold-more-down`). Outer fill contours are now wound to match the outer
  stroke wall; holes keep the opposite winding so they stay empty.
* Fix lumpy inner curves on variable-stroke fonts. Offset plans built at the
  range maximum froze collapsed inner walls as chords, and `ContourShape`
  recorded at that width then dropped the control points from every narrower
  master (visible as faceted corners on Hugeicons `account-setting-03`).
  Narrower evaluations retry a cubic, and a segment stays a cubic on every
  master if it is a cubic at any width.
* Fix looping offset cubics at the stroke-width maximum. When an inner wall
  folded through a cusp, the cubic fit placed handles on opposite sides of
  the chord (visible as overlapping needles on Hugeicons `alien-02` at
  `wght=3`). Handles longer than 1.5× the chord now fall back to the chord.
  A curve that only collapses at one end is subdivided rather than replaced
  by a single chord, so the uncollapsed half keeps its shape.
* A non-finite or non-positive stroke width is now rejected with an
  `ArgumentError` naming it. It used to be caught only as a side effect of the
  numerical noise the fix above removes.
* Metrics come from the default instance, so an interior default makes ink at
  the axis maximum overflow the advertised box on both sides (single-digit
  font units at 1000 upem on the example icons). Documented, not fixed —
  leaving the default at the maximum keeps the old one-sided behaviour.
* Omitting `default_stroke_width` leaves output **byte-identical** to the
  `stroke_width_range`-only path above.
* Smaller outlined fonts — less subdivision on near-straight edges and exact
  90° round joins.
* IDE SVG previews in generated `IconData` dartdoc (`--[no-]preview` /
  YAML `preview:`, default on).
* CLI `--watch` (debounced SVG regen + config reload); negatable
  `--[no-]recursive` / `--[no-]verbose`; empty SVG dirs fail; recursive icon
  names use the path relative to the input dir.
* Reuse `head` created/modified when rewriting an existing font; otherwise a
  fixed default timestamp (no wall clock).
* Docs: README fixes; example gallery screenshot.
* **Breaking for `src/` importers:** many table constructors take named
  parameters; `OS2Table` uses nested version groups; `.glyf` / `.loca` /
  `.cff` / `.cff2` / `.fvar` / `.stat` are nullable; `tableMap` is read-only.
  Static encoded output without a stroke range stays byte-identical aside from
  the size wins above.
* Known limits: no fvar/STAT read-back yet (#12); OS/2 v2/v3 truncation (#13).

## 0.5.2

* Fix TrueType (`useOpenType: false`) output storing SVG cubic control points
  verbatim as consecutive quadratic off-curve points instead of converting
  them, which bulged curved outlines outward (a full circle overshot its
  radius by close to 10% at the diagonals).
* Fix `hmtx.lsb` being hardcoded to zero instead of the glyph's real `xMin`.
  TrueType (`useOpenType: false`) requires `hmtx.lsb == glyf.xMin`; a
  mismatch shifts a glyph sideways when rendered. This affects TrueType
  output in **both** `normalize` modes: with `normalize: true`, centring
  zeroes a glyph's *pre-conversion* `xMin`, but a curved outline can still
  land several font units off zero once quadratic-approximated, so the two
  need not coincide. `normalize: false` output changes for CFF
  (OpenType) fonts too — `hmtx.lsb`, the `head` bounding box, and `hhea`'s
  right-side-bearing/extent now reflect each glyph's real ink bounds
  instead of a placeholder that assumed every custom glyph filled its whole
  em square; advance widths are unchanged in every mode and format.

## 0.5.1

* `normalize` defaults to **true** again (uniform em fill). Pass
  `--no-normalize` / `normalize: false` to keep artboard-relative sizes.

## 0.5.0

* Fix font generation (0.4.x could not produce a font). SVG parsing now uses
  `vector_graphics_compiler`; outline-style stroked icons render by default.
* `normalize` defaults to **false** (artboard → em). Pass `--normalize` only for
  mismatched viewBoxes.
* YAML config is now `defaults` + named `fonts` (flat `fontify_plus:` rejected).
  CLI flags merge on top; `--font=<name>` runs one set.
* Public job API: `FontJob`, `parseFontifyConfig`, `runFontJob` / `runFontJobs`.
* Dropped `ignoreShapes`, SVG element tree exports, and unused deps. Generated
  IconData class is `abstract final`. SDK floor: Dart 3.10.

## 0.4.3

* Remove `collection` package dependency

## 0.4.1

* Remove `meta` package dependency

## 0.4.0

* Update Dart SDK constraint to `>=3.0.0 <4.0.0`
* Update dependencies
* Refactor codebase with lints package

## 0.3.0-nullsafety.1

* Fix regression related to CLI options (#13)

## 0.3.0-nullsafety.0

* Migrate to null safety
* Fix unknown config parameters causing a crash and add related warnings

## 0.2.0

* **IMPORTANT:** 'CFF' table is generated now instead of 'CFF2'.
It shouldn't affect glyphs in newly generated fonts.
To learn more, refer to the issue: <https://github.com/4akloon/fontify_plus/issues/8>
* PostScript name record in the 'name' table now only contains allowed characters.
* Added CharString optimization to remove some NOOP commands.

## 0.1.1

* Changed values of ascender (to unitsPerEm) and descender (to 0) for non-normalized fonts.

## 0.1.0

* `fontPackage` parameter for `IconData` class can now be provided (thanks @jamie1192).

## 0.0.3

* Fixed glyph metrics in a case where normalization setting is off (thanks @dricholm).
* Formatted code using dartfmt.

## 0.0.2

* CLI tool arguments can now be specified in yaml config (thanks for suggestion @dricholm).
* Fixed lints affecting package score.

## 0.0.1

* Initial release
