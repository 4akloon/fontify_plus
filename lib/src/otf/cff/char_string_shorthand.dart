import 'char_string_command.dart';

/// The shortest charstring form of a move.
///
/// A move along one axis only drops the other delta, saving an operand.
CharStringCommand shortestMoveto(int dx, int dy) {
  if (dx == 0) {
    return CharStringCommand.vmoveto(dy);
  }

  if (dy == 0) {
    return CharStringCommand.hmoveto(dx);
  }

  return CharStringCommand.rmoveto(dx, dy);
}

/// The shortest charstring form of a line, by the same rule as
/// [shortestMoveto].
CharStringCommand shortestLineto(int dx, int dy) {
  if (dx == 0) {
    return CharStringCommand.vlineto(dy);
  }

  if (dy == 0) {
    return CharStringCommand.hlineto(dx);
  }

  return CharStringCommand.rlineto([dx, dy]);
}

/// The shortest charstring form of a cubic segment.
///
/// When the final delta moves along one axis only, the zero can be dropped and
/// the `vv`/`hh` form used, which also folds the first delta into that form's
/// single optional leading argument.
CharStringCommand shortestCurveto(List<int> dlist) {
  if (dlist.length != 6) {
    throw ArgumentError('List length must be equal 6');
  }

  if (dlist[4] == 0) {
    return CharStringCommand.vvcurveto(
        _compact(dlist, zeroAt: 4, leadingAt: 0));
  }

  if (dlist[5] == 0) {
    return CharStringCommand.hhcurveto(
        _compact(dlist, zeroAt: 5, leadingAt: 1));
  }

  return CharStringCommand.rrcurveto(dlist);
}

/// Drops the zero delta at [zeroAt] and moves the delta at [leadingAt] to the
/// front, or drops that one too when it is itself zero.
List<int> _compact(
  List<int> dlist, {
  required int zeroAt,
  required int leadingAt,
}) {
  final rest = [...dlist]..removeAt(zeroAt);
  final leading = rest.removeAt(leadingAt);

  return leading == 0 ? rest : [leading, ...rest];
}
