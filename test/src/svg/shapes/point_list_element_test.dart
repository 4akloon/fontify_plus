import 'package:fontify_plus/src/svg/shapes/point_list_element.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

void main() {
  group('PolylineElement.fromXmlElement', () {
    test('reads the raw points string', () {
      final element = PolylineElement.fromXmlElement(
        null,
        parse('<polyline points="0,0 1,1 2,0"/>'),
      );

      expect(element.points, '0,0 1,1 2,0');
    });
  });

  group('PolygonElement.fromXmlElement', () {
    test('reads the raw points string', () {
      final element = PolygonElement.fromXmlElement(
        null,
        parse('<polygon points="0,0 1,1 2,0"/>'),
      );

      expect(element.points, '0,0 1,1 2,0');
    });
  });

  group('PointListElement.getPath', () {
    test('opens with a move to the point list and closes the contour', () {
      final element = PolygonElement.fromXmlElement(
        null,
        parse('<polygon points="0,0 1,1 2,0"/>'),
      );

      expect(element.getPath().data, 'M0,0 1,1 2,0z');
    });

    test('polyline and polygon produce the same path shape', () {
      const points = '3,1 4,5 8,2';

      final polyline = PolylineElement.fromXmlElement(
        null,
        parse('<polyline points="$points"/>'),
      ).getPath();
      final polygon = PolygonElement.fromXmlElement(
        null,
        parse('<polygon points="$points"/>'),
      ).getPath();

      expect(polyline.data, polygon.data);
    });

    test('carries the transform through to the path', () {
      final element = PolygonElement.fromXmlElement(
        null,
        parse('<polygon points="0,0 1,1" transform="translate(1,1)"/>'),
      );

      expect(element.getPath().transform, element.transform);
    });
  });
}
