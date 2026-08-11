import 'char_string_command.dart';
import 'char_string_operand.dart';
import 'char_string_operator.dart';

/// Merges one glyph's per-master command streams into a single CFF2
/// charstring, inserting `blend` wherever the masters disagree.
///
/// [masters] must be structurally identical — same operators, same operand
/// counts — which is what `toCharStringCommandsForMasters` guarantees. The
/// first entry is the default master, the one the `fvar` default instance
/// selects; every other entry contributes one region's deltas.
///
/// A command whose operands agree in every master is emitted unchanged. That
/// is not only an optimisation: a filled icon does not vary with stroke width
/// at all, and paying two extra operands per value to say "and the delta is
/// zero" would put a cost on exactly the glyphs that have nothing to vary.
List<CharStringCommand> blendCommands(List<List<CharStringCommand>> masters) {
  if (masters.isEmpty) {
    throw ArgumentError('At least one master is required');
  }

  final defaultMaster = masters.first;
  final regionCount = masters.length - 1;

  for (final master in masters) {
    if (master.length != defaultMaster.length) {
      throw ArgumentError(
        'Masters must have the same command count: '
        '${defaultMaster.length} vs ${master.length}',
      );
    }
  }

  if (regionCount == 0) {
    return defaultMaster;
  }

  final out = <CharStringCommand>[];

  for (var i = 0; i < defaultMaster.length; i++) {
    final base = defaultMaster[i];
    final operandCount = base.operandList.length;

    for (final master in masters) {
      if (master[i].operator != base.operator ||
          master[i].operandList.length != operandCount) {
        throw ArgumentError(
          'Masters diverge at command $i: ${base.operator} with '
          '$operandCount operands vs ${master[i].operator} with '
          '${master[i].operandList.length}',
        );
      }
    }

    num deltaAt(int region, int operand) =>
        masters[region + 1][i].operandList[operand].value! -
        base.operandList[operand].value!;

    var varies = false;

    for (var r = 0; r < regionCount && !varies; r++) {
      for (var o = 0; o < operandCount; o++) {
        if (deltaAt(r, o) != 0) {
          varies = true;
          break;
        }
      }
    }

    if (!varies) {
      out.add(base);
      continue;
    }

    // n default values, then n * k deltas, then n, then the operator.
    //
    // With one region the two candidate orderings for those n * k deltas —
    // grouped by operand or grouped by region — are the same sequence, so
    // this cannot be got wrong today. Adding a second region makes them
    // differ: check the CFF2 specification's `blend` entry before doing so
    // rather than extending the loop below by symmetry.
    out
      ..add(
        CharStringCommand(blend, [
          ...base.operandList,
          for (var o = 0; o < operandCount; o++)
            for (var r = 0; r < regionCount; r++)
              CharStringOperand(deltaAt(r, o)),
          CharStringOperand(operandCount),
        ]),
      )
      // blend leaves the blended values on the stack; the drawing operator
      // takes them from there and needs no operands of its own.
      ..add(CharStringCommand(base.operator, const []));
  }

  return out;
}
