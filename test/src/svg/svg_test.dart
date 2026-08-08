import 'package:fontify_plus/src/svg/path.dart';
import 'package:fontify_plus/src/svg/shapes.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _kMinimalSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path d="M0 0 L1 1"/>
</svg>
''';

void main() {
  group('Svg.parse — viewBox', () {
    test('reads all four values', () {
      final svg = Svg.parse(
        'icon',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="1 2 24 32">'
            '<path d="M0 0"/></svg>',
      );

      expect(svg.viewBox.left, 1);
      expect(svg.viewBox.top, 2);
      expect(svg.viewBox.width, 24);
      expect(svg.viewBox.height, 32);
    });

    test('left-pads a partial viewBox with zeros', () {
      // SVG treats an abbreviated viewBox attribute list as zero-filled from
      // the front, the same way it treats an abbreviated points list.
      final svg = Svg.parse(
        'icon',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="16 16">'
            '<path d="M0 0"/></svg>',
      );

      expect(svg.viewBox.left, 0);
      expect(svg.viewBox.top, 0);
      expect(svg.viewBox.width, 16);
      expect(svg.viewBox.height, 16);
    });

    test('accepts commas as separators', () {
      final svg = Svg.parse(
        'icon',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0,0,24,24">'
            '<path d="M0 0"/></svg>',
      );

      expect(svg.viewBox.width, 24);
    });

    test('throws when viewBox is missing', () {
      expect(
        () => Svg.parse(
          'icon',
          '<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg>',
        ),
        throwsA(isA<SvgParserException>()),
      );
    });

    test('throws when viewBox has more than four numbers', () {
      expect(
        () => Svg.parse(
          'icon',
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 0 0 0">'
              '<path d="M0 0"/></svg>',
        ),
        throwsA(isA<SvgParserException>()),
      );
    });
  });

  group('Svg.parse — root validation', () {
    test('throws when the root element is not <svg>', () {
      expect(
        () => Svg.parse('icon', '<g><path d="M0 0"/></g>'),
        throwsA(isA<SvgParserException>()),
      );
    });

    test('throws on malformed XML', () {
      expect(
        () => Svg.parse('icon', '<svg><path d="M0 0"'),
        throwsA(isA<XmlParserException>()),
      );
    });
  });

  group('Svg.parse — identity', () {
    test('keeps the name it was given', () {
      final svg = Svg.parse('my-icon', _kMinimalSvg);

      expect(svg.name, 'my-icon');
    });

    test('toString reports the name and element count', () {
      final svg = Svg.parse('my-icon', _kMinimalSvg);

      expect(svg.toString(), contains('my-icon'));
      expect(svg.toString(), contains('1'));
    });
  });

  group('Svg.parse — ignoreShapes', () {
    const withShape = '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 10 10"><rect width="5" height="5"/></svg>';

    test('converts shapes to paths by default', () {
      final svg = Svg.parse('icon', withShape);

      expect(svg.elementList.single, isA<PathElement>());
    });

    test('leaves shapes unconverted when true', () {
      final svg = Svg.parse('icon', withShape, ignoreShapes: true);

      expect(svg.elementList.single, isA<RectElement>());
    });
  });

  group('Svg.parse — groups', () {
    test('flattens a group into its children', () {
      final svg = Svg.parse(
        'icon',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
            '<g><path d="M0 0"/><path d="M1 1"/></g></svg>',
      );

      expect(svg.elementList, hasLength(2));
      expect(svg.elementList, everyElement(isA<PathElement>()));
    });

    test("pushes a group's transform onto its children", () {
      final svg = Svg.parse(
        'icon',
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
            '<g transform="translate(5, 0)"><path d="M0 0"/></g></svg>',
      );

      expect(svg.elementList.single.transform, isNotNull);
    });
  });

  group('Svg.parse — outlineStrokes', () {
    const strokedPlus = '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 10 10"><path d="M5 0V10M0 5H10" stroke="#000" '
        'stroke-width="2" fill="none"/></svg>';

    test('outlines stroked paths by default', () {
      final svg = Svg.parse('icon', strokedPlus);
      final path = svg.elementList.whereType<PathElement>().single;

      // The centreline is untouched; an outlined stroke replaces it with the
      // filled region it covers, which is a closed contour.
      expect(path.data, isNot('M5 0V10M0 5H10'));
      expect(path.data, contains('Z'));
    });

    test('leaves the centreline alone when false', () {
      final svg = Svg.parse('icon', strokedPlus, outlineStrokes: false);
      final path = svg.elementList.whereType<PathElement>().single;

      expect(path.data, 'M5 0V10M0 5H10');
    });

    test('keeps an independent fill region alongside the outlined stroke', () {
      const filledAndStroked = '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 10 10"><path d="M0 0H10V10H0Z" fill="#000" '
          'stroke="#000" stroke-width="1"/></svg>';

      final svg = Svg.parse('icon', filledAndStroked);

      expect(svg.elementList, hasLength(2));
    });
  });
}
