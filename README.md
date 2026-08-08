# fontify_plus

[![pub package](https://img.shields.io/pub/v/fontify_plus.svg)](https://pub.dartlang.org/packages/fontify_plus)

The fontify_plus package provides an easy way to convert SVG icons to OpenType font
and generate Flutter-compatible class that contains identifiers for the icons
(just like [CupertinoIcons][] or [Icons][] classes).

The package is written fully in Dart and doesn't require any external dependency.
Compatible with dart2js and dart2native.

Outline-style icon sets — the kind Figma, Hugeicons, Lucide and Feather export —
are drawn with strokes rather than fills. Font glyphs are fill-only, so
fontify_plus converts each stroke into the region it covers before encoding it.
That happens by default; see [Stroked icons](#stroked-icons).

[CupertinoIcons]: https://api.flutter.dev/flutter/cupertino/CupertinoIcons-class.html
[Icons]: https://api.flutter.dev/flutter/material/Icons-class.html

## Using CLI tool

[Globally activate][] the package:

[globally activate]: https://dart.dev/tools/pub/cmd/pub-global

```sh
pub global activate fontify_plus
```

And it's ready to go:

```sh
fontify_plus <input-svg-dir> <output-font-file> [options]
```

Required positional arguments:

- `<input-svg-dir>`
Path to the input directory that contains .svg files.
- `<output-font-file>`
Path to the output font file. Should have .otf extension.

Flutter class options:

- `-o` or `--output-class-file=<path>`
Output path for Flutter-compatible class that contains identifiers for the icons.
- `-i` or `--indent=<indent>`
Number of spaces in leading indentation for Flutter class file.
  (defaults to "2")
- `-c` or `--class-name=<name>`
Name for a generated class.
- `-p` or `--package=<name>`
Name of a package that provides a font. Used to provide a font through package dependency.

Font options:

- `-f` or `--font-name=<name>`
Name for a generated font.
- `--[no-]normalize`
Scales each glyph so its own longest side fills the em square.
Only for icons collected from mismatched sources — see [Glyph sizing](#glyph-sizing).
(defaults to off)

Other options:

- `-z` or `--config-file=<path>`
Path to fontify_plus yaml configuration file.
pubspec.yaml and fontify_plus.yaml files are used by default.
- `-r` or `--recursive`
Recursively look for .svg files.
- `-v` or `--verbose`
Display every logging message.
- `-h` or `--help`
Shows usage information.

*Usage example:*

```sh
fontify_plus assets/svg/ fonts/my_icons_font.otf --output-class-file=lib/my_icons.dart --indent=4 -r
```

Updated Flutter project's pubspec.yaml:

```yaml
...

flutter:
  fonts:
    - family: fontify_plus Icons
      fonts:
        - asset: fonts/my_icons_font.otf
```

## CLI tool config file

fontify_plus's configuration can also be placed in yaml file.
Add *fontify_plus* section to either `pubspec.yaml` or `fontify_plus.yaml` file:

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

`input_svg_dir` and `output_font_file` keys are required.
It's possible to specify any other config file by using `--config-file` option.

## Using API

[svgToOtf][] and [generateFlutterClass][] functions can be used for generating font and Flutter class.

The example of API usage is located in [example folder][].

[example folder]: https://github.com/4akloon/fontify_plus/tree/master/example/example.dart
[svgToOtf]: https://pub.dev/documentation/fontify_plus/latest/fontify_plus/svgToOtf.html
[generateFlutterClass]: https://pub.dev/documentation/fontify_plus/latest/fontify_plus/generateFlutterClass.html

## Stroked icons

A font glyph is a filled region — the format has no concept of stroke width,
caps or joins. An SVG like this describes the *centreline* of a stroke, an
infinitely thin path enclosing zero area:

```svg
<svg viewBox="0 0 16 16" fill="none">
  <path d="M8 2.66667V13.3333M13.3333 8H2.66666"
        stroke="currentColor" stroke-width="1.33" stroke-linecap="round" />
</svg>
```

Filled as-is it is invisible, which is why outline-style icons come out blank or
hairline thin in naive converters.

fontify_plus computes the area the stroke covers and fills that instead,
honouring `stroke-width`, `stroke-linecap`, `stroke-linejoin`,
`stroke-miterlimit` and `stroke-dasharray`, including values inherited from an
ancestor `<g>`. A dashed stroke is cut into its dashes and each dash is
outlined separately. No preparation is needed — export from Figma and convert.

`stroke-dashoffset` is parsed but has no effect: `vector_graphics_compiler`
drops it before fontify_plus sees the path, so the dash pattern always starts
at the beginning of the path regardless of the value. See
[doc/figma-export.md](doc/figma-export.md) for this and other limitations.

Pass `--no-outline-strokes` to disable it and treat path data as fill geometry,
as older versions did.

For export settings, troubleshooting and the cases that need outlining in Figma
first, see [doc/figma-export.md](doc/figma-export.md).

## Glyph sizing

By default an icon's artboard maps straight onto the em square. An icon drawn to
fill its 16x16 viewBox fills the em; one drawn at half that size fills half of
it. `Icon(MyIcons.thing, size: 24)` then covers the same area the SVG does at
24 logical pixels, so the font is a drop-in replacement for the SVG.

`--normalize` instead scales each glyph individually until its own longest side
fills the em square, and centres it. That discards how much of its artboard the
icon was drawn to occupy — which is design information. A full-bleed circle gets
shrunk and a small arrow gets blown up until they match, so the arrow can end up
larger than the circle even though the artwork says otherwise.

Use it only when the icons come from mismatched sources whose viewBoxes disagree
and a uniform size is the lesser evil. For a set exported from one design file,
leave it off.

## Notes

- Generated OpenType font is using CFF table.
- Generated font is using PostScript Table (post) of version 3.0, i.e., it doesn't contain glyph names.
- Supported SVG elements: path, g, circle, ellipse, rect, polyline, polygon,
line, use, defs, symbol.
- SVG transforms are applied to paths according to specs.
- SVG `<g>` element's children are expanded to the root with transformations applied.
`<use>` referencing a `<defs>` or `<symbol>` element is supported and expands the
same way.
- Consider using [Non-zero fill rule][].
- Shapes (circle, rect, etc.) are always converted to paths.
- Paint attributes other than stroke geometry — `fill` colour, gradients,
opacity — are ignored. A glyph is a single-colour region; colour comes from the
surrounding text style at render time.
- `normalize` expects every icon to share a viewBox when it is off, which is the
usual case for an icon set. See [Glyph sizing](#glyph-sizing).
- When Flutter class is generated, static variable names derive from the SVG
file name converted to lowerCamelCase (Dart's convention for constants) with
non-allowed characters removed.
Name is set to 'unnamed', if it's empty.
Suffix '_{i+1}' is added, if name already exists.

[Non-zero fill rule]: https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/fill-rule

## Planned

- Support svg-to-ttf conversion (cubic-to-quad curves approximation needs to be
done). The CFF/OTF output path is the supported one today.
- Support ligatures.
- Support font variations.

## Contributing

Any suggestions, issues, pull requests are welcomed. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to get set up and what a change is
expected to look like.

## License

[MIT](https://github.com/4akloon/fontify_plus/blob/master/LICENSE)
