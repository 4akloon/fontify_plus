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

   As of `fontify_plus` 0.5.2 this check **does not** pass for the `glyf`
   masters, and the reason is not the glyph choice. See Results.

3. `python3 build_variable.py`

   Merges the masters with `fontTools.varLib` into `out/variable_cff2.otf`,
   `out/variable_gvar.ttf` and `out/variable_gvar_noiup.ttf`. Watch stdout for
   `has incompatible masters; skipping` — `varLib` warns rather than failing,
   and a skipped glyph silently stops responding to the axis.

4. `python3 gates.py`

   The four gates, one block per candidate. Exits non-zero if any fails.

5. `python3 plan_once_probe.py` — optional, and the one script here that
   measures a technique the package does not implement. See Results.

`out/` is generated and gitignored; nothing under it is committed.

## Results

Recorded against `fontify_plus` 0.5.2, fontTools 4.60.2, OTS 9.2.0, Flutter
3.44.8. The prototypes were regenerated after 0.5.2 fixed two writer bugs that
had made every TrueType font this package emitted geometrically wrong
(`glyf.dart` discarded the cubic→quadratic conversion; `hmtx` hardcoded `lsb`
to 0). Both fixes are TrueType-only — the CFF masters' outlines are unchanged
byte-for-byte, so only the `glyf`/`gvar` numbers moved.

### Gates

`python3 gates.py`, plus `ots-sanitize` run separately (the PyPI
`opentype-sanitizer` package ships the real binary; Homebrew's `ots` formula is
an unrelated project).

| Gate | `variable_cff2.otf` | `variable_gvar.ttf` | `variable_gvar_noiup.ttf` |
|---|---|---|---|
| Parse (fontTools round-trip) | PASS | PASS | PASS |
| OTS 9.2.0 sanitize | PASS, no warnings | PASS, no warnings | PASS, no warnings |
| Correctness (instanced at 1.33 / 1.5 / 2.0 vs a separately built static, tolerance 2 units) | PASS — worst 2.00 units | **FAIL** — `uniE002` @1.33, 74 points vs 78 | **FAIL** — same |
| Subset survival (`fvar` + variation table after subsetting) | PASS (968 B) | PASS (1024 B) | PASS (1024 B) |
| Size, unsubsetted (scaling bytes vs static 2.0) | PASS — 1.16× (263 vs 226) | PASS — 1.21× (382 vs 316) † | PASS — 1.27× (402 vs 316) † |
| Size, after subsetting (scaling bytes vs the same static, subsetted identically) | PASS — 1.24× (ring only), 1.22× (all three) | not measured — candidate already failed | not measured |

† These two ratios flatter `gvar`. See below: the font they measure is missing
a third of its variation data, because `varLib` dropped `ring`.

The spec requires ≤ 1.5× before *and* after subsetting. Only CFF2 has been
measured on the "after" half; earlier tasks measured absolute subsetted sizes
but never a ratio.

Two standing weaknesses in the gates themselves, neither resolved:

- **The correctness gate has no margin.** CFF2's worst deviation is exactly
  2.00 units against a tolerance of exactly 2, so the gate cannot currently
  distinguish a real regression from integer rounding. Per stop: 1.33 exact,
  1.5 worst 2.00 (`ring`) / 1.00 (`plus`), 2.0 exact — the deviation is
  entirely at the interpolated stop, which is the expected place for it, but
  the gate would not report it any differently if it were a defect.
- **The size gate is not symmetric across formats.** For CFF it sums
  charstring bytecode; for TrueType it sums the whole `glyf` + `gvar` tables,
  which carry per-glyph headers the CFF side excludes. The upem also differs
  (1000 for CFF masters, 1024 for `glyf`), so a tolerance in raw font units is
  not the same tolerance in the two families.

### Why `glyf`+`gvar` fails the correctness gate

Once `cubicToQuad()` actually runs, the subdivision it chooses depends on the
radius it is fed, and a 4 % change in radius is enough to change the answer.
The masters stop being point-compatible:

| Glyph | 1.33 | 1.5 | 2.0 | Verdict |
|---|---:|---:|---:|---|
| `dot` (`uniE000`) | 12 | 12 | 12 | compatible — pure fill, no width dependence |
| `plus` (`uniE001`) | 28 | 24 | 28 | incompatible; the two endpoints happen to coincide |
| `ring` (`uniE002`) | 37 | 40 | 35 | incompatible |

CFF is 13 / 30 / 26 at every width: cubics need no conversion, so there is no
width-dependent decision to make.

`varLib` does not treat this as an error. It prints

```
glyph uniE002 has incompatible masters; skipping
```

and builds the font anyway. The resulting `gvar` table carries **zero regions
for `uniE002`** — the icon is still in the font, still renders, and silently
stops responding to the axis. (The gate's counts are flattened pen
coordinates; the `glyf` point counts behind "74 vs 78" are 35 and 37, the 2.0
and 1.33 rows of the table above.)

`plus` survives only because its two *endpoint* masters coincide at 28 points.
Instanced at 1.5 it still mismatches the static built at 1.5 — 28 points
against 24 — because a static build at 1.5 plans a different quadratic
structure. Both failures are the same defect seen from two sides: with a
per-width plan, "the variable font at *w*" and "the static font built at *w*"
are not the same font.

This was invisible in every earlier round because no conversion was happening.

### `glyf`+`gvar` is priced by this, not disqualified

The spec (section 3) already predicted this as a *third* site needing the
plan-once/evaluate-per-width discipline Phase 1 applies to the offsetter. That
discipline does fix it. Run `python3 plan_once_probe.py` to reproduce
everything in this section; it converts the three CFF masters to quadratics
under one shared subdivision plan (`fontTools.pens.cu2quPen.Cu2QuMultiPen`, the
technique `fontmake` uses for every TrueType variable font it ships), merges
them, and runs the gate's own byte counting on the result. At `max_err` 1.0
font unit:

- point-compatible masters at every width — 16 / 28 / 40 for dot / plus / ring,
- a `varLib` build with **no warnings**, and `gvar` deltas on both glyphs that
  should have them (`dot` correctly still has none — it is the fill control),
- correctness **1.00 unit** worst deviation, against CFF2's 2.00,
- OTS clean,
- and **1.50×** against its own plan-once static 2.0 (460 scaling bytes vs
  306), where CFF2 is 1.16×.

**Read the ratio against the right baseline.** The probe prints two, and they
diverge by enough to change the conclusion:

| `max_err` | ring points | vs own plan-once static 2.0 | vs the package's per-width static 2.0 |
|---:|---:|---:|---:|
| 0.5 | 48 | 1.55× | 1.62× |
| 1.0 | 40 | **1.50×** | 1.46× |
| 2.0 | 32 | 1.51× | 1.33× |
| 4.0 | 24 | 1.57× | 1.14× |

The first column is the meaningful one: both sides move together with the
tolerance, so it isolates what variation costs on top of an outline, and it
stays flat at 1.50–1.57× — structural, not a tolerance artifact. The second
column holds the denominator fixed at today's per-width output while the
numerator moves, so it slides across the whole 1.14–1.62× range and says more
about the tolerance than about `gvar`. It is reported only because it is the
comparison someone will reach for by mistake, and because it is the honest
answer to a different question: what a plan-once *variable* font costs against
the per-width *static* font that ships today.

This is a probe of a technique the package does not implement, not a
measurement of what `fontify_plus` would emit. But on the apples-to-apples
baseline it is the right order of magnitude, and it says a `gvar` font that
actually varies every glyph sits on the ≤ 1.5× gate with no headroom. It also
says the 1.21× in the gate table above is not a size `gvar` can achieve — that
is the size of a font that dropped a glyph's variation.

### Platform matrix

From Task 4's third round, the only round whose reference pairing is correct
(each variable font judged against static masters of *its own* outline format;
the first two rounds compared `gvar` against a CFF reference and are void).
Every threshold is self-calibrating: a fraction of `staticSpan`, the measured
raster change from rebuilding the font at 1.33 vs 2.0, with a floor that fails
if the font did not load.

| Platform | Backend | Format | matches static @1.5 | axis is applied | fill invariant | clamps |
|---|---|---|---|---|---|---|
| macOS desktop | Skia / CoreText | CFF2 | PASS | PASS | PASS | PASS |
| macOS desktop | Skia / CoreText | gvar ‡ | PASS | PASS | PASS | PASS |
| iPhone 17 Pro sim (iOS 26.5) | Impeller | CFF2 | PASS | PASS | PASS | PASS |
| iPhone 17 Pro sim (iOS 26.5) | Impeller | gvar ‡ | FAIL — `plus`, 0.0031467 vs < 0.0026693 | PASS | PASS | PASS |
| Pixel 8 Pro emu (Android 16) | Skia/GL | CFF2 | PASS | PASS | PASS | PASS |
| Pixel 8 Pro emu (Android 16) | Skia/GL | gvar ‡ | FAIL — `ring`, 0.0230035 vs < 0.0070964 | PASS | PASS | PASS |
| Pixel 8 Pro emu (Android 16) | Impeller | CFF2 | PASS | PASS | PASS | PASS |
| Pixel 8 Pro emu (Android 16) | Impeller | gvar ‡ | FAIL — same glyph, byte-identical value | PASS | PASS | PASS |
| Chrome 151 | CanvasKit | CFF2 | PASS | PASS | PASS | PASS |
| Chrome 151 | CanvasKit | gvar ‡ | FAIL — `ring`, 0.0230035 vs < 0.0070530 | PASS | PASS | PASS |
| Chrome 151 | skwasm (`--wasm`) | CFF2 | INFERRED | INFERRED | INFERRED | INFERRED |
| Chrome 151 | skwasm (`--wasm`) | gvar ‡ | FAIL — re-run in isolation, byte-identical to CanvasKit | INFERRED | INFERRED | INFERRED |
| Linux desktop | — | both | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Windows desktop | — | both | NOT RUN | NOT RUN | NOT RUN | NOT RUN |

- **NOT RUN** means exactly that: no Linux or Windows target exists on the
  Darwin host this was measured on. These are holes in the evidence, not
  passes, and they are holes for the chosen format too.
- **INFERRED** means the assertion was not executed and reported for that cell.
  `flutter drive`'s web output surfaces one aggregated failure block per run,
  so the passing assertions on skwasm were never isolated. The inference is
  that skwasm matches CanvasKit, supported by the one skwasm value that *was*
  captured being bit-identical to CanvasKit's. Reasonable, unverified. One
  CanvasKit pass/fail counter in the source report is internally inconsistent
  (`+8 -1` where only `+7 -1` is possible), so at least one figure in that row
  was transcribed by hand.
- ‡ **The `gvar` rows are stale and must not be cited as evidence against the
  format.** They were measured on fonts built before 0.5.2. The 0.0230035
  failures were traced to the `hmtx` `lsb` bug (FreeType derives phantom point
  `pp1.x = xMin − lsb` from the default instance and translates every varied
  outline by it; patching `lsb := xMin` collapsed the residual to exactly
  0.0000000) and would not recur. The iOS 0.0031467 was a genuine sub-font-unit
  master-rounding residual just over a very tight self-calibrated bar. Neither
  survives as a `gvar` defect. Re-running the matrix on today's fonts would
  produce a *different* `gvar` failure — `ring` carries no deltas, so the
  "axis is applied" assertion, which tests `ring` first, cannot pass — but that
  would be a build-pipeline failure, not an engine one.
- The CFF2 rows are unaffected by the 0.5.2 regeneration. The CFF outlines are
  identical before and after (verified pen-op by pen-op); only `hmtx.lsb`,
  `hhea.xMaxExtent` and timestamps changed, and CFF does not position glyphs
  from `lsb`.

**Subsetting.** `flutter build apk/ios --release --tree-shake-icons` with a
forced `const IconData` reference subsets both candidates and preserves
`fvar`, the variation table, `STAT` and `HVAR` intact, with the axis range
unchanged; the subsetted fonts still instance correctly under
`fontTools.varLib.instancer`. Android and iOS produce byte-identical subsetted
output. The subsetter does not drop the axis.

### Decision: CFF2 + `blend`

CFF2 passes all six gates and every assertion on every platform that was
measured. `glyf`+`gvar` fails the correctness gate today, and the work that
would fix it is a third plan-once site in the package's geometry pipeline,
after which its size lands on the ≤ 1.5× gate with roughly no headroom while
CFF2 sits at 1.16× unsubsetted and 1.22–1.24× subsetted.

So `gvar` is more code to write, for a font that is measurably larger — and,
to be exact about it, one that is slightly *more* accurate: on the one gate
where the two are cleanly comparable, plan-once `gvar` interpolates to 1.00
unit against CFF2's 2.00. **The decision rests on size headroom and build
cost, not on correctness, and the rejected format is the one ahead on
correctness.** Two units at upem 1000 is invisible and both clear the
tolerance, so this does not come close to outweighing a whole extra planning
site plus a `gvar` writer plus the entire size budget — but it is a point
against the choice, not for it, and the summary paragraph is the wrong place
to round it away.

The two formats were indistinguishable on the pre-0.5.2 evidence. Fixing the
writer is what separated them, and it separated them on cost.

What follows, against the kill criteria the spec registered in advance:

- **Both formats fail the render matrix → fall back to `A′`.** Not triggered.
  CFF2 passes on macOS, iOS, Android (both backends) and Chrome/CanvasKit, and
  the axis-application assertion — the one that catches an engine silently
  ignoring `FontVariation` — passes for both formats everywhere it ran. Three
  static assets selected by `Icon.fontWeight` is off the table.
- **The subsetter drops the axis → the font must fit the budget unsubsetted.**
  Not triggered. `--tree-shake-icons` preserves the axis on both release
  pipelines, so it does not have to be disabled, and CFF2 clears the budget in
  both states anyway.
- **Only one format survives → the other branch is never written.** CFF2 is
  the surviving format. The `glyf`+`gvar` branch — the `gvar` table writer,
  packed point numbers and deltas, IUP, and the cubic→quadratic plan-once site
  the spec listed as its precondition — is not written. Phase 1's two
  plan/evaluate sites (the offset recursion and the straight/curved plus
  `dropRepeatedStart` decisions) are format-independent and still required.

### What this does not establish

- Linux and Windows were never tested, for either format.
- Variable CFF2 is rare in the wild; that was the spec's stated risk for this
  branch and the reason `gvar` was a candidate at all. Phase 0 retires the risk
  only on the surface it measured. `gvar` remains the format the rest of the
  web uses, and if a platform outside this matrix mishandles CFF2, the
  fallback is expensive because the `gvar` branch will not exist.
- Every prototype here was merged by `fontTools.varLib`, not by this package.
  Phase 0 shows CFF2 works; it does not show that *this package's* CFF2 writer
  will.
- Three toy glyphs. The size ratios are directional, not quantitative. Do not
  read 1.16 vs 1.21 as a 4 % ranking — the two sides are not measured
  symmetrically and the `gvar` side is measured on an incomplete font. What
  survives scrutiny is the difference in headroom against the gate, not the
  gap between those two numbers.
- The render matrix is a standing gate, not a one-off. It must be wired into CI
  (Phase 3), and its fonts under `example/fonts/proto/` are still the pre-0.5.2
  copies — they need regenerating, and the `ProtoGlyf*`/`ProtoGvar` families
  can be retired with the `gvar` candidate.
