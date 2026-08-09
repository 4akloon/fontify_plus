# CLI & Config

The `fontify_plus` command converts a directory of SVG files into an OpenType
font and optionally generates a Flutter `IconData` class.

## Positional arguments

| Argument | Description |
|----------|-------------|
| `<input-svg-dir>` | Directory containing `.svg` icon files. |
| `<output-font-file>` | Output path for the font. Use a `.otf` extension. |

## Flutter class flags

| Flag | Description |
|------|-------------|
| `-o`, `--output-class-file=<path>` | Output path for the generated Dart class. |
| `-i`, `--indent=<n>` | Spaces for class member indentation (default `2`). |
| `-c`, `--class-name=<name>` | Name of the generated class. |
| `-p`, `--package=<name>` | Package that provides the font (for `IconData` package parameter). |

## Font flags

| Flag | Description |
|------|-------------|
| `-f`, `--font-name=<name>` | PostScript / family name for the generated font. |
| `--[no-]normalize` | Scale each glyph so its longest side fills the em square (default off). |
| `--[no-]outline-strokes` | Convert stroked paths to filled regions (default on). |

## Other flags

| Flag | Description |
|------|-------------|
| `-z`, `--config-file=<path>` | Path to a yaml config file (`pubspec.yaml` and `fontify_plus.yaml` are checked by default). |
| `-r`, `--recursive` | Recursively search for `.svg` files. |
| `-v`, `--verbose` | Print every log message. |
| `-h`, `--help` | Show usage information. |

## Yaml configuration

Add a `fontify_plus:` section to `pubspec.yaml` or `fontify_plus.yaml`:

```yaml
fontify_plus:
  input_svg_dir: "assets/svg/"
  output_font_file: "fonts/my_icons_font.otf"

  output_class_file: "lib/my_icons.dart"
  class_name: "MyIcons"
  indent: 4
  package: my_font_package

  font_name: "My Icons"
  normalize: false

  recursive: true
  verbose: false
```

`input_svg_dir` and `output_font_file` are required. Override the config file
location with `--config-file`.

## Example

```sh
fontify_plus assets/svg/ fonts/my_icons_font.otf \
  --output-class-file=lib/my_icons.dart --indent=4 -r
```
