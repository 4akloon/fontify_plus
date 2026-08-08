# Changelog

## 0.6.0

SVG parsing now goes through `package:vector_graphics_compiler` instead of a
hand-written reader. This fixes several classes of icon that previously came out
blank or wrong, and removes a net 496 lines from `lib` and `bin` (602 added,
1098 removed).

### Breaking

* Minimum Dart SDK is now 3.10.
* The `ignoreShapes` option is gone from `svgToOtf`, the `--ignore-shapes` flag
  and the `ignore_shapes` config key. Shape elements are always converted to
  paths; the parser no longer records which element a path came from.
* The `Svg` class and the rest of the SVG element tree are no longer exported.
  Use `svgToOtf`, or `GenericGlyph.fromSvg(name, xmlString)`.
* A `viewBox` with fewer than four numbers is now rejected instead of being
  left-padded with zeroes.

### Fixed

* Read presentation properties from a `style` attribute. An icon written as
  `style="fill:none;stroke:#000;stroke-width:1.5"` — the shape Illustrator and
  some Figma exports produce — previously lost its stroke entirely and rendered
  blank.
* Expand `<use>`, `<defs>` and `<symbol>` instead of discarding them.
* Accept an SVG with `width`/`height` and no `viewBox`, and a `viewBox` with a
  non-zero minimum.
* Accept `width="100%"`.
* Stop a `<clipPath>`'s own shape from being drawn as part of the icon.

### Changed

* A path with `fill="none"` and no stroke is dropped rather than filled.
* `stroke-dasharray` is now honoured: each dash is outlined separately.
* Contours produced by stroke outlining always use the nonzero fill rule. An
  `evenodd` value on a stroked path used to punch holes through its own stroke.
* A stroke-derived contour closed by a straight line no longer repeats its start
  point, which every such contour used to carry. A contour closed by a curve still
  carries it, and must: CFF closes a charstring path with a straight line, so a
  curve's end point cannot be left implicit. Glyphs shift by a few bytes either way
  as a result; round-capped icons grow slightly, everything else shrinks.
* `clip-path`, `<text>` and `<image>` remain unsupported, but now log a warning
  naming the icon instead of being dropped silently.

## 0.5.0

**This release fixes a bug that made every 0.4.x version unable to produce a
font at all.** If you are on 0.4.x, upgrade.

### Fixed

* Fix a stale CFF INDEX cache that made font writing fail with
  `RangeError (end): Invalid value: Not in inclusive range 25..26: 29`.
  `CFFIndexWithData` memoized its INDEX while the Top DICT still held one-byte
  placeholder offset operands, then sized its encode buffer from that stale
  index while writing the grown DICT. Every published 0.4.x was affected.
* Fix `moveTo` not starting a new subpath when converting paths to outlines. A
  path such as `M8 2V13 M13 8H2` — two separate strokes, no `Z` — was
  accumulated into a single contour and rendered as one zigzag.
* Preserve the source element when converting shapes to paths, so attributes on
  a `<circle>` or `<rect>` are no longer lost.

### Added

* Stroked paths are now converted into the filled region the stroke covers,
  honouring `stroke-width`, `stroke-linecap`, `stroke-linejoin` and
  `stroke-miterlimit`, including values inherited from an ancestor `<g>`.
  Outline-style icon sets exported from Figma previously rendered blank,
  because font glyphs are fill-only and a stroke centreline encloses no area.
  Controlled by `--outline-strokes` / `outlineStrokes`, enabled by default.
* End-to-end tests that write a font and parse the bytes back. The suite
  previously passed 35 tests while the package could not produce a font,
  because nothing exercised the full write path.
* `doc/figma-export.md` — export settings, troubleshooting, and the cases that
  need outlining in Figma first.
* Analytic offsetting for outlined strokes. The outline is built by offsetting
  the source curves directly, rather than flattening them to a polyline first.
  End points and end tangents of an offset are known exactly, so each source
  curve maps to a handful of cubics instead of hundreds of samples that then
  have to be refitted. Round joins and caps became cubic arc approximations for
  the same reason. On a 32-icon set that cut the font by 39% raw and 30%
  compressed, and halved the point count, with no measurable change to the
  rendered shape.

  Where `distance * curvature` reaches 1 — the inside of a corner rounded
  tighter than the stroke is wide — the true offset grows a cusp that no curve
  tracks. Those are detected and approximated in one step; the nonzero winding
  rule absorbs the small overlap.
* `CONTRIBUTING.md`, CI across Dart 3.5 and stable, and automated publishing.

* Fix glyph normalization scaling to `ascender + descender` instead of the span
  between them. With the default metrics that is 700 units rather than 1000, so
  every normalized glyph came out at 70% of the size it asked for. (The same sum
  is correct a few lines away in `center`, where it is the band's midpoint
  rather than its height.)

### Changed

* **Breaking:** `normalize` now defaults to false. Normalization scales each
  glyph until its own longest side fills the em square, which discards how much
  of its artboard an icon was drawn to occupy: a full-bleed circle is shrunk and
  a small arrow is blown up until they match, so the arrow can end up larger
  than the circle. With it off the artboard maps onto the em square directly and
  `Icon(..., size: n)` covers the same area as the SVG at the same size. Pass
  `--normalize` for icons collected from sources whose viewBoxes disagree.
* **Breaking:** `ignoreShapes` now defaults to false, so `<circle>`, `<rect>`,
  `<line>`, `<polyline>` and `<polygon>` are converted to paths instead of being
  silently discarded. Pass `--ignore-shapes` for the old behaviour.
* **Breaking:** the generated class is now `abstract final` rather than a plain
  class with a private constructor. It states the intent directly — a namespace
  of constants that can be neither instantiated nor extended — and drops the
  unused constructor.
* **Breaking:** minimum Dart SDK is now 3.5.
* Upgrade all dependencies, including `xml` 6 to 7.
* Drop the `recase` and `logger` dependencies. `recase` was pulled in for one
  call; `logger` for four lines of levelled output. Both are now a few lines of
  local code, which also removes their transitive `clock` and `meta`.
* Restructure the source into one responsibility per file. Stroke outlining,
  Bézier geometry, CFF, the OTF tables and the CLI each became a directory of
  focused files rather than one large one; existing import paths still work
  through barrel files. Behaviour is unchanged — the generated font is
  byte-for-byte identical.
* Remove the CFF charstring interpreter's read path. It was unreachable, and it
  did not advance the read offset past multi-byte operands, so it would have
  misparsed any charstring it was pointed at. `CharStringInterpreter` is now
  `CharStringWriter`.
* Remove `CFFOperand.forceLargeInt`. No caller set it, and `size` did not
  account for it, so enabling it would have produced a corrupt table.

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
