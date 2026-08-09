import 'char_string.dart';
import 'char_string_operator.dart';

class CharStringOptimizer {
  CharStringOptimizer(bool isCFF1)
    : _limits = CharStringInterpreterLimits(isCFF1);

  final CharStringInterpreterLimits _limits;

  /// Returns true, if commands were compacted
  bool _tryToCompactSameOperator(
    CharStringCommand prev,
    CharStringCommand next,
  ) {
    final prevOpnds = prev.operandList;
    final currOpnds = next.operandList;

    final mergedArgLength = prevOpnds.length + currOpnds.length;

    if (mergedArgLength > _limits.argumentStackLimit) {
      // Can't optimize because of argument stack limit
      return false;
    }

    if (prev.operator != next.operator) {
      // Different operators
      return false;
    }

    final op = next.operator;

    if (op == rlineto) {
      prevOpnds.addAll(currOpnds);
      return true;
    } else if (op == rrcurveto) {
      prevOpnds.addAll(currOpnds);
      return true;
    } else if (op == hhcurveto || op == vvcurveto) {
      final prevHasDelta = prevOpnds.length % 4 != 0;
      final currHasDelta = currOpnds.length % 4 != 0;

      // A leading delta adjusts only the very first curve of the sequence it
      // is part of. Two independent commands each declaring one are two
      // separate one-time adjustments to two separate curves, not the same
      // value stated twice — dropping either loses that curve's own tangent,
      // even when the two values happen to be numerically equal. Merging is
      // only lossless when neither side has one to lose.
      if (!prevHasDelta && !currHasDelta) {
        prevOpnds.addAll(currOpnds);
        return true;
      }
    }

    // hlineto/vlineto are deliberately not merged here: each is generated
    // as a fresh, self-contained single delta starting the h/x, v/y
    // alternation over again, so concatenating two of them either drops one
    // delta outright or reinterprets it on the wrong axis. There is no
    // combination that is both simpler and correct.
    return false;
  }

  static List<CharStringCommand> _optimizeEmpty(
    List<CharStringCommand> commandList,
  ) {
    return commandList.where((e) {
      final everyOperandIsZero = e.operandList.every((o) => o.value == 0);
      final isCurveToOperator = [
        rrcurveto,
        vvcurveto,
        hhcurveto,
        vhcurveto,
        hvcurveto,
      ].contains(e.operator);

      if (isCurveToOperator) {
        return !everyOperandIsZero;
      }

      return true;
    }).toList();
  }

  List<CharStringCommand> _optimizeCommandsWithSameOperators(
    List<CharStringCommand> commandList,
  ) {
    if (commandList.isEmpty) {
      return [];
    }

    final newCommandList = <CharStringCommand>[commandList.first.copy()];

    for (var i = 1; i < commandList.length; i++) {
      final prev = newCommandList.last;
      final next = commandList[i].copy();

      final optimized = _tryToCompactSameOperator(prev, next);
      if (!optimized) {
        newCommandList.add(next);
      }
    }

    return newCommandList;
  }

  List<CharStringCommand> optimize(List<CharStringCommand> commandList) {
    return _optimizeCommandsWithSameOperators(_optimizeEmpty(commandList));
  }
}
