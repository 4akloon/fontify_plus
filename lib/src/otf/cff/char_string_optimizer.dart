import 'char_string.dart';
import 'char_string_operator.dart';

/// Operators whose command draws nothing when all of its operands are zero.
const _curveToOperators = [
  rrcurveto,
  vvcurveto,
  hhcurveto,
  vhcurveto,
  hvcurveto,
];

class CharStringOptimizer {
  CharStringOptimizer(bool isCFF1, {int regionCount = 0})
    : _limits = CharStringInterpreterLimits(isCFF1, regionCount: regionCount);

  final CharStringInterpreterLimits _limits;

  /// Returns true, if the two commands can be written as one.
  ///
  /// Reads one master only: operators and operand counts are identical across
  /// masters, so the answer is too. The caller asserts that.
  bool _canCompactSameOperator(CharStringCommand prev, CharStringCommand next) {
    final mergedArgLength = prev.operandList.length + next.operandList.length;

    if (mergedArgLength > _limits.argumentStackLimit) {
      // Can't optimize because of argument stack limit
      return false;
    }

    if (prev.operator != next.operator) {
      // Different operators
      return false;
    }

    final op = next.operator;

    if (op == rlineto || op == rrcurveto) {
      return true;
    }

    if (op == hhcurveto || op == vvcurveto) {
      final prevHasDelta = prev.operandList.length % 4 != 0;
      final currHasDelta = next.operandList.length % 4 != 0;

      // A leading delta adjusts only the very first curve of the sequence it
      // is part of. Two independent commands each declaring one are two
      // separate one-time adjustments to two separate curves, not the same
      // value stated twice — dropping either loses that curve's own tangent,
      // even when the two values happen to be numerically equal. Merging is
      // only lossless when neither side has one to lose.
      return !prevHasDelta && !currHasDelta;
    }

    // hlineto/vlineto are deliberately not merged here: each is generated
    // as a fresh, self-contained single delta starting the h/x, v/y
    // alternation over again, so concatenating two of them either drops one
    // delta outright or reinterprets it on the wrong axis. There is no
    // combination that is both simpler and correct.
    return false;
  }

  /// Drops every command that is a curve drawing nothing in *every* master.
  ///
  /// A curve degenerate in one master but not another still has to be written
  /// by both, or the two command streams stop lining up.
  static List<List<CharStringCommand>> _dropEmptyCurves(
    List<List<CharStringCommand>> masters,
  ) {
    final keptIndices = [
      for (var i = 0; i < masters.first.length; i++)
        if (!_curveToOperators.contains(masters.first[i].operator) ||
            !masters.every(
              (commands) => commands[i].operandList.every((o) => o.value == 0),
            ))
          i,
    ];

    return [
      for (final commands in masters)
        [for (final i in keptIndices) commands[i]],
    ];
  }

  List<List<CharStringCommand>> _compactSameOperators(
    List<List<CharStringCommand>> masters,
  ) {
    if (masters.first.isEmpty) {
      return [for (final _ in masters) <CharStringCommand>[]];
    }

    final newCommandLists = [
      for (final commands in masters)
        <CharStringCommand>[commands.first.copy()],
    ];

    for (var i = 1; i < masters.first.length; i++) {
      assert(
        masters.every(
          (commands) =>
              commands[i].operator == masters.first[i].operator &&
              commands[i].operandList.length ==
                  masters.first[i].operandList.length,
        ),
        'Masters must agree on operator and operand count at command $i',
      );

      if (_canCompactSameOperator(
        newCommandLists.first.last,
        masters.first[i],
      )) {
        for (var m = 0; m < masters.length; m++) {
          newCommandLists[m].last.operandList.addAll(masters[m][i].operandList);
        }
      } else {
        for (var m = 0; m < masters.length; m++) {
          newCommandLists[m].add(masters[m][i].copy());
        }
      }
    }

    return newCommandLists;
  }

  List<CharStringCommand> optimize(List<CharStringCommand> commandList) =>
      optimizeMasters([commandList]).single;

  /// Optimizes every master in lockstep.
  ///
  /// Both passes below drop or merge commands based on their operand values,
  /// so running them per master would let the masters diverge — the exact
  /// failure the joint operator choice in `char_string_form.dart` exists to
  /// prevent. Every decision here is taken from all masters at once and
  /// applied to all of them.
  List<List<CharStringCommand>> optimizeMasters(
    List<List<CharStringCommand>> masters,
  ) {
    assert(masters.isNotEmpty, 'At least one master is required');
    assert(
      masters.every((commands) => commands.length == masters.first.length),
      'Masters must have the same number of commands',
    );

    return _compactSameOperators(_dropEmptyCurves(masters));
  }
}
