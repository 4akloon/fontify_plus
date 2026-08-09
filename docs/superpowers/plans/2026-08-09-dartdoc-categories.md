# Dartdoc Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add basalt-style dartdoc categories and guides to `fontify_plus`, slim the README, then open a PR to `master` and delete `fix/restore-font-generation`.

**Architecture:** Root `dartdoc_options.yaml` names five topic categories. Each has a `doc/<slug>.md` guide. Public entry points get `{@category api}` in their `///` docs. README keeps the pitch and Notes/Planned; long how-to sections become one-paragraph pointers into those guides. Verification is `dart doc .` with zero warnings.

**Tech Stack:** Dart 3.10, dartdoc via `dart doc`, no new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-09-dartdoc-categories-design.md`

## Global Constraints

- Categories exactly: `getting-started`, `api`, `stroked-icons`, `glyph-sizing`, `cli` — no `figma-export`.
- `displayName` must not case-collide with the slug (e.g. `API Usage`, not `API`).
- In `doc/*.md` guides use `` `Symbol` ``, never `[Symbol]`.
- Every category must have ≥1 tagged member (dartdoc omits empty topics).
- Category tags (multiple `{@category}` lines on one symbol are OK):
  - `lib/fontify_plus.dart` library doc: `getting-started`, `cli`
  - `svgToOtf`: `api`, `stroked-icons`, `glyph-sizing`
  - `generateFlutterClass`, `SvgToOtfResult`, `OpenTypeFont`, `writeToFile`, `readFromFile`: `api` only
- Do not delete `doc/figma-export.md`; only remove links to it from README (and anywhere else you touch).
- `doc/api/` stays gitignored; never commit it.
- Do not commit unless the user asks, or the task's commit step is explicitly approved. Prefer pathspec adds — never bare `git add -A`.
- PR base is `master` (repo default), not `main`.
- `fix/restore-font-generation` is already an ancestor of `feat/vgc-migration`; delete local + remote after the PR is up.

## File map

| Path | Role |
|---|---|
| `dartdoc_options.yaml` | Category registry |
| `doc/getting_started.md` | First-run CLI + API |
| `doc/api.md` | Library entry points |
| `doc/stroked_icons.md` | Stroke outlining |
| `doc/glyph_sizing.md` | normalize vs artboard |
| `doc/cli.md` | Flags + yaml config |
| `lib/src/common/api.dart` | `{@category api}` on `SvgToOtfResult`, `svgToOtf`, `generateFlutterClass` |
| `lib/src/otf/otf.dart` | `{@category api}` on `OpenTypeFont` |
| `lib/src/otf/io.dart` | `{@category api}` on `readFromFile`, `writeToFile` |
| `lib/src/otf/stub.dart` | Same `{@category api}` on stub `readFromFile`/`writeToFile` if present |
| `README.md` | Slim landing; drop figma-export links |
| `lib/fontify_plus.dart` | Library overview + `{@category getting-started}` and `{@category cli}` |

---

### Task 1: `dartdoc_options.yaml` + five guides

**Files:**
- Create: `dartdoc_options.yaml`
- Create: `doc/getting_started.md`
- Create: `doc/api.md`
- Create: `doc/stroked_icons.md`
- Create: `doc/glyph_sizing.md`
- Create: `doc/cli.md`

**Interfaces:**
- Consumes: existing README / CLI flag names / `svgToOtf` API
- Produces: five category markdown files referenced by `dartdoc_options.yaml`

- [ ] **Step 1: Write `dartdoc_options.yaml`**

```yaml
dartdoc:
  categories:
    getting-started:
      markdown: doc/getting_started.md
      displayName: Getting Started
    api:
      markdown: doc/api.md
      displayName: API Usage
    stroked-icons:
      markdown: doc/stroked_icons.md
      displayName: Stroked Icons
    glyph-sizing:
      markdown: doc/glyph_sizing.md
      displayName: Glyph Sizing
    cli:
      markdown: doc/cli.md
      displayName: CLI & Config
  categoryOrder:
    - getting-started
    - api
    - stroked-icons
    - glyph-sizing
    - cli
  showUndocumentedCategories: true
```

- [ ] **Step 2: Write `doc/getting_started.md`**

```markdown
# Getting Started

fontify_plus turns a directory of SVG icons into an OpenType font and an optional
Flutter `IconData` class.

## CLI (fastest path)

```sh
dart pub global activate fontify_plus
fontify_plus assets/svg/ fonts/my_icons.otf \
  --output-class-file=lib/my_icons.dart -r
```

Then register the font in your Flutter `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: My Icons
      fonts:
        - asset: fonts/my_icons.otf
```

## API (same pipeline in Dart)

```dart
final result = svgToOtf(
  svgMap: {'arrow_up': await File('arrow_up.svg').readAsString()},
  fontName: 'My Icons',
);

writeToFile('MyIcons.otf', result.font);

final source = generateFlutterClass(
  glyphList: result.glyphList,
  familyName: result.font.familyName,
  className: 'MyIcons',
  fontFileName: 'MyIcons.otf',
);
```

## Where to go next

- **API Usage** — parameters on `svgToOtf` and `generateFlutterClass`.
- **Stroked Icons** — why outline-style SVGs need stroke conversion.
- **Glyph Sizing** — artboard mapping vs `--normalize`.
- **CLI & Config** — flags and the yaml config file.
```

- [ ] **Step 3: Write `doc/api.md`**

Content requirements (write full file):
- Show the same three-call pipeline as getting started.
- Document `svgToOtf` params: `svgMap`, `outlineStrokes` (default true), `normalize` (default false), `useOpenType` (default true), `fontName`.
- Document return type `SvgToOtfResult` (`glyphList`, `font`).
- Document `generateFlutterClass` params: `glyphList`, `className`, `familyName`, `package`, `fontFileName`, `indent`.
- Document `writeToFile` / `readFromFile`.
- Note: paint attributes other than stroke geometry are ignored; colour comes from Flutter text style.
- Use `` `svgToOtf` `` style refs only.

- [ ] **Step 4: Write `doc/stroked_icons.md`**

Content requirements:
- Explain fill-only glyphs (no stroke in font formats).
- Include a minimal stroked SVG example (centreline path).
- Explain default outlining (`outlineStrokes: true` / `--outline-strokes`).
- List honoured attrs: `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`, `stroke-dasharray` (incl. inherited from `<g>`).
- Note `stroke-dashoffset` is parsed upstream but has no effect (`vector_graphics_compiler` drops it).
- Opt-out: `--no-outline-strokes` / `outlineStrokes: false`.
- **Do not** link to `doc/figma-export.md`.

- [ ] **Step 5: Write `doc/glyph_sizing.md`**

Content requirements:
- Default: artboard maps onto the em square; `Icon(..., size: n)` matches SVG at n logical pixels.
- `--normalize` / `normalize: true`: each glyph scaled so longest side fills em, then centred — discards relative artboard occupancy.
- Recommend off for one design-file set; on only for mismatched viewBoxes.

- [ ] **Step 6: Write `doc/cli.md`**

Content requirements:
- Positional: `<input-svg-dir>` `<output-font-file>` (.otf).
- Flutter class flags: `-o/--output-class-file`, `-i/--indent`, `-c/--class-name`, `-p/--package`.
- Font flags: `-f/--font-name`, `--[no-]normalize`, `--[no-]outline-strokes`.
- Other: `-z/--config-file`, `-r/--recursive`, `-v/--verbose`, `-h/--help`.
- Yaml example under `fontify_plus:` key in `pubspec.yaml` or `fontify_plus.yaml` (keys matching current README: `input_svg_dir`, `output_font_file`, `output_class_file`, `class_name`, `indent`, `package`, `font_name`, `normalize`, `recursive`, `verbose`).
- One usage example command.

- [ ] **Step 7: Smoke `dart doc`**

Run: `dart doc . 2>&1 | tail -40`  
Expected: builds; category pages exist. Category-tag warnings for untagged API are OK until Task 2. Fail on broken markdown path errors.

- [ ] **Step 8: Commit (only if user asked)**

```bash
git add dartdoc_options.yaml doc/getting_started.md doc/api.md doc/stroked_icons.md doc/glyph_sizing.md doc/cli.md
git commit -m "$(cat <<'EOF'
docs: add dartdoc categories and topic guides

EOF
)"
```

---

### Task 2: `{@category api}` on entry points

**Files:**
- Modify: `lib/src/common/api.dart` (class + two top-levels)
- Modify: `lib/src/otf/otf.dart` (`OpenTypeFont` class doc)
- Modify: `lib/src/otf/io.dart` (`readFromFile`, `writeToFile`)
- Modify: `lib/src/otf/stub.dart` (conditional stubs — keep docs in sync)

**Interfaces:**
- Consumes: categories from Task 1
- Produces: tagged public symbols for the `api` topic

- [ ] **Step 1: Tag `lib/src/common/api.dart`**

Add `/// {@category api}` as the first line of the doc comment on:
- `SvgToOtfResult`
- `svgToOtf`
- `generateFlutterClass`

Example shape:

```dart
/// {@category api}
/// Converts SVG icons to OTF font.
///
/// ...
SvgToOtfResult svgToOtf({
```

- [ ] **Step 2: Tag `OpenTypeFont`**

In `lib/src/otf/otf.dart`, prepend `/// {@category api}` to the class doc of `OpenTypeFont`.

- [ ] **Step 3: Tag IO helpers**

In `lib/src/otf/io.dart` and `lib/src/otf/stub.dart`, prepend `/// {@category api}` to `readFromFile` and `writeToFile` docs.

- [ ] **Step 4: Verify**

Run: `dart doc . 2>&1`  
Expected: exit 0, no `unresolved doc reference`, no missing-category-file errors. Tagged symbols appear under API Usage.

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add lib/src/common/api.dart lib/src/otf/otf.dart lib/src/otf/io.dart lib/src/otf/stub.dart
git commit -m "$(cat <<'EOF'
docs: tag public entry points with {@category api}

EOF
)"
```

---

### Task 3: Slim README + drop figma-export links

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: guides from Task 1
- Produces: short landing that points at `doc/*.md`

- [ ] **Step 1: Rewrite long sections into pointers**

Keep the top pitch, CupertinoIcons/Icons links, and stroked-icons one-liner.

Replace the long **Using CLI tool**, **CLI tool config file**, **Using API**, **Stroked icons**, and **Glyph sizing** bodies with short paragraphs + relative links:

- CLI → [`doc/cli.md`](doc/cli.md) (keep one example command inline)
- API → [`doc/api.md`](doc/api.md) (keep one pub.dev API link or doc/api.md)
- Stroked icons → [`doc/stroked_icons.md`](doc/stroked_icons.md)
- Glyph sizing → [`doc/glyph_sizing.md`](doc/glyph_sizing.md)
- Getting started umbrella → [`doc/getting_started.md`](doc/getting_started.md)

Keep **Notes**, **Planned**, **Contributing**, **License** largely as-is.

- [ ] **Step 2: Remove every `doc/figma-export.md` link**

Search README for `figma-export` — zero matches after the edit. Do not delete `doc/figma-export.md`.

- [ ] **Step 3: Verify**

Run: `rg 'figma-export' README.md` → no matches.  
Run: `dart doc .` → still clean.

- [ ] **Step 4: Commit (only if user asked)**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: point README at dartdoc topic guides

EOF
)"
```

---

### Task 4: Final verify + PR + delete old fix branch

**Files:** none (git/gh only), optionally stage the superpowers spec/plan if the user wants them in the PR

- [ ] **Step 1: Final `dart doc`**

Run: `dart doc . 2>&1`  
Expected: exit 0, zero warnings about unresolved refs or missing markdown.

- [ ] **Step 2: Status check**

```bash
git status
git log --oneline master..HEAD | head -30
```

Confirm `feat/vgc-migration` is ahead of `master` and docs changes are committed (ask user to commit if still dirty).

- [ ] **Step 3: Push and open PR to `master`**

```bash
git push -u origin HEAD
gh pr create --base master --title "..." --body "$(cat <<'EOF'
## Summary
- ...

## Test plan
- [ ] `dart doc .` clean
- [ ] `dart test`
- [ ] CLI smoke on a stroked icon

EOF
)"
```

Title/body should cover the whole branch (vgc migration + restoration fixes + dartdoc), not only Task 1–3.

- [ ] **Step 4: Delete `fix/restore-font-generation`**

```bash
git branch -d fix/restore-font-generation
git push origin --delete fix/restore-font-generation 2>/dev/null || true
```

Only if it exists remotely; local delete is enough if never pushed.

---

## Spec coverage (self-review)

| Spec item | Task |
|---|---|
| `dartdoc_options.yaml` + 5 categories | 1 |
| Guides for each category | 1 |
| No figma-export category | 1 (omitted) |
| `{@category api}` on listed symbols | 2 |
| README slim + drop figma links | 3 |
| `dart doc` zero warnings | 2, 3, 4 |
| PR to master | 4 |
| Delete fix branch | 4 |

No placeholders. Symbol names match current exports.
