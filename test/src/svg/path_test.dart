import 'package:fontify_plus/src/svg/path.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

void main() {
  group('PathElement.fromXmlElement', () {
    test('reads the "d" attribute as path data', () {
      final element = parse('<path d="M0 0 L1 1"/>');
      final path = PathElement.fromXmlElement(null, element);

      expect(path.data, 'M0 0 L1 1');
    });

    test('reads an explicit fill-rule', () {
      final element = parse('<path d="M0 0" fill-rule="evenodd"/>');
      final path = PathElement.fromXmlElement(null, element);

      expect(path.fillRule, 'evenodd');
    });

    test('leaves fillRule null when unset', () {
      final element = parse('<path d="M0 0"/>');
      final path = PathElement.fromXmlElement(null, element);

      expect(path.fillRule, isNull);
    });

    test('throws when "d" is missing', () {
      final element = parse('<path/>');

      expect(
        () => PathElement.fromXmlElement(null, element),
        throwsA(isA<SvgParserException>()),
      );
    });

    test('keeps a reference to its parent', () {
      final element = parse('<path d="M0 0"/>');
      final parent = PathElement.fromXmlElement(null, element);
      final path = PathElement.fromXmlElement(parent, element);

      expect(path.parent, parent);
    });
  });
}
