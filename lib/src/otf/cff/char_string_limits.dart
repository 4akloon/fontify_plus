/// Interpreter limits the CFF specification places on a charstring.
class CharStringInterpreterLimits {
  factory CharStringInterpreterLimits(bool isCFF1) => isCFF1
      ? const CharStringInterpreterLimits._cff1()
      : const CharStringInterpreterLimits._cff2();

  const CharStringInterpreterLimits._cff1() : argumentStackLimit = 48;

  const CharStringInterpreterLimits._cff2() : argumentStackLimit = 513;

  /// How many operands may be on the argument stack at once.
  ///
  /// A command with more operands than this has to be split, which is what the
  /// charstring optimizer uses this for.
  final int argumentStackLimit;
}
