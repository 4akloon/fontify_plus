import 'package:fontify_plus/src/otf/cff/char_string_form.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:test/test.dart';

void main() {
  group('charstring form, decided across masters', () {
    test('a single master keeps every shorthand it takes today', () {
      expect(
        movetoForm([
          [0, 7],
        ]).operator,
        vmoveto,
      );
      expect(
        movetoForm([
          [0, 7],
        ]).operandIndices,
        [1],
      );
      expect(
        movetoForm([
          [7, 0],
        ]).operator,
        hmoveto,
      );
      expect(
        movetoForm([
          [7, 0],
        ]).operandIndices,
        [0],
      );
      expect(
        movetoForm([
          [7, 7],
        ]).operator,
        rmoveto,
      );
      expect(
        movetoForm([
          [7, 7],
        ]).operandIndices,
        [0, 1],
      );

      expect(
        linetoForm([
          [0, 7],
        ]).operator,
        vlineto,
      );
      expect(
        linetoForm([
          [7, 0],
        ]).operator,
        hlineto,
      );
      expect(
        linetoForm([
          [7, 7],
        ]).operator,
        rlineto,
      );
    });

    test('a component zero in one master only is written in full', () {
      // Master A moves straight up, master B also drifts sideways. Taking
      // vmoveto from A would encode B's dx as an implicit zero and lose it.
      final form = movetoForm([
        [0, 7],
        [3, 7],
      ]);

      expect(form.operator, rmoveto);
      expect(form.operandIndices, [0, 1]);
    });

    test('a component zero in every master is still dropped', () {
      final form = linetoForm([
        [0, 7],
        [0, 9],
      ]);

      expect(form.operator, vlineto);
      expect(form.operandIndices, [1]);
    });

    test('vvcurveto needs the final dx zero in every master', () {
      // dlist[4] is the last curve's dx.
      final shared = curvetoForm([
        [1, 2, 3, 4, 0, 6],
        [1, 2, 3, 4, 0, 8],
      ]);
      expect(shared.operator, vvcurveto);
      // zeroAt 4 removed, leadingAt 0 (dx0 = 1, non-zero) moved to the front.
      expect(shared.operandIndices, [0, 1, 2, 3, 5]);

      final split = curvetoForm([
        [1, 2, 3, 4, 0, 6],
        [1, 2, 3, 4, 5, 8],
      ]);
      expect(split.operator, rrcurveto);
      expect(split.operandIndices, [0, 1, 2, 3, 4, 5]);
    });

    test('the leading delta is dropped only when zero in every master', () {
      final dropped = curvetoForm([
        [0, 2, 3, 4, 0, 6],
        [0, 2, 3, 4, 0, 8],
      ]);
      expect(dropped.operator, vvcurveto);
      expect(dropped.operandIndices, [1, 2, 3, 5]);

      final kept = curvetoForm([
        [0, 2, 3, 4, 0, 6],
        [1, 2, 3, 4, 0, 8],
      ]);
      expect(kept.operator, vvcurveto);
      expect(kept.operandIndices, [0, 1, 2, 3, 5]);
    });

    test('hhcurveto is preferred only when vvcurveto does not apply', () {
      final form = curvetoForm([
        [1, 2, 3, 4, 5, 0],
      ]);
      expect(form.operator, hhcurveto);
      // zeroAt 5 removed, leadingAt 1 (dy0 = 2) moved to the front.
      expect(form.operandIndices, [1, 0, 2, 3, 4]);
    });
  });

  // The cases below came from `char_string_shorthand_test.dart`, which tested
  // the single-master decision these forms replace. They are kept so that
  // widening the decision to several masters did not quietly narrow what is
  // covered for one.
  group('charstring form, single master', () {
    test('movetoForm prefers vmoveto when both deltas are zero', () {
      expect(
        movetoForm([
          [0, 0],
        ]).operator,
        vmoveto,
      );
      expect(
        movetoForm([
          [0, 0],
        ]).operandIndices,
        [1],
      );
    });

    test('linetoForm keeps both deltas when neither is zero', () {
      expect(
        linetoForm([
          [5, 6],
        ]).operandIndices,
        [0, 1],
      );
    });

    test('curvetoForm throws unless every master supplies six deltas', () {
      expect(
        () => curvetoForm([
          [1, 2, 3, 4, 5],
        ]),
        throwsArgumentError,
      );
      expect(
        () => curvetoForm([
          [1, 2, 3, 4, 5, 6],
          [1, 2, 3, 4, 5],
        ]),
        throwsArgumentError,
      );
    });

    test('curvetoForm falls back to rrcurveto when no final delta is zero', () {
      final form = curvetoForm([
        [1, 2, 3, 4, 5, 6],
      ]);

      expect(form.operator, rrcurveto);
      expect(form.operandIndices, [0, 1, 2, 3, 4, 5]);
    });

    test('curvetoForm prefers vvcurveto when both final deltas are zero', () {
      expect(
        curvetoForm([
          [1, 2, 3, 4, 0, 0],
        ]).operator,
        vvcurveto,
      );
    });
  });
}
