import 'package:fontify_plus/src/otf/cff/char_string_command.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operand.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/char_string_optimizer.dart';
import 'package:test/test.dart';

/// Traces the absolute end point of a moveto/lineto-only command list.
///
/// Enough of a charstring interpreter to check that optimizing a command
/// list does not change what it draws — moveto/rlineto/hlineto/vlineto are
/// the only operators any of the tests below need.
(num, num) traceEndPoint(List<CharStringCommand> commands) {
  num x = 0;
  num y = 0;

  for (final command in commands) {
    final values = command.operandList.map((o) => o.value!).toList();

    if (command.operator == rmoveto) {
      x += values[0];
      y += values[1];
    } else if (command.operator == hmoveto) {
      x += values[0];
    } else if (command.operator == vmoveto) {
      y += values[0];
    } else if (command.operator == rlineto) {
      for (var i = 0; i < values.length; i += 2) {
        x += values[i];
        y += values[i + 1];
      }
    } else if (command.operator == hlineto || command.operator == vlineto) {
      var isX = command.operator == hlineto;

      for (final v in values) {
        if (isX) {
          x += v;
        } else {
          y += v;
        }

        isX = !isX;
      }
    } else {
      throw UnsupportedError('traceEndPoint cannot interpret $command');
    }
  }

  return (x, y);
}

void main() {
  group('CharStringOptimizer — dropping degenerate curves', () {
    test('drops an all-zero curveto', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rrcurveto([0, 0, 0, 0, 0, 0]),
      ]);

      expect(result, isEmpty);
    });

    test('keeps an all-zero moveto or lineto', () {
      // Only curveto operators are filtered; a zero move or line is left
      // alone even though it draws nothing either.
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rmoveto(0, 0),
        CharStringCommand.rlineto([0, 0]),
      ]);

      expect(result, hasLength(2));
    });

    test('keeps a curveto with any non-zero operand', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rrcurveto([0, 0, 0, 0, 1, 0]),
      ]);

      expect(result, hasLength(1));
    });

    test('an all-zero vhcurveto/hvcurveto is also dropped', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand(
          vhcurveto,
          [for (var i = 0; i < 4; i++) CharStringOperand(0)],
        ),
      ]);

      expect(result, isEmpty);
    });
  });

  group('CharStringOptimizer — merging same-operator commands', () {
    test('merges two consecutive rlineto into one', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rlineto([1, 2]),
        CharStringCommand.rlineto([3, 4]),
      ]);

      expect(result, hasLength(1));
      expect(result.single.operandList.map((o) => o.value), [1, 2, 3, 4]);
    });

    test('merges two consecutive rrcurveto into one', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rrcurveto([1, 2, 3, 4, 5, 6]),
        CharStringCommand.rrcurveto([7, 8, 9, 10, 11, 12]),
      ]);

      expect(result, hasLength(1));
      expect(result.single.operandList.map((o) => o.value), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ]);
    });

    test('does not merge commands with different operators', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rlineto([1, 2]),
        CharStringCommand.hmoveto(5),
      ]);

      expect(result, hasLength(2));
    });

    test('does not merge past the CFF1 argument stack limit', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.rlineto(List.filled(40, 1)),
        CharStringCommand.rlineto(List.filled(10, 1)),
      ]);

      // 40 + 10 = 50 exceeds CFF1's 48-operand limit.
      expect(result, hasLength(2));
    });

    test('the same merge is allowed under the wider CFF2 limit', () {
      final optimizer = CharStringOptimizer(false);
      final result = optimizer.optimize([
        CharStringCommand.rlineto(List.filled(40, 1)),
        CharStringCommand.rlineto(List.filled(10, 1)),
      ]);

      expect(result, hasLength(1));
    });

    test('merges hhcurveto commands that neither carry a leading delta', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.hhcurveto([1, 2, 3, 4]),
        CharStringCommand.hhcurveto([5, 6, 7, 8]),
      ]);

      expect(result, hasLength(1));
      expect(
        result.single.operandList.map((o) => o.value),
        [1, 2, 3, 4, 5, 6, 7, 8],
      );
    });

    test(
      'does not merge hhcurveto when only one side carries a leading delta',
      () {
        final optimizer = CharStringOptimizer(true);
        final result = optimizer.optimize([
          CharStringCommand.hhcurveto([9, 1, 2, 3, 4]),
          CharStringCommand.hhcurveto([5, 6, 7, 8]),
        ]);

        expect(result, hasLength(2));
      },
    );

    test('does not merge hhcurveto when both sides have a leading delta, '
        'even if the values are equal', () {
      // A leading delta adjusts only the first curve of the sequence it is
      // part of. Merging would keep prev's adjustment but silently drop
      // curr's — corrupting curr's own curve's tangent — regardless of
      // whether the two values happen to match.
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.hhcurveto([9, 1, 2, 3, 4]),
        CharStringCommand.hhcurveto([9, 5, 6, 7, 8]),
      ]);

      expect(result, hasLength(2));
    });

    test('does not merge hhcurveto when leading deltas differ', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.hhcurveto([9, 1, 2, 3, 4]),
        CharStringCommand.hhcurveto([7, 5, 6, 7, 8]),
      ]);

      expect(result, hasLength(2));
    });

    test('merges vvcurveto by the same rule as hhcurveto', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.vvcurveto([1, 2, 3, 4]),
        CharStringCommand.vvcurveto([5, 6, 7, 8]),
      ]);

      expect(result, hasLength(1));
    });

    test('never merges two hlineto commands, even with equal deltas', () {
      // Each hlineto is a fresh, self-contained delta. Concatenating two
      // singleton hlineto operand lists into one command would reinterpret
      // the second delta as a vertical move under hlineto's alternation —
      // there is no way to merge these two commands without changing what
      // they draw, regardless of whether the values happen to match.
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.hlineto(5),
        CharStringCommand.hlineto(5),
      ]);

      expect(result, hasLength(2));
    });

    test('optimizing never changes where two equal-delta hlinetos end up', () {
      // Regression guard: a prior version of this merge matched the two
      // deltas, kept only one, and dropped the other — silently halving the
      // total horizontal travel. Traced through both the original and the
      // optimized command list, the end point must be identical.
      final commands = [
        CharStringCommand.rmoveto(0, 0),
        CharStringCommand.hlineto(5),
        CharStringCommand.hlineto(5),
      ];

      final optimized = CharStringOptimizer(true).optimize(commands);

      expect(traceEndPoint(optimized), traceEndPoint(commands));
      expect(traceEndPoint(commands), (10, 0));
    });

    test('never merges two vlineto commands, by the same reasoning', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.vlineto(5),
        CharStringCommand.vlineto(5),
      ]);

      expect(result, hasLength(2));
    });

    test('does not merge across different operators, hlineto with vlineto', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([
        CharStringCommand.hlineto(5),
        CharStringCommand.vlineto(6),
      ]);

      expect(result, hasLength(2));
    });

    test('leaves a single command alone', () {
      final optimizer = CharStringOptimizer(true);
      final result = optimizer.optimize([CharStringCommand.hmoveto(5)]);

      expect(result, hasLength(1));
    });

    test('returns nothing for an empty command list', () {
      expect(CharStringOptimizer(true).optimize([]), isEmpty);
    });

    test('does not mutate the commands it was given', () {
      final original = CharStringCommand.rlineto([1, 2]);
      final originalOperandCount = original.operandList.length;

      CharStringOptimizer(true).optimize([
        original,
        CharStringCommand.rlineto([3, 4]),
      ]);

      expect(original.operandList, hasLength(originalOperandCount));
    });
  });
}
