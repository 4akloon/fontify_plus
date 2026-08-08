import 'package:fontify_plus/src/svg/unknown_element.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('UnknownElement', () {
    test('wraps an XmlElement without interpreting it', () {
      final xml = XmlDocument.parse('<defs/>').rootElement;
      final element = UnknownElement(null, xml);

      expect(element.xmlElement, xml);
      expect(element.parent, isNull);
    });
  });
}
