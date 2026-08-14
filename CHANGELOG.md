# Changelog

## Unreleased

## 0.6.0

* Variable stroke width: `stroke_width_range` / `--stroke-width-range` /
  `strokeWidthRange` emits a CFF2 font whose `wght` axis is the SVG stroke
  width (e.g. `Icon(..., weight: 1.33)`). Optional `default_stroke_width` /
  `--default-stroke-width` / `defaultStrokeWidth` moves the default off the
  range maximum to a width strictly inside it. Omitting it leaves output
  **byte-identical** to the range-only path. See `doc/variable_stroke.md`.
* **Fix icon codepoints depending on directory listing order.** Icons are
  now sorted by name before charcodes are assigned. **If your icons were
  numbered on a filesystem that did not return them alphabetically,
  regenerating will renumber them once**; regenerate the font and its class
  together.
* Fix stroke outlining: joiners follow source tangents (was
  `IncompatibleMastersException` on ~1/5 of chained-cubic sets like
  Hugeicons); fill holes stay empty; collapsed inner walls and looping
  handles at the width maximum no longer distort. Smaller outlined fonts
  (less subdivision, exact 90° round joins). Non-finite stroke widths throw
  `ArgumentError`.
* IDE SVG previews in generated `IconData` dartdoc (`--[no-]preview` /
  YAML `preview:`, default on): minified markdown images, auto-dropped with
  a warning over 2 MiB — explicit `--preview` forces them.
* CLI `--watch`; negatable `--[no-]recursive` / `--[no-]verbose`; empty SVG
  dirs fail; recursive icon names use the path relative to the input dir.
* Reuse `head` timestamps when rewriting a font; otherwise a fixed default
  (no wall clock).
* **Breaking for `src/` importers:** named table constructors; nested
  `OS2Table` version groups; `.glyf` / `.loca` / `.cff` / `.cff2` / `.fvar`
  / `.stat` nullable; `tableMap` read-only. Static output without a stroke
  range stays byte-identical aside from the size wins above.
* SDK floor is Dart 3.11 (`xml` 7).
* Known limits: no fvar/STAT read-back yet (#12); OS/2 v2/v3 truncation
  (#13); interior-default metrics can overflow at the axis maximum
  (documented, not fixed).

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
