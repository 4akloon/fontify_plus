# Changelog

## Unreleased

* **Breaking:** `OS2Table`'s 39 positional parameters are gone. The
  constructor now takes named parameters, and the fields live in one object
  per version that introduced them, **nested** the way OpenType's versions
  accumulate: `version0` (`OS2Version0Fields`, always present) and a nullable
  `version1` (`OS2Version1Fields`) that owns a nullable `version4`
  (`OS2Version4Fields`) that owns a nullable `version5`
  (`OS2Version5Fields`). Roughly thirty of those positional parameters were
  adjacent `int`s — `ySubscriptXSize` next to `ySubscriptYSize`, the four
  `ulUnicodeRange`s, the two `ulCodePageRange`s, the `sTypo*`/`usWin*` runs —
  so transposing a neighbouring pair compiled, analyzed clean and shipped a
  font that was wrong only in the rendering.
  Nesting settles the second half. A null group means the table ends there,
  which is the rule the format already has, and because a higher group has
  nowhere to live except inside a lower one, `sxHeight` set while
  `ulCodePageRange1` is absent genuinely does not type-check. Reading a field
  moves down the chain: `table.achVendID` becomes `table.version0.achVendID`,
  and `table.sxHeight` becomes `table.version4?.sxHeight` — `version4` and
  `version5` remain on `OS2Table` as shorthand getters for
  `version1?.version4` and `version1?.version4?.version5`, and the `?` is the
  reminder that a version-1 table genuinely has no `sxHeight`.
  `version` is still a stored `int` and still reports what the font declares,
  including the versions 2 and 3 that add no fields this package models. The
  one thing nesting cannot enforce is that `version` agrees with the groups,
  so **the constructor now throws `TableDataFormatException` when it does
  not** — in either direction, in release builds as well as debug. That
  replaces a check the previous encoder made by force-unwrapping each
  optional field: building a version-5 table without its version-5 group used
  to crash on encode, and must not instead emit a 96-byte table whose version
  field claims 100 bytes of content.
  `size` is now counted from the groups present rather than from `version`.
  For every table this package can read out of a well-formed font it produces
  the same number as before; for a corrupt table whose version field is
  negative (`version` is read as an `int16`, so 0xFFFF arrives as -1) it now
  measures 78 bytes and re-encodes a version-0-shaped table carrying that
  version verbatim, where it used to measure 0 and fail mid-encode with an
  `IndexError`. The encoded byte order is untouched. (`OS2Table` itself is not
  exported from `package:fontify_plus/fontify_plus.dart`, but every one of its
  fields is reachable through `OpenTypeFont.os2`, so reading code breaks even
  without a `src/` import.)
* **Breaking for `src/` importers:** the other positional constructors whose
  neighbouring parameters share a type now take named parameters too, so that
  a transposition stops compiling instead of shipping —
  `HeaderTable` (and `HeaderTable._`), `HorizontalHeaderTable`,
  `MaximumProfileTable.v1`, `CmapSegmentMappingToDeltaValuesTable`,
  `CmapSegmentedCoverageTable`, `CmapByteEncodingTable`, `CmapSegment`,
  `CharacterToGlyphTableHeader`, `EncodingRecord`, `SequentialMapGroup`,
  `CFF1Table`, `CFF2Table`, `CFF1TableHeader`, `CFF2TableHeader`, `CFFIndex`,
  `ItemVariationStore`, `ItemVariationData`, `VariationRegionList`,
  `RegionAxisCoordinates`, `PostScriptTableHeader`, `SimpleGlyphFlag`,
  `SimpleGlyph`, `GlyphHeader`, `GenericGlyphMetrics`, `Outline`,
  `OffsetTable`, `TableRecordEntry`, `NameRecord` (both constructors),
  `NamingTableFormat0Header`, `LookupTable`, `LigatureSubstitutionSubtable`,
  `CoverageTableFormat1`, `FeatureTable`, `LanguageSystemTable`,
  `ScriptTable`, `GlyphSubstitutionTableHeader`,
  `SimpleGlyphFlag.createForPoint`, `CFFOperand.fromByteData`,
  `CharStringOperand.fromByteData` and `HorizontalHeaderTable.create`.
  `SimpleGlyphFlag` took seven bools in a row; `GlyphHeader(numberOfContours,
  xMin, yMin, xMax, yMax)` and `GenericGlyphMetrics(xMin, xMax, yMin, yMax)`
  ordered the same four concepts differently, so code moving between them
  interleaved x and y with a clean analyze; `createForPoint(x, y, isOnCurve)`
  was called from that same interleaving code as
  `createForPoint(relX[i], relY[i], …)`.
  A leading parameter of a type none of the others share stays positional —
  the table record entry, a cmap subtable's format, a table record's tag, the
  `ByteData` an operand is read from.
  Two constructors in `lib/` still take three or more positional parameters
  with a same-typed adjacency, and both are deliberate:
  `Cubic(p0, p1, p2, p3)` takes an indexed sequence rather than distinct
  roles — the name *is* the index, so `p1:`/`p2:` protects against nothing —
  and `IndexToLocationTable.fromByteData(byteData, entry, indexToLocFormat,
  numGlyphs)` has one call site in the library, distinctly-named locals, and a
  swap that fails loudly rather than silently, since a 0/1 format flag and a
  glyph count are not plausible substitutes for one another. Everything else
  either has distinct types at every adjacency or takes two parameters, which
  is a pair rather than a list. No field, name, type or encoded offset changed,
  and none of these classes are exported from the main library, so only code
  importing `src/` directly is affected.
* **Breaking:** `OpenTypeFont.glyf`, `.loca`, `.cff` and `.cff2` are now
  nullable (`GlyphDataTable?`, `IndexToLocationTable?`, `CFF1Table?`,
  `CFF2Table?`). They previously returned a non-nullable type by casting the
  table map, so asking a CFF font for `glyf` — a table that font format
  genuinely does not have — threw a bare `TypeError` naming neither the tag
  nor the type. Returning null is the point: "this font has no glyf" is a
  legitimate answer, not a failure. Downstream code that writes
  `font.glyf.glyphList` stops compiling on upgrade. A caller that is
  branching on the outline format should treat the null as the branch
  (`if (font.glyf case final glyf?)`, or `font.glyf?.glyphList`); a caller
  that already knows the format — because it just built the font, or read a
  file it controls — should say so with
  `font.tables.require<GlyphDataTable>(kGlyfTag)`, which throws
  `TableDataFormatException` naming the missing tag instead of returning
  null. Every other table getter (`head`, `maxp`, `gsub`, `os2`, `post`,
  `name`, `cmap`, `hhea`, `hmtx`) keeps its non-nullable type and is
  unaffected at the call site, but now also throws that named
  `TableDataFormatException` rather than a `TypeError` when the table really
  is absent. Two new nullable getters, `fvar` and `stat`, join them for
  variable-font metadata; both are null on the static fonts this version
  writes.
* **Breaking, with no compile-time warning:** `OpenTypeFont.tableMap` is now
  a read-only view (`UnmodifiableMapView`) over the font's tables rather than
  the underlying map. Reading, iterating, counting and `containsKey` are
  unchanged, but **a write such as `font.tableMap[kFvarTag] = myTable` still
  compiles and now throws `UnsupportedError` at runtime.** The tables belong
  to the new `FontTables` object behind `OpenTypeFont.tables`, which hands
  out typed, tag-named access (`tables.lookup<T>(tag)` for "null if this font
  has none", `tables.require<T>(tag)` for "fail naming the tag") instead of
  the `tableMap[tag] as T` casts that used to be the only way in. There is no
  supported replacement for mutating a font's table set after construction:
  build the map first and pass it to the `OpenTypeFont` constructor, whose
  signature is unchanged.
* `OpenTypeFont.createFromGlyphs` can now build a **variable font** whose
  `wght` axis is the icon's stroke width. Pass `minGlyphList` — the same
  glyphs as `glyphList`, in the same order, drawn at the thin end of the
  range — together with `strokeWidthRange`, and the outlines move out of
  `CFF` into a `CFF2` table carrying both masters, while `fvar` and `STAT`
  declare the axis and a `name` record labels it "Stroke Width". The axis
  values are literal stroke widths, so `Icon(icon, weight: 1.33)` asks for a
  stroke width of 1.33 rather than for a rescaling of one.
  `glyphList` stays the *default* master — the maximum width — because that
  is the instance `fvar` selects by default and the one every metric is
  computed from. No `HVAR` table is written and none is needed: `hmtx` is
  emitted once, from that master, so a glyph's advance is the same at every
  point on the axis. Note that this advance is *not* a uniform em under the
  default `normalize: true` — it is each glyph's own ink width, so the four
  icons in this package's `example/svg` advance by 947, 1000, 958 and 1000
  at 1000 upem. Pass `normalize: false` for a uniform one-em advance. Either
  way the number is the widest master's, so a thin instance gains
  sidebearing rather than reflowing as the axis moves.
  Both masters are fitted onto the em square with **one** transform, taken
  from the default master, never with one transform each. Fitting the thinner
  master on its own would scale it up until its own longest side filled the
  same em band, which moves the centreline between the masters and bends
  every width in between — a font that parses, sanitizes and renders
  correctly at both endpoints and subtly wrong everywhere else.
  The two parameters must be supplied together, must be the same length, and
  require `useOpenType: true`, since a TrueType variable font would need
  `gvar`, which this package does not write; every other combination throws
  `ArgumentError`. `StrokeWidthRange` is now exported from
  `package:fontify_plus/fontify_plus.dart`.
  Omitting both leaves the static path untouched, down to the byte.
  Note one limitation: `OpenTypeFont.fromByteData` cannot read `fvar` or
  `STAT` back, so a read-modify-write round trip through `OTFReader` turns a
  variable font into a static one.
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
* A straight edge could cost dozens to hundreds of extra cubics, and, for a
  variable stroke-width axis, quietly break the promise that every control
  point moves affinely between two width masters. The offset
  approximation's parallel-tangent test compared the *unnormalised*
  determinant against a fixed length-scale constant with no relation to
  that quantity; float32 rounding in the tangent computation routinely put
  a mathematically dead-straight edge's determinant six orders of magnitude
  above that threshold, so the near-singular two-tangent solve ran instead
  of the straight-line fallback — a division that, this close to singular,
  amplified rounding noise into distorted control points and, at worst, a
  subdivision run that never converged. The test now thresholds the
  *normalised* cross product of the two tangents against an epsilon
  measured from both sides: up to 3.66e-4 of genuine float32 noise across a
  wide sweep of edge directions and coordinate scales, comfortably below
  where a genuinely curved segment needs the full solve. Shapes move
  slightly — toward the true offset, since the fallback is exact for a
  straight edge and the solve it replaces was not — but by far less than
  the curve-fitting tolerance already in use elsewhere in this pipeline:
  this package's own `arrow_right` and `check` icons shift their affected
  contours by under 0.13%, at most a few tenths of a unit at 1000 upem.
  Those two icons' point counts drop from 376 and 97 to 37 and 22; an
  ordinary triangle's one affected edge (offset in both directions, so
  counted twice per contour) collapses from 193- and 66-piece
  approximations to one each.

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
