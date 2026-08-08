import 'package:fontify_plus/src/utils/svg.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

void main() {
  group('getScalarAttribute', () {
    test('parses a present attribute', () {
      expect(parse('<r x="3.5"/>').getScalarAttribute('x'), 3.5);
    });

    test('defaults to zero when absent', () {
      expect(parse('<r/>').getScalarAttribute('x'), 0);
    });

    test('returns null when absent and zeroIfAbsent is false', () {
      expect(
        parse('<r/>').getScalarAttribute('x', zeroIfAbsent: false),
        isNull,
      );
    });

    test('reads from a given namespace', () {
      final element = parse('<r xmlns:a="urn:a" a:x="7"/>');

      expect(element.getScalarAttribute('x', namespace: 'urn:a'), 7);
    });
  });

  group('parseTransformMatrix', () {
    test('returns null with no transform attribute', () {
      expect(parse('<g/>').parseTransformMatrix(), isNull);
    });

    test('returns a matrix for a transform attribute', () {
      expect(
          parse('<g transform="scale(2)"/>').parseTransformMatrix(), isNotNull);
    });
  });

  group('parseSvgElements', () {
    test('parses every child element', () {
      final elements = parse('<g><path d="M0 0"/><path d="M1 1"/></g>')
          .parseSvgElements(null, false);

      expect(elements, hasLength(2));
    });

    test('ignores text nodes between elements', () {
      final elements =
          parse('<g>text<path d="M0 0"/></g>').parseSvgElements(null, false);

      expect(elements, hasLength(1));
    });

    test('drops elements of unknown type', () {
      final elements =
          parse('<g><defs/><path d="M0 0"/></g>').parseSvgElements(null, false);

      expect(elements, hasLength(1));
    });

    test('expands a nested group into its children', () {
      final elements =
          parse('<g><g><path d="M0 0"/></g></g>').parseSvgElements(null, false);

      expect(elements, hasLength(1));
    });
  });
}
