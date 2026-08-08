import 'package:fontify_plus/src/svg/shapes/rect_element.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

RectElement rect(String xml) => RectElement.fromXmlElement(null, parse(xml));

void main() {
  group('RectElement.fromXmlElement', () {
    test('reads position and size', () {
      final element = rect('<rect x="1" y="2" width="3" height="4"/>');

      expect(element.x, 1);
      expect(element.y, 2);
      expect(element.width, 3);
      expect(element.height, 4);
    });

    test('defaults position to zero when absent', () {
      final element = rect('<rect width="3" height="4"/>');

      expect(element.x, 0);
      expect(element.y, 0);
    });

    test('is square-cornered with no rx or ry', () {
      final element = rect('<rect width="1" height="1"/>');

      expect(element.rx, 0);
      expect(element.ry, 0);
    });

    test('ry defaults to rx when only rx is given', () {
      final element = rect('<rect width="10" height="10" rx="2"/>');

      expect(element.rx, 2);
      expect(element.ry, 2);
    });

    test('rx defaults to ry when only ry is given', () {
      final element = rect('<rect width="10" height="10" ry="3"/>');

      expect(element.rx, 3);
      expect(element.ry, 3);
    });

    test('keeps rx and ry independent when both are given', () {
      final element = rect('<rect width="10" height="10" rx="2" ry="5"/>');

      expect(element.rx, 2);
      expect(element.ry, 5);
    });
  });

  group('RectElement.getPath', () {
    test('traces a square-cornered rectangle with four lines', () {
      final path = rect('<rect x="0" y="0" width="10" height="20"/>').getPath();

      expect(path.data, 'M0 0h10v20h-10v-20z');
    });

    test('offsets the path data to the rectangle\'s position', () {
      final path = rect('<rect x="5" y="7" width="10" height="20"/>').getPath();

      expect(path.data, startsWith('M5 7'));
    });

    test('inserts an arc at each corner when rounded', () {
      final path = rect(
        '<rect x="0" y="0" width="10" height="10" rx="2" ry="3"/>',
      ).getPath();

      expect('a'.allMatches(path.data), hasLength(4));
      expect(path.data, contains('a 2 3 0 0 1'));
    });

    test('shrinks the straight runs by the corner radius', () {
      // A 10-wide rect with rx=2 has a straight top run of 10 - 2*2 = 6.
      final path = rect(
        '<rect x="0" y="0" width="10" height="10" rx="2" ry="2"/>',
      ).getPath();

      expect(path.data, startsWith('M2 0h6a'));
    });

    test('closes the contour', () {
      final path = rect('<rect width="1" height="1"/>').getPath();

      expect(path.data, endsWith('z'));
    });

    test('carries the transform through to the path', () {
      final element = RectElement.fromXmlElement(
        null,
        parse('<rect width="1" height="1" transform="translate(1,1)"/>'),
      );

      expect(element.getPath().transform, element.transform);
    });
  });
}
