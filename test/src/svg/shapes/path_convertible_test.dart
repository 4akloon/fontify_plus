import 'package:fontify_plus/src/svg/shapes/path_convertible.dart';
import 'package:fontify_plus/src/svg/shapes/rect_element.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('PathConvertible', () {
    test('every shape element implements it', () {
      final element = RectElement.fromXmlElement(
        null,
        XmlDocument.parse('<rect width="1" height="1"/>').rootElement,
      );

      expect(element, isA<PathConvertible>());
    });
  });
}
