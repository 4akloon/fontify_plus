# API Usage

The API mirrors the CLI pipeline: convert SVG strings to a font, write the font
file, then generate a Flutter `IconData` class.

## Job API

For directory-based workflows (same I/O as the CLI), use `FontJob` and
`runFontJob`:

```dart
runFontJob(FontJob(
  inputSvgDir: 'assets/svg',
  outputFontFile: 'fonts/my_icons.otf',
  outputClassFile: 'lib/my_icons.dart',
  className: 'MyIcons',
));
```

Parse a multi-font yaml config:

```dart
final config = parseFontifyConfig(await File('fontify_plus.yaml').readAsString());
final jobs = config.resolve(fontFilter: 'icons');
runFontJobs(jobs);
```

`runFontJob` / `runFontJobs` require `dart:io`. On web, use the low-level
pipeline below with in-memory SVG strings.

## Low-level pipeline

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

Write `source` to a `.dart` file with `dart:io` (or your preferred file API).

## `svgToOtf`

Converts a map of SVG strings into an OpenType font.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `svgMap` | `Map<String, String>` | *(required)* | Glyph name to SVG source. Keys become glyph identifiers. |
| `outlineStrokes` | `bool?` | `true` | Convert stroked paths into the filled region the stroke covers. |
| `normalize` | `bool?` | `true` | Scale each glyph so its longest side fills the em square, then centre it. |
| `useOpenType` | `bool?` | `true` | Emit CFF (OpenType) outlines. When `false`, TrueType outlines are generated with cubic-to-quadratic approximation. |
| `fontName` | `String?` | `null` | PostScript / family name for the generated font. |
| `strokeWidthRange` | `StrokeWidthRange?` | `null` | Build a variable font whose `wght` axis is the stroke width (`min` and `max` in SVG units). Omit for a static font. See [Variable stroke width](variable_stroke.md). |

Returns a `SvgToOtfResult` containing:

- `glyphList` — `List<GenericGlyph>` of parsed glyphs (pass to `generateFlutterClass`).
- `font` — `OpenTypeFont` instance (pass to `writeToFile`).

## `generateFlutterClass`

Emits Dart source for a class of `IconData` constants.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `glyphList` | `List<GenericGlyph>` | *(required)* | Glyphs from `svgToOtf`. |
| `className` | `String?` | `null` | Generated class name (PascalCase recommended). |
| `familyName` | `String?` | `null` | Font family name used in each `IconData`. |
| `package` | `String?` | `null` | Package name when the font is provided through a dependency. |
| `fontFileName` | `String?` | `null` | Font file name referenced in generated docs. |
| `indent` | `int?` | `2` | Leading spaces for class members. |
| `strokeWidthRange` | `StrokeWidthRange?` | `null` | When set, documents the variable `wght` axis in the class comment. |

Returns the class file contents as a `String`.

## `writeToFile` / `readFromFile`

`writeToFile(String path, OpenTypeFont font)` serialises an `OpenTypeFont` to
disk. Use a `.otf` extension for CFF-based fonts.

`readFromFile(String path)` reads an OpenType font back from disk. Both require
`dart:io` and are unavailable on web targets.

## Paint attributes

Paint attributes other than stroke geometry — `fill` colour, gradients, opacity
— are ignored. A glyph is a single-colour region; colour comes from the
surrounding Flutter text style at render time.
