# Changelog

## Unreleased

* Fonts generated from icons with an exact-90° round join
  (`stroke-linejoin="round"`) may differ slightly from those produced by
  0.5.2. The join's arc is now segmented using the source path's tangents
  instead of the offset coordinates, whose floating-point error scaled with
  the stroke width and could push an exact quarter turn onto either side of
  a segment-count rounding boundary depending on the width. The rendered
  shape is unaffected — it is the same arc, only ever differently
  segmented — the point of the change is that the segmentation no longer
  depends on the stroke width.
* An exact quarter-turn arc (a round join or, at a smaller scale, part of a
  round cap) now costs one cubic instead of sometimes costing two, for icon
  geometry at realistic coordinate scales. The segment count is
  `ceil(sweep / 90°)`, and floating-point noise in the tangent-derived sweep
  — worse the farther a corner sits from the origin, where recovering a
  short leg from two large, closely-spaced coordinates is lossier — could
  push an exact 90° corner a hair above the 90° boundary; this package's
  own `arrow_right` and `check` icons both landed on the expensive side.
  Validated against 500,000 sampled right angles spanning coordinate
  offsets up to 2000 units and leg lengths from 0.5 to 50 (a 512–1024
  viewBox's plausible range); an arc that is genuinely more than a quarter
  turn, or a corner at a coordinate/leg-length ratio far past that range,
  is unaffected. The rendered shape is unchanged; only the point count
  drops.
* A straight edge could still cost dozens to hundreds of extra cubics, and,
  for a variable stroke-width axis, quietly break the promise that every
  control point moves affinely between two width masters. The offset
  approximation's parallel-tangent test compared the *unnormalised*
  determinant against a fixed length-scale constant with no relation to
  that quantity; float32 rounding in the tangent computation routinely put
  a mathematically dead-straight edge's determinant six orders of magnitude
  above that threshold, so the near-singular two-tangent solve ran instead
  of the straight-line fallback, amplifying rounding noise into distorted
  control points and, at worst, a subdivision run that never converged.
  The test now thresholds the *normalised* cross product of the two
  tangents against an epsilon measured from both sides: up to 2.8e-4 of
  genuine float32 noise across a wide sweep of edge directions and
  coordinate scales, comfortably below where a genuinely curved segment
  needs the full solve. This package's own `arrow_right` and `check` icons
  drop from 376 and 97 points to 37 and 22; an ordinary triangle's two
  affected edges collapse from 193 and 66 pieces to one each. The rendered
  shape at any single width is unaffected — the fallback already
  reproduces the source curve's own control spacing, which is exact for a
  straight edge — only the point count drops, and interpolation between
  widths now holds exactly rather than approximately.

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
