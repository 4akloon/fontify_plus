import 'dart:async';
import 'dart:math';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/char_string_optimizer.dart';
import 'package:fontify_plus/src/otf/cff/operator.dart';
import 'package:test/test.dart';

final _optimizer = CharStringOptimizer(true);

GenericGlyph glyphOf(
  List<Point<num>> points,
  List<bool> onCurve, {
  FillRule fillRule = FillRule.nonzero,
}) => GenericGlyph(
  [Outline(points, onCurve, false, false, fillRule)],
  const Rectangle(0, 0, 10, 10),
);

void main() {
  group('GlyphCharStringEncoding.toCharStringCommands', () {
    test('opens every contour with a moveto', () {
      final glyph = glyphOf(
        [const Point(1, 2), const Point(5, 2), const Point(5, 5)],
        [true, true, true],
      );

      final commands = glyph.toCharStringCommands(_optimizer);

      expect(commands.first.operator.context, CFFOperatorContext.charString);
      expect(
        [hmoveto, vmoveto, rmoveto].map((o) => o.b0),
        contains(commands.first.operator.b0),
      );
    });

    test('encodes a straight contour with only line operators', () {
      final glyph = glyphOf(
        [
          const Point(0, 0),
          const Point(10, 0),
          const Point(10, 10),
          const Point(0, 10),
        ],
        [true, true, true, true],
      );

      final commands = glyph.toCharStringCommands(_optimizer);
      final lineOps = {hmoveto, vmoveto, rmoveto, hlineto, vlineto, rlineto};

      expect(commands.every((c) => lineOps.contains(c.operator)), isTrue);
    });

    test('encodes two consecutive off-curve points as a curve operator', () {
      final glyph = glyphOf(
        [
          const Point(0, 0),
          const Point(0, 10),
          const Point(10, 10),
          const Point(10, 0),
        ],
        [true, false, false, true],
      );

      final commands = glyph.toCharStringCommands(_optimizer);
      final curveOps = {rrcurveto, hhcurveto, vvcurveto};

      expect(commands.any((c) => curveOps.contains(c.operator)), isTrue);
    });

    test('throws when an outline still has quadratic curves', () {
      final glyph = GenericGlyph(
        [
          Outline(
            [const Point(0, 0), const Point(5, 5)],
            [true, false],
            false,
            true, // hasQuadCurves
            FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 10, 10),
      );

      expect(
        () => glyph.toCharStringCommands(_optimizer),
        throwsUnsupportedError,
      );
    });

    test('warns, but still encodes, an even-odd outline', () {
      final glyph = glyphOf(
        [const Point(0, 0), const Point(10, 0), const Point(10, 10)],
        [true, true, true],
        fillRule: FillRule.evenodd,
      );

      final commands = runZoned(
        () => glyph.toCharStringCommands(_optimizer),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {},
        ),
      );

      expect(commands, isNotEmpty);
    });

    test('encodes each contour of a multi-contour glyph separately', () {
      final glyph = GenericGlyph(
        [
          Outline(
            [const Point(0, 0), const Point(1, 0), const Point(1, 1)],
            [true, true, true],
            false,
            false,
            FillRule.nonzero,
          ),
          Outline(
            [const Point(5, 5), const Point(6, 5), const Point(6, 6)],
            [true, true, true],
            false,
            false,
            FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 10, 10),
      );

      final commands = glyph.toCharStringCommands(_optimizer);
      final movetoOps = {hmoveto, vmoveto, rmoveto};

      expect(
        commands.where((c) => movetoOps.contains(c.operator)),
        hasLength(2),
      );
    });
  });
}
