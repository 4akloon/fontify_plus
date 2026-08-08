# Changelog

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
* `CONTRIBUTING.md`, CI across Dart 3.5 and stable, and automated publishing.

### Changed

* **Breaking:** `ignoreShapes` now defaults to false, so `<circle>`, `<rect>`,
  `<line>`, `<polyline>` and `<polygon>` are converted to paths instead of being
  silently discarded. Pass `--ignore-shapes` for the old behaviour.
* **Breaking:** minimum Dart SDK is now 3.5.
* Upgrade all dependencies, including `xml` 6 to 7.

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
