import 'package:fontify_plus/src/svg/svg_preview.dart';
import 'package:test/test.dart';

void main() {
  group('minifySvgPreview', () {
    test('strips declaration, doctype, comments, and metadata elements', () {
      const svg = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg>
<!-- exporter note -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <title>arrow</title>
  <desc>An arrow.</desc>
  <metadata>meta</metadata>
  <path d="M5 12h14"/>
</svg>
''';

      expect(
        minifySvgPreview(svg),
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' "
        "fill='none' width='32' height='32'><path d='M5 12h14'/></svg>",
      );
    });

    test('synthesizes a viewBox from author width/height before resizing', () {
      const svg =
          '<svg width="24px" height="16" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M5 12h14"/></svg>';

      expect(
        minifySvgPreview(svg),
        "<svg width='32' height='32' xmlns='http://www.w3.org/2000/svg' "
        "viewBox='0 0 24 16' fill='grey'><path d='M5 12h14'/></svg>",
      );
    });

    test('leaves sizing alone without a viewBox or usable dimensions', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%">'
          '<path d="M5 12h14"/></svg>';

      expect(
        minifySvgPreview(svg),
        "<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='100%' "
        "fill='grey'><path d='M5 12h14'/></svg>",
      );
    });

    test(
      'swaps every black fill/stroke form for grey, keeps other colors',
      () {
        const svg =
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
            'fill="BLACK">'
            '<path stroke="#000" fill="#000000" d="M0 0h24"/>'
            '<path stroke="currentColor" fill="#111" d="M0 0v24"/></svg>';

        expect(
          minifySvgPreview(svg),
          "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' "
          "fill='grey' width='32' height='32'>"
          "<path stroke='grey' fill='grey' d='M0 0h24'/>"
          "<path stroke='grey' fill='#111' d='M0 0v24'/></svg>",
        );
      },
    );

    test('adds a grey root fill when the root has none', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8">'
          '<path d="M0 0h8"/></svg>';

      expect(
        minifySvgPreview(svg),
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 8 8' "
        "width='32' height='32' fill='grey'><path d='M0 0h8'/></svg>",
      );
    });

    test('keeps defs, gradients, and style content untouched', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8">'
          '<defs><linearGradient id="g">'
          '<stop offset="0" stop-color="#f00"/></linearGradient></defs>'
          '<style>.a{fill:black}</style>'
          '<path class="a" d="M0 0h8"/></svg>';

      final minified = minifySvgPreview(svg);

      expect(minified, contains('<defs>'));
      expect(minified, contains("stop-color='#f00'"));
      expect(minified, contains('.a{fill:black}'));
    });

    test('escapes embedded single quotes in attribute values', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8" '
          'aria-label="it\'s"/>';

      expect(minifySvgPreview(svg), contains("aria-label='it&apos;s'"));
    });
  });
}
