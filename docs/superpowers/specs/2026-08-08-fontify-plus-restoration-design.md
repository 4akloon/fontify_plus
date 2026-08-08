# fontify_plus — restoration & hardening

Date: 2026-08-08

## Problem

`fontify_plus` 0.4.3 cannot produce a font at all. Both output paths fail on the
package's own test assets (`test/assets/svg/`), not just on user icons:

```
useOpenType=true  (CFF/PostScript) -> RangeError: Not in inclusive range 25..26: 29
useOpenType=false (TrueType/glyf)  -> UnimplementedError: Cubic to quadratic curve conversion not supported
```

The 35 existing tests all pass, because none of them writes a font end to end.

### Root cause of the CFF crash

`CFFIndexWithData._cachedIndex` (`lib/src/otf/cff/index.dart`) is populated on the
first call to `size` or `recalculateOffsets()` and is never invalidated.

The first call happens while the Top DICT still holds zero-value placeholder
operands, so the cached index records a 26-byte element. `_calculateEntryOffsets`
then grows those operands to their real byte width (29 bytes). Every later call
returns the stale 26. `CFFIndexWithData.encodeToBinary` sizes its sub-view from
the cached index (26) while the encoder writes the live `CFFDict` (29), and
`ByteData.sublistView` throws.

Measured, and stable across repeated `recalculateOffsets()` calls:

```
pass 0: live topDict.size=29  cachedIndexElemSize=26  topDicts.size=31
pass 1: live topDict.size=29  cachedIndexElemSize=26  topDicts.size=31
```

Introduced by commit `838fe3d`, which implemented upstream's
`// TODO: memoize` comment with an unconditional cache. Every published 0.4.x is
therefore broken.

### Why user icons rendered badly (separate, real issue)

The target icon set (`zeely-mobile/packages/design_system/assets/icons`, 32 files)
is entirely stroke-based:

```svg
<path d="M8 2.66667V13.3333M13.3333 8H2.66666"
      stroke="currentColor" stroke-width="1.33" fill="none" />
```

`lib/src/svg/svg.dart:22` states that `fill` and `stroke` are ignored. Font
glyphs are fill-only by format, so a zero-area stroke centreline becomes an empty
or degenerate filled contour.

## Non-goals

- Cubic-to-quadratic conversion / working TrueType (`glyf`) output. Flutter
  renders CFF-outline OTF correctly. The TrueType path stays unimplemented but
  must fail with an explicit, documented error rather than a bare
  `UnimplementedError` at runtime.

## Design

### Phase 0 — Repository hygiene

94 files are staged as modified purely by mode change (`100644` -> `100755`) with
zero content diff. Restore 644 and set `core.fileMode false`.

### Phase 1 — Fix the CFF crash

Invalidate `_cachedIndex` at the start of `recalculateOffsets()` before calling
`_calculateIndex()`. Memoization is retained — the index genuinely is requested
three times per write — but becomes correct.

Add an assertion in `CFFIndexWithData.encodeToBinary` that each element's cached
size equals its live size, so this class of regression fails loudly and
immediately instead of as an opaque `RangeError` deep in a sub-view.

### Phase 2 — End-to-end regression test

`test/e2e_test.dart`: SVG -> OTF bytes -> parse back with the package's own
`OTFReader` -> assert `numGlyphs`, `cmap` entries, and contour bounds. This is
the coverage gap that let a total failure ship.

### Phase 3 — stroke-to-outline conversion

New `lib/src/svg/stroke_to_outline.dart`. Approach: flatten-then-offset, relying
on nonzero winding rather than boolean path union.

1. Parse `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`
   (currently discarded in `lib/src/svg/element.dart`).
2. Flatten cubic/quadratic segments to polylines at an adaptive tolerance.
3. Open subpath -> one closed contour: offset `+w/2` forward, end cap, offset
   `-w/2` backward, start cap.
4. Closed subpath (e.g. the `<circle>` in `alert_circle.svg`) -> two contours,
   outer `+w/2` and inner `-w/2` with reversed orientation, forming an annulus.
5. Joins: round, miter (falling back to bevel past `stroke-miterlimit`), bevel.
   Caps: butt, round, square.

CFF fills using the nonzero winding rule, so overlapping contours of the same
orientation merge without an explicit union. This is what makes the feature
tractable, and it is what correctly renders `plus_sign.svg` (two crossing
strokes) and every other multi-subpath icon in the set.

**Ordering constraint:** `stroke-width` is expressed in viewBox units, so
outlining must run *before* glyph normalization/resizing, or stroke weight
scales incorrectly.

Enabled by default (`--no-outline-strokes` to opt out). No backward-compatibility
risk: filled icons carry no `stroke` attribute.

**Accepted trade-off:** a self-intersecting single stroke can in principle
produce a reversed inner loop, appearing as a hole. No icon in the target set
does this. A test will characterize the behaviour rather than claim it cannot
happen.

### Phase 4 — SDK, dependencies, pub.dev score

- `sdk: ">=3.5.0 <4.0.0"`.
- Upgrade all 7 outdated direct dependencies. `xml` 6 -> 7 is a major bump;
  verify parser API usage.
- Add `repository:`, `issue_tracker:`, `topics:` to `pubspec.yaml`.
- Add dartdoc to the public API — `lib/fontify_plus.dart` currently has zero doc
  comments.
- `LICENSE` begins with a markdown heading (`# MIT License`), which can defeat
  pana's license detection. Replace with canonical MIT text.

If `lints ^6` requires an SDK above 3.5, resolve by pinning `lints ^5` rather
than raising the floor — the 3.5 minimum is a stated requirement.

### Phase 5 — Port repository settings from basalt_dart

- `analysis_options.yaml`: full lint list plus `formatter: trailing_commas: preserve`,
  minus Flutter-only rules (`use_colored_box`, `sized_box_shrink_expand`).
- `.gitignore`, `CONTRIBUTING.md`, `CLAUDE.md`.
- `.github/workflows/ci.yml` adapted to a single-package repo:
  format -> analyze -> test -> publish dry-run.
- `.github/workflows/publish.yml` adapted to OIDC publishing on a `v*` tag.

### Phase 6 — Figma export guide

`doc/figma-export.md` plus a README section: why font glyphs are fill-only, how
to configure Figma export, and what the stroke validator reports.

## Verification

The package is only considered fixed when all 32 icons in
`zeely-mobile/packages/design_system/assets/icons` convert to an OTF that parses
back correctly, with stroke geometry preserved.

## Outcome

Implemented as designed. Two defects beyond the two identified above surfaced
during the work and were fixed alongside them:

- **`ignoreShapes` defaulted to true**, silently discarding `<circle>`,
  `<rect>`, `<line>`, `<polyline>` and `<polygon>`. This is why
  `alert_circle.svg` and `information_circle.svg` measured zero width — the ring
  was dropped and only the two interior line paths survived. The default is now
  false.
- **`PathToOutlineConverter.moveTo` did not start a new subpath**, so a path
  such as `M8 2V13 M13 8H2` accumulated both strokes into one contour. Fixed in
  both the converter and the new stroke flattener.

The CFF fix landed as cache removal rather than cache invalidation: validating a
cache costs the same O(n) walk over live element sizes as recomputing it, so the
memoization bought nothing that justified the hazard.

One design assumption was corrected during implementation. Skipping join
geometry on the inner side of a corner is right for *outer* joins but leaves the
two offset edges overrunning each other at inner corners. Inner corners are now
trimmed back to the crossing point, which is what makes a stroked rectangle
measure its exact ring area rather than running ~2.5% over.

Verified: all 32 target icons convert with no flags, every glyph encloses real
area, and the rendered contact sheet matches the source artwork — including the
mirrored pairs (`layout_align_left`/`right`, `arrow_up_narrow_wide`/`wide_narrow`)
that must not collapse into each other.
