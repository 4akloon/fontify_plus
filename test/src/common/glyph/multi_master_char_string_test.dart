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
          pointList: points.toList(),
          isOnCurveList: onCurve ?? List.filled(points.length, true),
          hasCompactCurves: false,
          hasQuadCurves: false,
          fillRule: FillRule.nonzero,
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

      final masters = CharStringEncoder([
        a,
        b,
      ], CharStringOptimizer(false)).encode();

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

      final masters = CharStringEncoder([
        a,
        b,
      ], CharStringOptimizer(false)).encode();

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

      final masters = CharStringEncoder([
        a,
        b,
      ], CharStringOptimizer(false)).encode();

      expect(masters[0].map((c) => c.operator), [vmoveto, rrcurveto]);
      expect(masters[1].map((c) => c.operator), [vmoveto, rrcurveto]);
      expect(masters[0][1].operandList.map((o) => o.value), [0, 0, 0, 0, 0, 0]);
      expect(masters[1][1].operandList.map((o) => o.value), [1, 2, 2, 2, 2, 2]);
    });

    test('a merged rlineto run keeps each master on its own coordinates', () {
      // Two adjacent rlineto commands merge into one. The merge has to append
      // each master's own operands to that master's command: appending master
      // 0's to all of them would hand the thick master the thin outline for
      // that run, and the variation deltas for those points would come out
      // zero. Nothing downstream can detect that, so it is asserted here.
      final a = _glyph([
        const math.Point<num>(1, 1),
        const math.Point<num>(3, 4),
        const math.Point<num>(6, 8),
      ]);
      final b = _glyph([
        const math.Point<num>(2, 1),
        const math.Point<num>(5, 5),
        const math.Point<num>(9, 10),
      ]);

      final masters = CharStringEncoder([
        a,
        b,
      ], CharStringOptimizer(false)).encode();

      for (final commands in masters) {
        expect(commands.map((c) => c.operator), [rmoveto, rlineto]);
      }
      expect(masters[0][0].operandList.map((o) => o.value), [1, 1]);
      expect(masters[1][0].operandList.map((o) => o.value), [2, 1]);
      expect(masters[0][1].operandList.map((o) => o.value), [2, 3, 3, 4]);
      expect(masters[1][1].operandList.map((o) => o.value), [3, 4, 4, 5]);
    });

    test('a merged vvcurveto run keeps each master on its own coordinates', () {
      // The curve merge carries an extra condition — neither side may hold a
      // leading delta — and is the one place operand counts could differ, so
      // it gets its own fixture. Every curve here starts and ends with a zero
      // dx in both masters, which is what makes the form `vvcurveto` with the
      // leading delta dropped: four operands each, so the two merge.
      final a = _glyph(
        [
          const math.Point<num>(0, 0),
          const math.Point<num>(0, 10),
          const math.Point<num>(5, 15),
          const math.Point<num>(5, 20),
          const math.Point<num>(5, 25),
          const math.Point<num>(10, 30),
          const math.Point<num>(10, 35),
        ],
        onCurve: [true, false, false, true, false, false, true],
      );
      final b = _glyph(
        [
          const math.Point<num>(0, 0),
          const math.Point<num>(0, 12),
          const math.Point<num>(6, 18),
          const math.Point<num>(6, 24),
          const math.Point<num>(6, 30),
          const math.Point<num>(12, 36),
          const math.Point<num>(12, 42),
        ],
        onCurve: [true, false, false, true, false, false, true],
      );

      final masters = CharStringEncoder([
        a,
        b,
      ], CharStringOptimizer(false)).encode();

      for (final commands in masters) {
        expect(commands.map((c) => c.operator), [vmoveto, vvcurveto]);
      }
      expect(masters[0][1].operandList.map((o) => o.value), [
        10, 5, 5, 5, //
        5, 5, 5, 5,
      ]);
      expect(masters[1][1].operandList.map((o) => o.value), [
        12, 6, 6, 6, //
        6, 6, 6, 6,
      ]);
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
        () => CharStringEncoder([
          a,
          b,
        ], CharStringOptimizer(false)).encode(),
        throwsArgumentError,
      );
    });

    test('at least one master is required', () {
      expect(
        () => CharStringEncoder([], CharStringOptimizer(false)).encode(),
        throwsArgumentError,
      );
    });
  });
}
