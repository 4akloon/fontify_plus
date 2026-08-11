import 'char_string_command.dart';
import 'char_string_operand.dart';
import 'char_string_operator.dart';

/// Merges one glyph's per-master command streams into a single CFF2
/// charstring, inserting `blend` wherever the masters disagree.
///
/// [masters] must be structurally identical — same operators, same operand
/// counts — which is what `CharStringEncoder` guarantees. The first entry is
/// the default master, the one the `fvar` default instance selects; every
/// other entry contributes one region's deltas. [regionCount]
/// is `masters.length - 1`, a property of this object rather than a
/// recomputed local that must agree with a separately threaded argument.
///
/// A command whose operands agree in every master is emitted unchanged. That
/// is not only an optimisation: a filled icon does not vary with stroke width
/// at all, and paying one delta per value plus one trailing count per command
/// to say "and nothing changed" would put a cost on exactly the glyphs that
/// have nothing to vary.
///
/// When there are no regions (a single master), the returned list is the
/// default master's own list object, not a copy — callers must not mutate
/// it or the commands/operands it holds. The same aliasing applies to any
/// command that passes through unchanged when there are regions: it is the
/// default master's own [CharStringCommand], not a copy of it.
class CharStringBlender {
  CharStringBlender(this.masters) {
    if (masters.isEmpty) {
      throw ArgumentError('At least one master is required');
    }

    final defaultMaster = masters.first;

    for (final master in masters) {
      if (master.length != defaultMaster.length) {
        throw ArgumentError(
          'Masters must have the same command count: '
          '${defaultMaster.length} vs ${master.length}',
        );
      }
    }
  }

  /// Per-master command streams; first entry is the default master.
  final List<List<CharStringCommand>> masters;

  /// How many non-default masters contribute deltas.
  int get regionCount => masters.length - 1;

  /// Merges [masters] into one command stream with `blend` where needed.
  List<CharStringCommand> merge() {
    final defaultMaster = masters.first;
    final regionCount = this.regionCount;

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
      // The deltas are grouped by operand, region-minor (all of operand 0's
      // deltas, then all of operand 1's, and so on) — the ordering the CFF2
      // `blend` operator's specification describes and the one fontTools'
      // blend assembler produces. With a single region that ordering is
      // indistinguishable from the alternative (grouped by region), so it
      // could not have been checked by any test until a second region existed;
      // the three-master cases in char_string_blend_test.dart now exercise it
      // directly.
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
}
