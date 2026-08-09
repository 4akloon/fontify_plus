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

Low-level (in-memory SVG map):

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

Job API (reads SVG directories from disk, same as CLI):

```dart
runFontJob(FontJob(
  inputSvgDir: 'assets/svg',
  outputFontFile: 'fonts/my_icons.otf',
  outputClassFile: 'lib/my_icons.dart',
  className: 'MyIcons',
));
```

## Where to go next

- **API Usage** — parameters on `svgToOtf` and `generateFlutterClass`.
- **Stroked Icons** — why outline-style SVGs need stroke conversion.
- **Glyph Sizing** — artboard mapping vs `--normalize`.
- **CLI & Config** — flags and the yaml config file.
- **[example/](../example/)** — Flutter web app that regenerates icons with
  `dart run tool/generate.dart` and shows them in Chrome.
