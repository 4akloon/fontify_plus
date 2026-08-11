// Two masters of the same glyph must produce structurally identical command
// streams: same operators in the same order, same operand counts. Anything
// else cannot carry variation deltas.
import 'dart:math' as math;

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/cff/char_string_command.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/char_string_optimizer.dart';
import 'package:test/test.dart';

/// One cubic, already-decompacted contour.
///
/// `false, false` is the only state the charstring encoder accepts: compact
/// curves leave points implicit and quadratics are rejected outright.
GenericGlyph _glyph(List<math.Point<num>> points, {List<bool>? onCurve}) =>
    GenericGlyph(
      [
        Outline(
          points.toList(),
          onCurve ?? List.filled(points.length, true),
          false,
          false,
          FillRule.nonzero,
        ),
      ],
      const math.Rectangle<num>(0, 0, 100, 100),
      GenericGlyphMetadata(name: 'test'),
    );

void main() {
  group('charstring commands across masters', () {
    test('a single master is byte-for-byte what it was before', () {
      // Starts away from the origin on purpose: the first point's coordinates
      // are themselves the moveto's deltas, so a contour opening at (0, 0)
      // would only ever exercise the both-deltas-zero branch.
      final glyph = _glyph([
        const math.Point<num>(5, 0),
        const math.Point<num>(15, 0),
        const math.Point<num>(15, 10),
      ]);

      final commands = glyph.toCharStringCommands(CharStringOptimizer(false));

      expect(commands.map((c) => c.operator), [hmoveto, hlineto, vlineto]);
      expect(commands[1].operandList.single.value, 10);
    });

    test('a shorthand one master alone would take is not taken', () {
      // Both masters start at the origin; only the second one's second point
      // leaves the x axis. Master A alone would encode hlineto(10).
      final a = _glyph([
        const math.Point<num>(0, 0),
        const math.Point<num>(10, 0),
      ]);
      final b = _glyph([
        const math.Point<num>(0, 0),
        const math.Point<num>(10, 3),
      ]);

      final masters = a.toCharStringCommandsForMasters([
        a,
        b,
      ], CharStringOptimizer(false));

      expect(masters, hasLength(2));
      for (final commands in masters) {
        expect(commands.map((c) => c.operator), [vmoveto, rlineto]);
      }
      expect(masters[0][1].operandList.map((o) => o.value), [10, 0]);
      expect(masters[1][1].operandList.map((o) => o.value), [10, 3]);
    });

    test('both masters emit the same operators and operand counts', () {
      final a = _glyph([
        const math.Point<num>(0, 0),
        const math.Point<num>(10, 0),
        const math.Point<num>(10, 10),
        const math.Point<num>(0, 10),
      ]);
      final b = _glyph([
        const math.Point<num>(1, 1),
        const math.Point<num>(9, 1),
        const math.Point<num>(9, 9),
        const math.Point<num>(1, 9),
      ]);

      final masters = a.toCharStringCommandsForMasters([
        a,
        b,
      ], CharStringOptimizer(false));

      List<String> shapeOf(List<CharStringCommand> commands) => [
        for (final c in commands) '${c.operator}:${c.operandList.length}',
      ];

      expect(shapeOf(masters[0]), shapeOf(masters[1]));
    });

    test('an all-zero curve is dropped only when zero in every master', () {
      // A degenerate curve in master A that master B actually draws must
      // survive in both, or the two lose a command relative to each other.
      final a = _glyph(
        [
          const math.Point<num>(0, 0),
          const math.Point<num>(0, 0),
          const math.Point<num>(0, 0),
          const math.Point<num>(0, 0),
        ],
        onCurve: [true, false, false, true],
      );
      final b = _glyph(
        [
          const math.Point<num>(0, 0),
          const math.Point<num>(1, 2),
          const math.Point<num>(3, 4),
          const math.Point<num>(5, 6),
        ],
        onCurve: [true, false, false, true],
      );

      // On its own, master A's curve moves nothing and is dropped entirely.
      expect(a.toCharStringCommands(CharStringOptimizer(false)), hasLength(1));

      final masters = a.toCharStringCommandsForMasters([
        a,
        b,
      ], CharStringOptimizer(false));

      expect(masters[0].map((c) => c.operator), [vmoveto, rrcurveto]);
      expect(masters[1].map((c) => c.operator), [vmoveto, rrcurveto]);
      expect(masters[0][1].operandList.map((o) => o.value), [0, 0, 0, 0, 0, 0]);
      expect(masters[1][1].operandList.map((o) => o.value), [1, 2, 2, 2, 2, 2]);
    });

    test('mismatched point counts are rejected, not silently truncated', () {
      final a = _glyph([
        const math.Point<num>(0, 0),
        const math.Point<num>(10, 0),
      ]);
      final b = _glyph([
        const math.Point<num>(0, 0),
        const math.Point<num>(10, 0),
        const math.Point<num>(10, 10),
      ]);

      expect(
        () => a.toCharStringCommandsForMasters([
          a,
          b,
        ], CharStringOptimizer(false)),
        throwsArgumentError,
      );
    });

    test('at least one master is required', () {
      expect(
        () => _glyph([
          const math.Point<num>(0, 0),
        ]).toCharStringCommandsForMasters([], CharStringOptimizer(false)),
        throwsArgumentError,
      );
    });
  });
}
