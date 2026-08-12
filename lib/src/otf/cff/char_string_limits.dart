/// Interpreter limits the CFF specification places on a charstring.
class CharStringInterpreterLimits {
  factory CharStringInterpreterLimits(bool isCFF1, {int regionCount = 0}) {
    assert(regionCount >= 0, 'regionCount must not be negative');

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

  /// How many operands a *pre-blend* command may carry.
  ///
  /// With `regionCount == 0` this is also the interpreter's real stack
  /// ceiling. With `regionCount > 0` it is smaller than that ceiling on
  /// purpose: blending a command of `n` operands expands it to
  /// `n * (regionCount + 1) + 1` operands on the stack, so this field caps
  /// `n` at whatever keeps that expansion within the true 513-operand limit,
  /// not at 513 itself. The charstring optimizer uses this to decide how much
  /// it may merge.
  final int argumentStackLimit;
}

const _kCFF2StackSize = 513;
