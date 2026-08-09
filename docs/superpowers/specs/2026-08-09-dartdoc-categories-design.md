# Design: fontify_plus dartdoc categories (basalt-level)

Date: 2026-08-09  
Branch: `feat/vgc-migration`  
Base for PR: `master`  
Reference: `basalt_dart` package docs model (`dartdoc_options.yaml` + `doc/*.md` + `{@category}` + `///`)

## Goal

Bring `fontify_plus` API documentation to the same dartdoc structure used in
`basalt_dart`, so pub.dev shows topic guides beside the library API. Then open
the migration PR against `master` and drop the obsolete
`fix/restore-font-generation` branch (already an ancestor of HEAD).

## Scope

### In

- Root `dartdoc_options.yaml` with five categories.
- Example-driven guides under `doc/`.
- `{@category ...}` on intentional public entry points only.
- Tighten `///` summaries on those entry points where needed.
- `dart doc .` with zero warnings; generated `doc/api/` stays gitignored.
- Slim README: short landing + pointers into guides; remove dead links to
  `doc/figma-export.md`.
- After docs land: commit on `feat/vgc-migration`, push, open PR to `master`,
  delete `fix/restore-font-generation` locally and on remote if present.

### Out

- A `figma-export` category or guide (existing `doc/figma-export.md` is left for
  the author to delete separately; this work only removes references to it).
- Documenting OTF table internals, CFF layout, SVG parser internals.
- API refactors, new abstractions, or new dependencies.
- Changing default branch name; PR base remains `master`.

## Categories

| slug | displayName | markdown | Content |
|---|---|---|---|
| `getting-started` | Getting Started | `doc/getting_started.md` | Activate CLI; one API snippet (`svgToOtf` → `writeToFile` → `generateFlutterClass`); where to go next |
| `api` | API Usage | `doc/api.md` | `svgToOtf` / `generateFlutterClass` / `SvgToOtfResult` / `readFromFile` / `writeToFile` parameters and flow |
| `stroked-icons` | Stroked Icons | `doc/stroked_icons.md` | Fill-only glyphs; stroke outlining; `--no-outline-strokes`; known limits (no figma-export link) |
| `glyph-sizing` | Glyph Sizing | `doc/glyph_sizing.md` | Artboard→em default vs `--normalize` / `normalize: true` |
| `cli` | CLI & Config | `doc/cli.md` | Positional args, flags, yaml config keys |

`categoryOrder`: getting-started → api → stroked-icons → glyph-sizing → cli.  
`showUndocumentedCategories: true`.

**displayName rule (from basalt):** must not collide with the slug on
case-insensitive filesystems (e.g. slug `api` + displayName `API Usage`, not
`API`).

## Category tags

Every category must have ≥1 tagged member (dartdoc omits empty topics).
Multiple `{@category}` lines on one symbol are OK.

| Symbol | Categories |
|---|---|
| `lib/fontify_plus.dart` (library doc) | `getting-started`, `cli` |
| `svgToOtf` | `api`, `stroked-icons`, `glyph-sizing` |
| `generateFlutterClass` | `api` |
| `SvgToOtfResult` | `api` |
| `OpenTypeFont` | `api` |
| `writeToFile` | `api` |
| `readFromFile` | `api` |

`GenericGlyph`: leave untagged unless a guide needs it as a first-class entry;
advanced callers can still find it via the library export.

Everything else exported today (OTF tables, `FlutterClassGenerator`, exceptions,
outlines, etc.): keep or add a one-line `///` summary if missing; **no**
`{@category}`.

Library doc in `lib/fontify_plus.dart` stays as the package overview and carries
`{@category getting-started}` and `{@category cli}` so those topics render;
guides own the deep topics that today live as long README sections.

## Guide conventions (match basalt)

- Example-driven: short runnable snippets, not prose-only.
- In `doc/*.md`, reference symbols with `` `Symbol` `` code spans — not
  `[Symbol]` (dartdoc does not resolve bracket refs across packages/files).
- Inside Dart `///` comments in the same library, `[Symbol]` is fine.
- After changes: `dart doc .` from package root; fix warnings; never commit
  `doc/api/`.

## README

Keep: package pitch, stroked-icons one-liner, CLI one-liner, Notes, Planned,
Contributing, License.

Compress into short paragraphs + links to `doc/*.md` (and, after publish, the
corresponding pub.dev topic pages):

- Using CLI tool / CLI config → `doc/cli.md`
- Using API → `doc/api.md`
- Stroked icons → `doc/stroked_icons.md`
- Glyph sizing → `doc/glyph_sizing.md`

Remove links to `doc/figma-export.md`. Do not delete that file in this change.

## Verification

```sh
dart doc .
# expect: exit 0, no unresolved doc reference / category warnings
```

## Ship sequence

1. Implement `dartdoc_options.yaml`, guides, `{@category}`, README trim.
2. Commit on `feat/vgc-migration`.
3. Push and open PR targeting `master`.
4. Delete `fix/restore-font-generation` (local + remote if it exists).

## Non-goals reminder

No figma guide. No deep OTF docs. No API surface redesign.
