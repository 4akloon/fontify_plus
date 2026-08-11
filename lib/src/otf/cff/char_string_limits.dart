/// Interpreter limits the CFF specification places on a charstring.
class CharStringInterpreterLimits {
  factory CharStringInterpreterLimits(bool isCFF1, {int regionCount = 0}) {
    if (isCFF1) {
      return const CharStringInterpreterLimits._(48);
    }

    if (regionCount == 0) {
      return const CharStringInterpreterLimits._(_kCFF2StackSize);
    }

    // A blended command puts n base values, n * k deltas and the count n on
    // the stack at once, so it fits only while n * (k + 1) + 1 <= 513. The
    // optimizer merges adjacent commands up to this limit, so the limit is
    // where the constraint has to be applied: without it a long merged
    // rrcurveto encodes fine and then overflows the interpreter at render
    // time, on someone else's machine.
    return CharStringInterpreterLimits._(
      (_kCFF2StackSize - 1) ~/ (regionCount + 1),
    );
  }

  const CharStringInterpreterLimits._(this.argumentStackLimit);

  /// How many operands may be on the argument stack at once.
  ///
  /// A command with more operands than this has to be split, which is what the
  /// charstring optimizer uses this for.
  final int argumentStackLimit;
}

const _kCFF2StackSize = 513;
