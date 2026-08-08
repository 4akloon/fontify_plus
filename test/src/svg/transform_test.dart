import 'package:fontify_plus/src/svg/transform.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// Applies [matrix] to a point, the way path coordinates are transformed.
Vector2 apply(Matrix3 matrix, double x, double y) {
  final v = Vector3(x, y, 1)..applyMatrix3(matrix);

  return Vector2(v.x, v.y);
}

void main() {
  group('Transform.parse', () {
    test('returns nothing for null', () {
      expect(Transform.parse(null), isEmpty);
    });

    test('returns nothing for an empty string', () {
      expect(Transform.parse(''), isEmpty);
    });

    test('parses a single function', () {
      final transforms = Transform.parse('translate(3, 4)');

      expect(transforms, hasLength(1));
      expect(transforms.single.type, TransformType.translate);
      expect(transforms.single.parameterList, [3.0, 4.0]);
    });

    test('parses multiple functions in order', () {
      final transforms = Transform.parse('translate(1 2) scale(3)');

      expect(transforms, hasLength(2));
      expect(transforms[0].type, TransformType.translate);
      expect(transforms[1].type, TransformType.scale);
    });

    test('accepts comma or whitespace between parameters', () {
      final commaSeparated = Transform.parse('translate(1,2)').single;
      final spaceSeparated = Transform.parse('translate(1 2)').single;

      expect(commaSeparated.parameterList, spaceSeparated.parameterList);
    });

    test('parses negative and fractional parameters', () {
      final transform = Transform.parse('translate(-1.5, 2.25)').single;

      expect(transform.parameterList, [-1.5, 2.25]);
    });
  });

  group('Transform.matrix — matrix()', () {
    test('reads all six values, padding the rest', () {
      final transform = Transform.parse('matrix(1, 0, 0, 1, 5, 6)').single;
      final point = apply(transform.matrix!, 0, 0);

      expect(point.x, closeTo(5, 1e-5));
      expect(point.y, closeTo(6, 1e-5));
    });
  });

  group('Transform.matrix — translate()', () {
    test('moves a point by (dx, dy)', () {
      final transform = Transform.parse('translate(3, 4)').single;
      final point = apply(transform.matrix!, 1, 1);

      expect(point.x, closeTo(4, 1e-5));
      expect(point.y, closeTo(5, 1e-5));
    });

    test('defaults dy to zero when only dx is given', () {
      final transform = Transform.parse('translate(3)').single;
      final point = apply(transform.matrix!, 0, 0);

      expect(point.x, closeTo(3, 1e-5));
      expect(point.y, closeTo(0, 1e-5));
    });
  });

  group('Transform.matrix — scale()', () {
    test('scales both axes uniformly with one parameter', () {
      final transform = Transform.parse('scale(2)').single;
      final point = apply(transform.matrix!, 3, 5);

      expect(point.x, closeTo(6, 1e-5));
      expect(point.y, closeTo(10, 1e-5));
    });

    test('scales axes independently with two parameters', () {
      final transform = Transform.parse('scale(2, 3)').single;
      final point = apply(transform.matrix!, 1, 1);

      expect(point.x, closeTo(2, 1e-5));
      expect(point.y, closeTo(3, 1e-5));
    });
  });

  group('Transform.matrix — rotate()', () {
    test('rotates about the origin by default', () {
      final transform = Transform.parse('rotate(90)').single;
      final point = apply(transform.matrix!, 1, 0);

      expect(point.x, closeTo(0, 1e-5));
      expect(point.y, closeTo(1, 1e-5));
    });

    test('rotates about the given centre when given three parameters', () {
      final transform = Transform.parse('rotate(90, 1, 1)').single;
      final point = apply(transform.matrix!, 1, 0);

      // (1, 0) is distance 1 from the centre (1, 1); a 90 degree turn about
      // that centre lands it at (2, 1).
      expect(point.x, closeTo(2, 1e-5));
      expect(point.y, closeTo(1, 1e-5));
    });
  });

  group('Transform.matrix — skewX() and skewY()', () {
    test('skewX shears x by tan(angle) * y', () {
      final transform = Transform.parse('skewX(45)').single;
      final point = apply(transform.matrix!, 0, 2);

      expect(point.x, closeTo(2, 1e-5));
      expect(point.y, closeTo(2, 1e-5));
    });

    test('skewY shears y by tan(angle) * x', () {
      final transform = Transform.parse('skewY(45)').single;
      final point = apply(transform.matrix!, 2, 0);

      expect(point.x, closeTo(2, 1e-5));
      expect(point.y, closeTo(2, 1e-5));
    });
  });

  group('generateTransformMatrix', () {
    test('returns null for an empty list', () {
      expect(generateTransformMatrix([]), isNull);
    });

    test('composes transforms in list order', () {
      // SVG composes "A B" as matrix A * B, so v' = A*(B*v): the transform
      // listed last is the one applied first, to the untransformed point.
      final matrix = generateTransformMatrix(
        Transform.parse('translate(10, 0) scale(2)'),
      )!;

      final point = apply(matrix, 1, 0);

      // scale(2) first: (1,0) -> (2,0). translate(10,0) second: -> (12,0).
      expect(point.x, closeTo(12, 1e-5));
    });

    test('matches applying each transform in sequence, last first', () {
      final transforms = Transform.parse('rotate(90) translate(1, 0)');
      final combined = generateTransformMatrix(transforms)!;

      var manual = Vector3(1, 0, 1);
      for (final t in transforms.reversed) {
        manual = t.matrix!.transformed(manual);
      }

      final viaCombined = apply(combined, 1, 0);

      expect(viaCombined.x, closeTo(manual.x, 1e-5));
      expect(viaCombined.y, closeTo(manual.y, 1e-5));
    });
  });

  group('TransformType', () {
    test('has exactly the six SVG transform functions', () {
      expect(TransformType.values, hasLength(6));
    });
  });
}
