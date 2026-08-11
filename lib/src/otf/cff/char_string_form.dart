import 'char_string_operator.dart';
import 'operator.dart';

/// Which operator a segment takes, and which of its deltas get written.
///
/// Decided once for every master of a glyph, never per master. Two masters
/// that chose different operators could not be blended: `blend` supplies
/// deltas for the operands of one operator, so the operator itself has to be
/// the same in both.
class CharStringForm {
  const CharStringForm(this.operator, this.operandIndices);

  final CFFOperator operator;

  /// Indices into the segment's flat delta list, in write order.
  ///
  /// An index list rather than a count, because the compact `vv`/`hh` forms
  /// also *reorder* — they move the surviving leading delta to the front.
  final List<int> operandIndices;
}

/// Whether component [i] of the segment is zero in every master.
///
/// The shorthand forms do not merely spell a segment more briefly: they encode
/// the dropped component as an implicit zero. Taking one because the reference
/// master happens to be axis-aligned would silently discard whatever the other
/// master actually moves along that axis.
bool _zeroInEvery(List<List<int>> deltas, int i) =>
    deltas.every((master) => master[i] == 0);

/// The shortest charstring form of a move.
CharStringForm movetoForm(List<List<int>> deltas) {
  if (_zeroInEvery(deltas, 0)) {
    return const CharStringForm(vmoveto, [1]);
  }

  if (_zeroInEvery(deltas, 1)) {
    return const CharStringForm(hmoveto, [0]);
  }

  return const CharStringForm(rmoveto, [0, 1]);
}

/// The shortest charstring form of a line, by the same rule as [movetoForm].
CharStringForm linetoForm(List<List<int>> deltas) {
  if (_zeroInEvery(deltas, 0)) {
    return const CharStringForm(vlineto, [1]);
  }

  if (_zeroInEvery(deltas, 1)) {
    return const CharStringForm(hlineto, [0]);
  }

  return const CharStringForm(rlineto, [0, 1]);
}

/// The shortest charstring form of a cubic segment.
///
/// When the final delta moves along one axis only, the zero can be dropped and
/// the `vv`/`hh` form used, which also folds the first delta into that form's
/// single optional leading argument.
CharStringForm curvetoForm(List<List<int>> deltas) {
  if (deltas.any((master) => master.length != 6)) {
    throw ArgumentError('Each master must supply 6 deltas');
  }

  if (_zeroInEvery(deltas, 4)) {
    return CharStringForm(vvcurveto, _compact(deltas, zeroAt: 4, leadingAt: 0));
  }

  if (_zeroInEvery(deltas, 5)) {
    return CharStringForm(hhcurveto, _compact(deltas, zeroAt: 5, leadingAt: 1));
  }

  return const CharStringForm(rrcurveto, [0, 1, 2, 3, 4, 5]);
}

/// Drops the index at [zeroAt] and moves [leadingAt] to the front, or drops
/// that one too when it is zero in every master.
List<int> _compact(
  List<List<int>> deltas, {
  required int zeroAt,
  required int leadingAt,
}) {
  final rest = [
    for (var i = 0; i < 6; i++)
      if (i != zeroAt) i,
  ]..remove(leadingAt);

  return _zeroInEvery(deltas, leadingAt) ? rest : [leadingAt, ...rest];
}
