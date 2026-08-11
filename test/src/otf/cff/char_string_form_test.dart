import 'package:fontify_plus/src/otf/cff/char_string_form.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:test/test.dart';

void main() {
  group('charstring form, decided across masters', () {
    test('a single master keeps every shorthand it takes today', () {
      expect(
        const CharStringFormChooser([
          [0, 7],
        ]).moveto().operator,
        vmoveto,
      );
      expect(
        const CharStringFormChooser([
          [0, 7],
        ]).moveto().operandIndices,
        [1],
      );
      expect(
        const CharStringFormChooser([
          [7, 0],
        ]).moveto().operator,
        hmoveto,
      );
      expect(
        const CharStringFormChooser([
          [7, 0],
        ]).moveto().operandIndices,
        [0],
      );
      expect(
        const CharStringFormChooser([
          [7, 7],
        ]).moveto().operator,
        rmoveto,
      );
      expect(
        const CharStringFormChooser([
          [7, 7],
        ]).moveto().operandIndices,
        [0, 1],
      );

      expect(
        const CharStringFormChooser([
          [0, 7],
        ]).lineto().operator,
        vlineto,
      );
      expect(
        const CharStringFormChooser([
          [7, 0],
        ]).lineto().operator,
        hlineto,
      );
      expect(
        const CharStringFormChooser([
          [7, 7],
        ]).lineto().operator,
        rlineto,
      );
    });

    test('a component zero in one master only is written in full', () {
      // Master A moves straight up, master B also drifts sideways. Taking
      // vmoveto from A would encode B's dx as an implicit zero and lose it.
      final form = const CharStringFormChooser([
        [0, 7],
        [3, 7],
      ]).moveto();

      expect(form.operator, rmoveto);
      expect(form.operandIndices, [0, 1]);
    });

    test('a component zero in every master is still dropped', () {
      final form = const CharStringFormChooser([
        [0, 7],
        [0, 9],
      ]).lineto();

      expect(form.operator, vlineto);
      expect(form.operandIndices, [1]);
    });

    test('vvcurveto needs the final dx zero in every master', () {
      // dlist[4] is the last curve's dx.
      final shared = const CharStringFormChooser([
        [1, 2, 3, 4, 0, 6],
        [1, 2, 3, 4, 0, 8],
      ]).curveto();
      expect(shared.operator, vvcurveto);
      // zeroAt 4 removed, leadingAt 0 (dx0 = 1, non-zero) moved to the front.
      expect(shared.operandIndices, [0, 1, 2, 3, 5]);

      final split = const CharStringFormChooser([
        [1, 2, 3, 4, 0, 6],
        [1, 2, 3, 4, 5, 8],
      ]).curveto();
      expect(split.operator, rrcurveto);
      expect(split.operandIndices, [0, 1, 2, 3, 4, 5]);
    });

    test('the leading delta is dropped only when zero in every master', () {
      final dropped = const CharStringFormChooser([
        [0, 2, 3, 4, 0, 6],
        [0, 2, 3, 4, 0, 8],
      ]).curveto();
      expect(dropped.operator, vvcurveto);
      expect(dropped.operandIndices, [1, 2, 3, 5]);

      final kept = const CharStringFormChooser([
        [0, 2, 3, 4, 0, 6],
        [1, 2, 3, 4, 0, 8],
      ]).curveto();
      expect(kept.operator, vvcurveto);
      expect(kept.operandIndices, [0, 1, 2, 3, 5]);
    });

    test('hhcurveto is preferred only when vvcurveto does not apply', () {
      final form = const CharStringFormChooser([
        [1, 2, 3, 4, 5, 0],
      ]).curveto();
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
    test('moveto prefers vmoveto when both deltas are zero', () {
      expect(
        const CharStringFormChooser([
          [0, 0],
        ]).moveto().operator,
        vmoveto,
      );
      expect(
        const CharStringFormChooser([
          [0, 0],
        ]).moveto().operandIndices,
        [1],
      );
    });

    test('lineto keeps both deltas when neither is zero', () {
      expect(
        const CharStringFormChooser([
          [5, 6],
        ]).lineto().operandIndices,
        [0, 1],
      );
    });

    test('curveto throws unless every master supplies six deltas', () {
      expect(
        () => const CharStringFormChooser([
          [1, 2, 3, 4, 5],
        ]).curveto(),
        throwsArgumentError,
      );
      expect(
        () => const CharStringFormChooser([
          [1, 2, 3, 4, 5, 6],
          [1, 2, 3, 4, 5],
        ]).curveto(),
        throwsArgumentError,
      );
    });

    test('curveto falls back to rrcurveto when no final delta is zero', () {
      final form = const CharStringFormChooser([
        [1, 2, 3, 4, 5, 6],
      ]).curveto();

      expect(form.operator, rrcurveto);
      expect(form.operandIndices, [0, 1, 2, 3, 4, 5]);
    });

    test('curveto prefers vvcurveto when both final deltas are zero', () {
      expect(
        const CharStringFormChooser([
          [1, 2, 3, 4, 0, 0],
        ]).curveto().operator,
        vvcurveto,
      );
    });
  });
}
