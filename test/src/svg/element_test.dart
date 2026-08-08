import 'package:fontify_plus/src/svg/element.dart';
import 'package:fontify_plus/src/svg/path.dart';
import 'package:fontify_plus/src/svg/shapes.dart';
import 'package:fontify_plus/src/svg/unknown_element.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:xml/xml.dart';

XmlElement parse(String xml) => XmlDocument.parse(xml).rootElement;

void main() {
  group('SvgElement.fromXmlElement', () {
    final cases = {
      '<path d="M0 0"/>': PathElement,
      '<rect x="0" y="0" width="1" height="1"/>': RectElement,
      '<circle cx="0" cy="0" r="1"/>': CircleElement,
      '<polyline points="0,0 1,1"/>': PolylineElement,
      '<polygon points="0,0 1,1 1,0"/>': PolygonElement,
      '<line x1="0" y1="0" x2="1" y2="1"/>': LineElement,
      '<g><path d="M0 0"/></g>': GroupElement,
      '<defs/>': UnknownElement,
    };

    cases.forEach((xml, type) {
      test('maps <${parse(xml).name.local}> to $type', () {
        final element = SvgElement.fromXmlElement(null, parse(xml), false);

        expect(element, isA<Object>());
        expect(element.runtimeType, type);
      });
    });
  });

  group('getResultTransformMatrix', () {
    test('returns null with no transform anywhere in the chain', () {
      final element = UnknownElement(null, parse('<defs/>'));

      expect(element.getResultTransformMatrix(), isNull);
    });

    test('returns its own transform when there is no parent', () {
      final element = UnknownElement(null, parse('<g transform="scale(2)"/>'));

      expect(element.getResultTransformMatrix(), isNotNull);
    });

    test('combines its own transform with every ancestor\'s', () {
      final parent =
          UnknownElement(null, parse('<g transform="translate(1, 0)"/>'));
      final child =
          UnknownElement(parent, parse('<g transform="translate(2, 0)"/>'));

      final combined = child.getResultTransformMatrix()!;
      final v = Vector3(0, 0, 1)..applyMatrix3(combined);

      // Child's own transform applies first, then the parent's — the parent
      // establishes the outer coordinate space.
      expect(v.x, closeTo(3, 1e-5));
    });

    test('walks past an ancestor with no transform of its own', () {
      final grandparent =
          UnknownElement(null, parse('<g transform="translate(5, 0)"/>'));
      final parent = UnknownElement(grandparent, parse('<g/>'));
      final child = UnknownElement(parent, parse('<defs/>'));

      final combined = child.getResultTransformMatrix()!;
      final v = Vector3(0, 0, 1)..applyMatrix3(combined);

      expect(v.x, closeTo(5, 1e-5));
    });
  });

  group('GroupElement.fromXmlElement', () {
    test('parses its children', () {
      final group = GroupElement.fromXmlElement(
        null,
        parse('<g><path d="M0 0"/><path d="M1 1"/></g>'),
        false,
      );

      expect(group.elementList, hasLength(2));
    });

    test('leaves shapes unconverted when ignoreShapes is true', () {
      // Nothing here actually discards the shape — [RectElement] simply isn't
      // a [PathElement], and it's GenericGlyph.fromSvg's `whereType<PathElement>`
      // filter downstream that turns "not converted" into "dropped".
      final group = GroupElement.fromXmlElement(
        null,
        parse('<g><rect x="0" y="0" width="1" height="1"/></g>'),
        true,
      );

      expect(group.elementList.single, isA<RectElement>());
    });

    test('converts shapes to paths when ignoreShapes is false', () {
      final group = GroupElement.fromXmlElement(
        null,
        parse('<g><rect x="0" y="0" width="1" height="1"/></g>'),
        false,
      );

      expect(group.elementList.single, isA<PathElement>());
    });
  });

  group('GroupElement.applyTransformOnChildren', () {
    test('does nothing when the group has no transform', () {
      final group = GroupElement.fromXmlElement(
        null,
        parse('<g><path d="M0 0"/></g>'),
        false,
      );
      final childTransformBefore = group.elementList.single.transform;

      group.applyTransformOnChildren();

      expect(group.elementList.single.transform, childTransformBefore);
    });

    test("pushes the group's transform onto each child and clears its own", () {
      final group = GroupElement.fromXmlElement(
        null,
        parse('<g transform="translate(3, 0)"><path d="M0 0"/></g>'),
        false,
      );

      group.applyTransformOnChildren();

      expect(group.transform, isNull);

      final child = group.elementList.single;
      final v = Vector3(0, 0, 1)..applyMatrix3(child.transform!);

      expect(v.x, closeTo(3, 1e-5));
    });

    test("composes with a child's existing transform", () {
      final group = GroupElement.fromXmlElement(
        null,
        parse(
          '<g transform="translate(3, 0)">'
          '<path d="M0 0" transform="translate(0, 5)"/>'
          '</g>',
        ),
        false,
      );

      group.applyTransformOnChildren();

      final child = group.elementList.single;
      final v = Vector3(0, 0, 1)..applyMatrix3(child.transform!);

      expect(v.x, closeTo(3, 1e-5));
      expect(v.y, closeTo(5, 1e-5));
    });
  });
}
