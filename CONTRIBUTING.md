# Contributing to fontify_plus

Thanks for helping out. This document covers how to get the project running,
how it is laid out, and what a change is expected to look like before it lands.

## Contents

- [Prerequisites](#prerequisites)
- [Getting the code](#getting-the-code)
- [Repository layout](#repository-layout)
- [Everyday commands](#everyday-commands)
- [Architecture at a glance](#architecture-at-a-glance)
- [Coding conventions](#coding-conventions)
- [Tests](#tests)
- [Commits & pull requests](#commits--pull-requests)
- [Releasing](#releasing)

## Prerequisites

- Dart SDK 3.11 or newer. CI runs the matrix `3.11` and `stable`, so a change must
  work on both.

No Flutter SDK is needed. The package generates a Flutter-compatible class, but
it is pure Dart and never imports Flutter.

## Getting the code

```bash
git clone https://github.com/4akloon/fontify_plus.git
cd fontify_plus
dart pub get
dart test
```

## Repository layout

```
bin/            CLI entry point
lib/src/cli/    Argument parsing, config files, option formatting
lib/src/svg/    SVG parsing: elements, shapes, stroke outlining, path to outline
lib/src/otf/    OpenType: tables, CFF charstrings, reader and writer
lib/src/common/ Format-independent glyph model shared by SVG and OTF
lib/src/utils/  Flutter class generation and assorted helpers
test/           Unit tests plus the end-to-end font write test
```

## Everyday commands

```bash
# Analyze. CI uses --fatal-infos, so treat infos as errors locally too.
dart analyze --fatal-infos

# Test everything.
dart test

# Test one file.
dart test test/stroke_test.dart

# Format. The formatter owns trailing commas; do not hand-place them.
dart format .

# Convert a directory of icons end to end.
dart run bin/fontify_plus.dart <svg-dir> <output.otf> -o lib/icons.dart -c MyIcons
```

## Architecture at a glance

Conversion runs as a pipeline, and each stage has one job:

1. **Parse** (`lib/src/svg/`) — `vector_graphics_compiler` parses the SVG and
   flattens it to draw commands; `svg_parser.dart` walks those commands into
   `SvgShape`s, dropping masked, clipped and invisible geometry along the way.
   `outline_builder.dart` turns a shape's path commands into `Outline`s, and for
   a stroked path, `lib/src/svg/stroke/` first converts the stroke into the
   closed contours of the region it covers, which `outline_builder.dart` then
   turns into `Outline`s the same way.
2. **Outline** (`lib/src/common/generic_glyph.dart`) — paths become `Outline`s in
   a format-independent glyph model, with the Y axis flipped into font space.
3. **Normalize** — glyphs are scaled and centred onto the em square.
4. **Encode** (`lib/src/otf/`) — glyphs become CFF charstrings and the surrounding
   OpenType tables, then bytes.

Two properties of the format drive most of the design and are easy to forget:

- **Glyphs are fill-only.** There is no stroke in a font. A stroked SVG path has
  to be converted into the area it covers first, or it collapses to a zero-area
  centreline and renders blank. That is what
  `lib/src/svg/stroke/stroke_outliner.dart` does.
- **CFF fills by the nonzero winding rule.** Overlapping contours wound the same
  way merge; contours wound opposite cut holes. The stroke outliner leans on this
  instead of running a boolean union, so contour orientation is load-bearing.

## Coding conventions

- Follow the analyzer. `analysis_options.yaml` is the source of truth.
- Prefer explaining *why* in comments. The mechanics are usually readable from
  the code; the constraint that forced the approach usually is not.
- Keep files focused. If one starts doing two jobs, split it.
- Public API needs dartdoc. `type_annotate_public_apis` is enabled.

## Tests

- Every bug fix gets a test that fails without the fix. Verify that it does —
  reintroduce the bug, watch the test go red, then restore.
- Geometry is tested by measurable properties (enclosed area, contour count,
  winding direction), not by golden coordinate dumps. Coordinates change
  whenever the flattening tolerance changes; area does not.
- `test/e2e_test.dart` writes a real font and parses the bytes back. Anything
  touching the OTF writer must keep it green — the suite once passed 35 tests
  while the package could not produce a font at all, because nothing exercised
  the full write path.

## Commits & pull requests

- Keep the subject line imperative and specific: *Fix stale CFF INDEX cache*,
  not *bug fixes*.
- One logical change per PR.
- CI must be green: format, analyze on 3.11 and stable, tests, and publish
  dry-run.
- Update `CHANGELOG.md` for anything user-visible, including changed defaults.

## Releasing

Publishing is automated. Bump `version:` in `pubspec.yaml`, update
`CHANGELOG.md`, then push a matching tag:

```bash
git tag v0.5.0
git push origin v0.5.0
```

The `Publish` workflow verifies that the tag matches the pubspec version and
publishes via pub.dev's OIDC flow. No tokens are stored in the repository.
