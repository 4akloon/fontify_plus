import 'package:fontify_plus/src/svg/shapes/line_element.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

LineElement line(String xml) => LineElement.fromXmlElement(null, parse(xml));

void main() {
  group('LineElement.fromXmlElement', () {
    test('reads both endpoints', () {
      final element = line('<line x1="1" y1="2" x2="3" y2="4"/>');

      expect(element.x1, 1);
      expect(element.y1, 2);
      expect(element.x2, 3);
      expect(element.y2, 4);
    });

    test('defaults every coordinate to zero when absent', () {
      final element = line('<line/>');

      expect(element.x1, 0);
      expect(element.y1, 0);
      expect(element.x2, 0);
      expect(element.y2, 0);
    });
  });

  group('LineElement.getPath', () {
    test('starts at the first endpoint', () {
      final path = line('<line x1="1" y1="2" x2="3" y2="4"/>').getPath();

      expect(path.data, startsWith('M1 2'));
    });

    test('visits the second endpoint before closing', () {
      final path = line('<line x1="1" y1="2" x2="3" y2="4"/>').getPath();

      expect(path.data, contains('3 4'));
      expect(path.data, endsWith('z'));
    });

    test('gives the sliver standing in for the line a nonzero width', () {
      // A line has no area; filling it directly produces nothing. getPath
      // stands in a thin quadrilateral instead.
      final path = line('<line x1="0" y1="0" x2="10" y2="0"/>').getPath();

      expect(path.data, isNot(contains('10 0 10 0')));
    });

    test('carries the transform through to the path', () {
      final element = LineElement.fromXmlElement(
        null,
        parse('<line transform="translate(1,1)"/>'),
      );

      expect(element.getPath().transform, element.transform);
    });
  });
}
