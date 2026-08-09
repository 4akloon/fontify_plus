# CLI & Config

The `fontify_plus` command converts SVG directories into OpenType fonts and
optionally generates Flutter `IconData` classes.

## Ad-hoc run

```sh
fontify_plus assets/svg/ fonts/my_icons_font.otf \
  --output-class-file=lib/my_icons.dart --indent=4 -r
```

| Argument / flag | Description |
|-----------------|-------------|
| `<input-svg-dir>` | Directory containing `.svg` icon files. |
| `<output-font-file>` | Output path for the font. Use a `.otf` extension. |
| `-o`, `--output-class-file=<path>` | Output path for the generated Dart class. |
| `-i`, `--indent=<n>` | Spaces for class member indentation (default `2`). |
| `-c`, `--class-name=<name>` | Name of the generated class. |
| `-p`, `--package=<name>` | Package that provides the font (for `IconData` package parameter). |
| `-f`, `--font-name=<name>` | PostScript / family name for the generated font. |
| `--[no-]normalize` | Scale each glyph so its longest side fills the em square (default on). |
| `--[no-]outline-strokes` | Convert stroked paths to filled regions (default on). |
| `--[no-]preview` | Embed SVG previews in generated IconData dartdoc (default on). |
| `--[no-]opentype` | Emit CFF outlines (default on). |
| `-r`, `--[no-]recursive` | Recursively search for `.svg` files (default off). Icon names are derived from each file's path relative to the input directory (e.g. `icons/nav/arrow.svg` → `iconsNavArrow`). An empty SVG directory fails the job. Use `--no-recursive` to override YAML `recursive: true`. |
| `-v`, `--[no-]verbose` | Print every log message (default off). Use `--no-verbose` to override YAML `verbose: true`. |
| `-z`, `--config-file=<path>` | Path to a yaml config file (`pubspec.yaml` and `fontify_plus.yaml` are checked by default). |
| `--font=<name>` | Run one named font set from the config (omit to run all sets). |
| `--watch` | After the first generate, watch SVG input dirs and the config file (if any). SVG changes regenerate matching font set(s) after a 250ms debounce; config changes re-parse and regenerate all selected sets immediately. Errors while watching are logged; the process keeps listening until Ctrl+C. |
| `-h`, `--help` | Show usage information. |

Ad-hoc positionals and a config file with `fontify_plus.fonts` cannot be used
together.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (including `--help`). |
| `64` | Usage / CLI argument error. |
| `65` | Runtime failure while generating. |
| `66` | YAML config parse error. |

## Multi-font yaml configuration

Add a `fontify_plus:` section with shared `defaults` and named `fonts` to
`pubspec.yaml` or `fontify_plus.yaml`:

```yaml
fontify_plus:
  defaults:
    recursive: true
    normalize: true
  fonts:
    icons:
      input_svg_dir: assets/icons/
      output_font_file: fonts/icons.otf
      output_class_file: lib/icons.dart
      class_name: AppIcons
    brand:
      input_svg_dir: assets/brand/
      output_font_file: fonts/brand.otf
```

`input_svg_dir` and `output_font_file` are required per font set. CLI flags
merge on top of `defaults` and per-font values (only flags you pass override).

```sh
fontify_plus                  # all sets
fontify_plus --font=icons     # one set
fontify_plus --no-normalize   # keep artboard-relative sizes for every set
```

## Example

```sh
fontify_plus assets/svg/ fonts/my_icons_font.otf \
  --output-class-file=lib/my_icons.dart --indent=4 -r
```

## Watch mode

```sh
fontify_plus --font=icons --watch
fontify_plus assets/svg/ fonts/my_icons_font.otf -o lib/my_icons.dart --watch
```
