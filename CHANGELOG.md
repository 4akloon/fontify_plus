# Changelog

## 0.6.0

* Variable stroke width: `stroke_width_range` / `--stroke-width-range` /
  `strokeWidthRange` emits a CFF2 font whose `wght` axis is the SVG stroke
  width (e.g. `Icon(..., weight: 1.33)`). See `doc/variable_stroke.md`.
* Smaller outlined fonts — less subdivision on near-straight edges and exact
  90° round joins.
* IDE SVG previews in generated `IconData` dartdoc (`--[no-]preview` /
  YAML `preview:`, default on): markdown images carrying URL-encoded
  minified SVG (black recolored grey for dark themes), auto-dropped with
  a warning when the class file would exceed 2 MiB — explicit `--preview`
  forces them.
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
