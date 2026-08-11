# Changelog

## 0.6.0

* **Variable stroke width.** `stroke_width_range` (YAML),
  `--stroke-width-range` (CLI), or `strokeWidthRange` (`svgToOtf` /
  `createFromGlyphs`) emits a CFF2 variable font whose `wght` axis is the
  literal stroke width in SVG units — e.g. `Icon(MyIcons.home, size: 16,
  weight: 1.33)`. Requires `outline_strokes` and `opentype` (defaults). See
  `doc/variable_stroke.md`. Generated Flutter classes document the axis when
  a range is set. Without a range, static output stays byte-identical.
* **Smaller fonts for everyone** (why this is a minor bump): offsetter fixes
  drop redundant subdivision on near-straight edges and exact 90° round
  joins. Example font 3112 → 2272 B; `arrow_right` 376 → 37 points, `check`
  97 → 22. Rendered shape is essentially unchanged.
* **Breaking:** `OS2Table` uses named parameters and nested version groups
  (`version0` / `version1` / `version4` / `version5`). Read fields via
  `table.version0.…` or the `version4?` / `version5?` shorthands. A
  `version` that disagrees with the groups throws
  `TableDataFormatException`.
* **Breaking for `src/` importers:** many other wide positional constructors
  now take named parameters (same hazard: adjacent same-typed args). Encoded
  layout unchanged; only `src/` imports are affected.
* **Breaking:** `OpenTypeFont.glyf` / `.loca` / `.cff` / `.cff2` are nullable;
  use `?.` or `font.tables.require<…>(tag)`. New nullable `.fvar` / `.stat`.
  Missing required tables throw `TableDataFormatException` instead of
  `TypeError`.
* **Breaking (runtime only):** `OpenTypeFont.tableMap` is read-only. Use
  `OpenTypeFont.tables` (`lookup` / `require`) instead of casting map values.
  Do not mutate `tableMap` after construction.
* Known limits: this package writes `fvar`/`STAT` but does not read them back
  yet (#12). OS/2 v2/v3 round-trip truncation is pre-existing (#13).

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
