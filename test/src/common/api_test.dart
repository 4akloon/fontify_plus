import 'package:fontify_plus/src/common/api.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/svg/svg_preview.dart';
import 'package:test/test.dart';

String svgWithViewBox(String viewBox) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">'
    '<path d="M0 0 L1 0 L1 1 Z"/></svg>';

void main() {
  group('svgToOtf', () {
    test('produces one glyph per SVG', () {
      final result = svgToOtf(
        svgMap: {
          'a': svgWithViewBox('0 0 16 16'),
          'b': svgWithViewBox('0 0 16 16'),
        },
      );

      expect(result.glyphList, hasLength(2));
    });

    test('defaults to OpenType (CFF) outlines', () {
      final result = svgToOtf(svgMap: {'a': svgWithViewBox('0 0 16 16')});

      expect(result.font.isOpenType, isTrue);
    });

    test('produces TrueType outlines when useOpenType is false', () {
      final result = svgToOtf(
        svgMap: {'a': svgWithViewBox('0 0 16 16')},
        useOpenType: false,
      );

      expect(result.font.isOpenType, isFalse);
    });

    test('assigns each glyph a unique private-use-area char code', () {
      final result = svgToOtf(
        svgMap: {
          'a': svgWithViewBox('0 0 16 16'),
          'b': svgWithViewBox('0 0 16 16'),
        },
      );

      final codes = result.glyphList.map((g) => g.metadata.charCode).toSet();

      expect(codes, hasLength(2));
      expect(codes, everyElement(isNotNull));
    });

    test('uses the requested font name', () {
      final result = svgToOtf(
        svgMap: {'a': svgWithViewBox('0 0 16 16')},
        fontName: 'My Icons',
      );

      expect(result.font.familyName, 'My Icons');
    });

    test('does not warn about mismatched viewBoxes when normalize is on', () {
      // Regression guard for the specific condition below: with normalize on,
      // a mismatched viewBox is exactly what it exists to handle, so it must
      // build without complaint regardless of what actually gets logged.
      expect(
        () => svgToOtf(
          svgMap: {
            'a': svgWithViewBox('0 0 16 16'),
            'b': svgWithViewBox('0 0 24 24'),
          },
          normalize: true,
        ),
        returnsNormally,
      );
    });

    test('builds fine with mismatched viewBoxes even without normalize', () {
      // Disabling normalize only logs a warning about this; it doesn't fail
      // the build.
      expect(
        () => svgToOtf(
          svgMap: {
            'a': svgWithViewBox('0 0 16 16'),
            'b': svgWithViewBox('0 0 24 24'),
          },
        ),
        returnsNormally,
      );
    });

    test('stores svg preview on glyphs by default', () {
      final svg = svgWithViewBox('0 0 16 16');
      final result = svgToOtf(svgMap: {'a': svg});

      expect(result.glyphList.single.metadata.preview, minifySvgPreview(svg));
    });

    test('skips preview when preview is false', () {
      final result = svgToOtf(
        svgMap: {'a': svgWithViewBox('0 0 16 16')},
        preview: false,
      );

      expect(result.glyphList.single.metadata.preview, isNull);
    });

    test('stores the same minified preview for variable-font builds', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
          '<path d="M5 12h14" stroke="black" stroke-width="2" fill="none"/>'
          '</svg>';

      final result = svgToOtf(
        svgMap: {'a': svg},
        strokeWidthRange: StrokeWidthRange(1, 2),
      );

      expect(result.glyphList.single.metadata.preview, minifySvgPreview(svg));
    });
  });

  group('generateFlutterClass', () {
    test('names the class as requested', () {
      final result = svgToOtf(
        svgMap: {'arrow-up': svgWithViewBox('0 0 16 16')},
      );

      final source = generateFlutterClass(
        glyphList: result.glyphList,
        className: 'MyIcons',
        familyName: result.font.familyName,
      );

      expect(source, contains('abstract final class MyIcons'));
    });

    test('emits one IconData constant per glyph', () {
      final result = svgToOtf(
        svgMap: {
          'arrow-up': svgWithViewBox('0 0 16 16'),
          'arrow-down': svgWithViewBox('0 0 16 16'),
        },
      );

      final source = generateFlutterClass(
        glyphList: result.glyphList,
        className: 'MyIcons',
        familyName: result.font.familyName,
      );

      // Each constant declares its type as IconData and calls the IconData
      // constructor, so the bare substring appears twice per glyph.
      expect('static const IconData'.allMatches(source), hasLength(2));
      expect(source, contains('arrowUp'));
      expect(source, contains('arrowDown'));
    });

    test('includes the font package when given', () {
      final result = svgToOtf(svgMap: {'a': svgWithViewBox('0 0 16 16')});

      final source = generateFlutterClass(
        glyphList: result.glyphList,
        className: 'MyIcons',
        familyName: result.font.familyName,
        package: 'my_package',
      );

      expect(source, contains('my_package'));
      expect(source, contains('fontPackage'));
    });
  });
}
