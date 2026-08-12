import 'package:fontify_plus/src/otf/cff/char_string_blend.dart';
import 'package:fontify_plus/src/otf/cff/char_string_command.dart';
import 'package:fontify_plus/src/otf/cff/char_string_limits.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operand.dart';
import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/char_string_optimizer.dart';
import 'package:fontify_plus/src/otf/cff/operator.dart';
import 'package:test/test.dart';

CharStringCommand _cmd(CFFOperator op, List<int> operands) => CharStringCommand(
  op,
  [for (final v in operands) CharStringOperand(v)],
);

void main() {
  group('CharStringBlender', () {
    test('a single master produces no blend at all', () {
      final out = CharStringBlender([
        [
          _cmd(rlineto, [10, 20]),
        ],
      ]).merge();

      expect(out.map((c) => c.operator), [rlineto]);
      expect(out.single.operandList.map((o) => o.value), [10, 20]);
    });

    test('identical masters produce no blend', () {
      // A fill does not vary with stroke width. Paying for a blend that is
      // all zeros would be pure size on every such command.
      final out = CharStringBlender([
        [
          _cmd(rlineto, [10, 20]),
        ],
        [
          _cmd(rlineto, [10, 20]),
        ],
      ]).merge();

      expect(out.map((c) => c.operator), [rlineto]);
      expect(out.single.operandList.map((o) => o.value), [10, 20]);
    });

    test('a differing command becomes blend followed by the operator', () {
      final out = CharStringBlender([
        [
          _cmd(rlineto, [10, 20]),
        ],
        [
          _cmd(rlineto, [13, 20]),
        ],
      ]).merge();

      expect(out.map((c) => c.operator), [blend, rlineto]);
      // n base values, then n * k deltas, then n. k == 1 here.
      expect(out[0].operandList.map((o) => o.value), [10, 20, 3, 0, 2]);
      // The operator consumes what blend left on the stack.
      expect(out[1].operandList, isEmpty);
    });

    test('deltas are measured from the first master, the default', () {
      final out = CharStringBlender([
        [
          _cmd(hlineto, [100]),
        ],
        [
          _cmd(hlineto, [90]),
        ],
      ]).merge();

      expect(out[0].operandList.map((o) => o.value), [100, -10, 1]);
    });

    test('an empty master list is rejected', () {
      expect(() => CharStringBlender([]), throwsArgumentError);
    });

    test('divergent structure is rejected', () {
      // Matcher for the per-command guard specifically: RangeError also
      // `is ArgumentError`, so a bare throwsArgumentError would still pass
      // if that guard were deleted and the missing bounds check crashed
      // instead. Pinning the message rules that out.
      final throwsDivergence = throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('diverge'),
        ),
      );

      // Operand counts differ (2 vs 1); the operators happen to differ too,
      // but this alone does not exercise the operator comparison, since the
      // operand-count comparison already trips first.
      expect(
        () => CharStringBlender([
          [
            _cmd(rlineto, [10, 20]),
          ],
          [
            _cmd(hlineto, [10]),
          ],
        ]).merge(),
        throwsDivergence,
      );

      // Operand counts agree (one operand each); only the operator differs.
      // This is the case that catches a guard weakened to check only operand
      // count — with the operator half deleted, CharStringBlender would emit
      // blend + hlineto and silently discard vlineto's y-move.
      expect(
        () => CharStringBlender([
          [
            _cmd(hlineto, [10]),
          ],
          [
            _cmd(vlineto, [30]),
          ],
        ]).merge(),
        throwsDivergence,
      );

      // Different command counts is a separate, earlier guard with its own
      // message, so it is checked only for ArgumentError in general.
      expect(
        () => CharStringBlender([
          [
            _cmd(rlineto, [10, 20]),
          ],
          [
            _cmd(rlineto, [10, 20]),
            _cmd(rlineto, [1, 1]),
          ],
        ]),
        throwsArgumentError,
      );
    });

    test(
      'three masters: the deltas are grouped by operand, region-minor',
      () {
        // A single-operand command. Region 1 (master index 1) matches the
        // default, region 2 (master index 2) does not.
        final out = CharStringBlender([
          [
            _cmd(hlineto, [10]),
          ],
          [
            _cmd(hlineto, [10]),
          ],
          [
            _cmd(hlineto, [11]),
          ],
        ]).merge();

        expect(out.map((c) => c.operator), [blend, hlineto]);
        // base, then region 1's delta (0), then region 2's delta (1), then
        // the operand count (1).
        expect(out[0].operandList.map((o) => o.value), [10, 0, 1, 1]);
        expect(out[1].operandList, isEmpty);
      },
    );

    test(
      'three masters, two operands: region-minor grouping within each '
      'operand',
      () {
        final out = CharStringBlender([
          [
            _cmd(rlineto, [10, 20]),
          ],
          [
            _cmd(rlineto, [12, 20]),
          ],
          [
            _cmd(rlineto, [10, 23]),
          ],
        ]).merge();

        expect(out.map((c) => c.operator), [blend, rlineto]);
        // base (10, 20), then operand 0's deltas across both regions
        // (2, 0), then operand 1's deltas across both regions (0, 3), then
        // the operand count (2).
        expect(out[0].operandList.map((o) => o.value), [
          10,
          20,
          2,
          0,
          0,
          3,
          2,
        ]);
        expect(out[1].operandList, isEmpty);
      },
    );

    test(
      'the region-aware stack limit keeps a real blend under the CFF2 '
      'ceiling',
      () {
        // 200 two-operand rlineto commands per master, with the two masters
        // differing on every operand, so every merged command actually
        // blends rather than collapsing back to the default via the
        // no-op-blend shortcut.
        List<CharStringCommand> master(int operand) => [
          for (var i = 0; i < 200; i++)
            CharStringCommand.rlineto([operand, operand]),
        ];

        final defaultMaster = master(1);
        final regionMaster = master(2);

        // Told apart from `regionCount: 0`: fed the region-blind limit,
        // the optimizer is happy to fold all 400 operands (200 commands *
        // 2 operands) into one command, because 400 <= 513.
        final unconstrained = CharStringOptimizer(
          false,
        ).optimizeMasters([defaultMaster]).single;
        expect(unconstrained, hasLength(1));
        expect(unconstrained.single.operandList, hasLength(400));

        // That single 400-operand command is exactly what must never reach
        // CharStringBlender once a region exists: blending it would need
        // 400 * 2 + 1 = 801 operands, well past the 513 a CFF2 interpreter
        // can hold.
        expect(400 * 2 + 1, greaterThan(513));

        // With one region declared, the optimizer instead stops merging at
        // or below 256 operands per command.
        final optimized = CharStringOptimizer(
          false,
          regionCount: 1,
        ).optimizeMasters([defaultMaster, regionMaster]);

        for (final command in optimized[0]) {
          expect(command.operandList.length, lessThanOrEqualTo(256));
        }

        // Blending that correctly-limited output is the real check: every
        // command differs between masters, so every one of them actually
        // becomes a blend, and its *actual* operand count — not the bound
        // recomputed from the limit constant — must still fit on the stack.
        final blended = CharStringBlender(optimized).merge();

        expect(blended, isNotEmpty);
        expect(blended.map((c) => c.operator), contains(blend));

        for (final command in blended) {
          if (command.operator == blend) {
            expect(command.operandList.length, lessThanOrEqualTo(513));
          }
        }

        // And the largest blend command actually reaches the boundary this
        // limit was built to protect, rather than staying comfortably below
        // it by accident.
        final blendOperandCounts = [
          for (final command in blended)
            if (command.operator == blend) command.operandList.length,
        ];
        expect(blendOperandCounts, contains(513));
      },
    );
  });

  group('argument stack limits', () {
    test('CFF2 without regions keeps the full stack', () {
      expect(CharStringInterpreterLimits(false).argumentStackLimit, 513);
    });

    test('one region halves it, because each operand carries a delta', () {
      // n bases + n * k deltas + the count must fit: n * (k + 1) + 1 <= 513.
      expect(
        CharStringInterpreterLimits(false, regionCount: 1).argumentStackLimit,
        256,
      );
      expect(256 * 2 + 1, lessThanOrEqualTo(513));
      expect(257 * 2 + 1, greaterThan(513));
    });

    test('two regions cut it to a third, and the -1 is load-bearing', () {
      // Reachable since three-master glyphs became legal. 512 ~/ 3 is 170,
      // not 171: the deltas alone would fit, but the operand count `blend`
      // pushes alongside them is what the -1 reserves room for. Dropping it
      // would yield 171, whose expansion is 514 — one over the ceiling, and
      // an overflow that only shows up in someone else's interpreter.
      expect(
        CharStringInterpreterLimits(false, regionCount: 2).argumentStackLimit,
        170,
      );
      expect(170 * 3 + 1, lessThanOrEqualTo(513));
      expect(171 * 3 + 1, greaterThan(513));
    });

    test('CFF1 is unaffected', () {
      expect(CharStringInterpreterLimits(true).argumentStackLimit, 48);
    });
  });
}
