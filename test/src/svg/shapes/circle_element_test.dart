import 'package:fontify_plus/src/svg/shapes/circle_element.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

CircleElement circle(String xml) =>
    CircleElement.fromXmlElement(null, parse(xml));

void main() {
  group('CircleElement.fromXmlElement', () {
    test('reads centre and radius', () {
      final element = circle('<circle cx="3" cy="4" r="5"/>');

      expect(element.cx, 3);
      expect(element.cy, 4);
      expect(element.r, 5);
    });

    test('defaults centre to the origin when absent', () {
      final element = circle('<circle r="5"/>');

      expect(element.cx, 0);
      expect(element.cy, 0);
    });
  });

  group('CircleElement.getPath', () {
    test('traces the circle with two half-turn arcs', () {
      // A single arc command cannot describe a full circle, since its start
      // and end points would coincide.
      final path = circle('<circle cx="0" cy="0" r="5"/>').getPath();

      expect('A'.allMatches(path.data), hasLength(2));
    });

    test('starts and ends at the leftmost point', () {
      final path = circle('<circle cx="10" cy="20" r="5"/>').getPath();

      expect(path.data, startsWith('M5,20'));
    });

    test('spans the diameter between the two arcs', () {
      final path = circle('<circle cx="10" cy="20" r="5"/>').getPath();

      expect(path.data, contains('15,20'));
    });

    test('uses the radius for both axes of each arc', () {
      final path = circle('<circle cx="0" cy="0" r="7"/>').getPath();

      expect(path.data, contains('A7,7'));
    });

    test('closes the contour', () {
      final path = circle('<circle r="1"/>').getPath();

      expect(path.data, endsWith('z'));
    });

    test('carries the transform through to the path', () {
      final element = CircleElement.fromXmlElement(
        null,
        parse('<circle r="1" transform="translate(1,1)"/>'),
      );

      expect(element.getPath().transform, element.transform);
    });
  });
}
