# AGENTS.md

Instructions for coding agents working in **fontify_plus**. Human setup and deeper architecture live in [CONTRIBUTING.md](CONTRIBUTING.md) — prefer linking there over copying.

## Project

Pure Dart CLI/API: SVG icons → OTF font + Flutter `IconData` class. Stroke outlining is on by default (fonts are fill-only). No Flutter SDK required for the package itself; `example/` is a Flutter app.

Default branch: `master`. SDK floor: Dart `^3.11.0`.

## Commands

```bash
dart pub get
dart analyze --fatal-infos   # CI treats infos as errors
dart format .
dart test                    # full suite; keep green
dart test path/to/test.dart  # focused
dart run bin/fontify_plus.dart <svg-dir> <out.otf> -o lib/icons.dart -c MyIcons
```

Do not hand-place trailing commas — `dart format` owns them.

## Layout (where to edit)

| Path | Role |
|------|------|
| `bin/` | CLI entry |
| `lib/src/cli/` | args, YAML config, watch loop |
| `lib/src/job/` | `FontJob`, config parse, `runFontJob` |
| `lib/src/svg/` | SVG → outlines (incl. stroke outlining) |
| `lib/src/otf/` | OpenType tables / CFF / IO |
| `lib/src/common/` | shared glyph model; public API surface |
| `lib/src/utils/` | Flutter class gen, helpers |
| `test/` | unit + integration; e2e must stay green if OTF writer changes |
| `doc/` | user docs (cli, api, glyph sizing, …) |
| `docs/superpowers/` | local design/plans — **do not commit** unless asked |
| `example/` | sample SVG → font + Flutter app |

## Architecture constraints (easy to break)

1. **Glyphs are fill-only** — stroked SVGs must be outlined (`lib/src/svg/stroke/`) or they render blank.
2. **CFF uses nonzero winding** — contour orientation matters; outliner relies on this instead of boolean union.
3. Pipeline: parse SVG → `Outline`s / `GenericGlyph` → fit/normalize → OTF encode → optional Flutter class.
4. Job API = CLI: prefer changing `runFontJob` / shared helpers once over patching CLI-only paths.

## Conventions

- Analyzer/`analysis_options.yaml` is truth. Public APIs need dartdoc.
- Comments explain *why* / constraints, not what the code already says.
- Smallest correct diff. Reuse existing helpers; no new deps without need.
- User-visible behaviour → update `CHANGELOG.md` (`Unreleased` or the release section).
- Bug fix → test that fails without the fix. Prefer measurable geometry (area, contour count, winding) over golden coordinates.
- Prefer deterministic outputs where possible (e.g. reuse existing OTF `head` timestamps when regenerating).

## GitHub remotes and PRs

| Remote | Repo | Use |
|--------|------|-----|
| `origin` | `4akloon/fontify_plus` | **default** — push + open PRs here |
| `upstream` | `westracer/fontify` | fork parent only |

When opening a PR:

1. `git push -u origin HEAD`
2. Always pass the repo explicitly (bare `gh` may default to upstream):

```bash
gh pr create --repo 4akloon/fontify_plus --base master ...
```

3. Do **not** open PRs on `westracer/fontify` unless the user explicitly asks.

## Commits and releases

- Imperative, specific subjects (*Fix stale CFF INDEX cache*).
- One logical change per PR; CI must be green.
- Release: bump `pubspec.yaml` `version:`, write `CHANGELOG.md`, then:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

Publish workflow verifies tag ↔ pubspec and publishes via OIDC. See [CONTRIBUTING.md](CONTRIBUTING.md#releasing).

## Do / don't

| Do | Don't |
|----|--------|
| Read the real call path before editing | Guess SVG/OTF behaviour from memory |
| Run focused tests, then `dart test` before claiming done | Skip e2e after writer/table changes |
| Ask before committing `docs/superpowers/**` | Commit design/plan scratch by default |
| Keep example artifacts in sync if defaults change codegen | Leave example fonts stale after intentional regen |

## Cursor Cloud specific instructions

Prefer the **Flutter SDK** (ships Dart) over a standalone Dart install — `example/` is a Flutter app, and agents should be able to run it and Flutter-facing checks. Package unit/integration tests under `test/` are still plain `dart test` and do not need the Flutter framework.

Standard commands: [CONTRIBUTING.md](CONTRIBUTING.md) / Commands above. Cloud gotchas:

- Use Flutter’s `dart`/`flutter` on `PATH` (typically `/opt/flutter/bin`). CI-style package-only deps: `dart pub get --no-example`. With Flutter present, root `dart pub get` also resolves `example/`.
- Example app: `cd example && dart run tool/generate.dart` then `flutter run -d chrome`. Chrome is the supported device here (web); Android/Linux desktop toolchains are optional and not required for this repo.
- Regenerating the example updates committed `example/fonts/` and `example/lib/my_icons.dart` — only commit those when the change is intentional.
- `dart analyze --fatal-infos` matches CI; format is pinned on stable (`dart format --output=none --set-exit-if-changed bin lib test`).
