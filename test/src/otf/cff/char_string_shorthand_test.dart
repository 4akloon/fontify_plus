import 'package:fontify_plus/src/otf/cff/char_string_operator.dart';
import 'package:fontify_plus/src/otf/cff/char_string_shorthand.dart';
import 'package:test/test.dart';

void main() {
  group('shortestMoveto', () {
    test('drops dx when it is zero', () {
      final command = shortestMoveto(0, 5);

      expect(command.operator, vmoveto);
      expect(command.operandList.single.value, 5);
    });

    test('drops dy when it is zero', () {
      final command = shortestMoveto(5, 0);

      expect(command.operator, hmoveto);
      expect(command.operandList.single.value, 5);
    });

    test('keeps both when neither is zero', () {
      final command = shortestMoveto(5, 6);

      expect(command.operator, rmoveto);
      expect(command.operandList.map((o) => o.value), [5, 6]);
    });

    test('prefers vmoveto when both deltas are zero', () {
      expect(shortestMoveto(0, 0).operator, vmoveto);
    });
  });

  group('shortestLineto', () {
    test('drops dx when it is zero', () {
      expect(shortestLineto(0, 5).operator, vlineto);
    });

    test('drops dy when it is zero', () {
      expect(shortestLineto(5, 0).operator, hlineto);
    });

    test('keeps both when neither is zero', () {
      final command = shortestLineto(5, 6);

      expect(command.operator, rlineto);
      expect(command.operandList.map((o) => o.value), [5, 6]);
    });
  });

  group('shortestCurveto', () {
    test('throws unless given exactly six deltas', () {
      expect(() => shortestCurveto([1, 2, 3, 4, 5]), throwsArgumentError);
    });

    test('uses vvcurveto when the final dx is zero', () {
      final command = shortestCurveto([1, 2, 3, 4, 0, 6]);

      expect(command.operator, vvcurveto);
    });

    test('folds the leading dx into vvcurveto\'s optional argument', () {
      // dlist[0]=1 (dx1) survives as the leading operand once dx1..dx3, dy3's
      // zero are dropped.
      final command = shortestCurveto([1, 2, 3, 4, 0, 6]);

      expect(command.operandList.map((o) => o.value), [1, 2, 3, 4, 6]);
    });

    test('drops the leading dx from vvcurveto when it is also zero', () {
      final command = shortestCurveto([0, 2, 3, 4, 0, 6]);

      expect(command.operandList.map((o) => o.value), [2, 3, 4, 6]);
    });

    test('uses hhcurveto when the final dy is zero', () {
      final command = shortestCurveto([1, 2, 3, 4, 5, 0]);

      expect(command.operator, hhcurveto);
    });

    test('folds the leading dy into hhcurveto\'s optional argument', () {
      final command = shortestCurveto([1, 2, 3, 4, 5, 0]);

      expect(command.operandList.map((o) => o.value), [2, 1, 3, 4, 5]);
    });

    test('falls back to rrcurveto when neither final delta is zero', () {
      final command = shortestCurveto([1, 2, 3, 4, 5, 6]);

      expect(command.operator, rrcurveto);
      expect(command.operandList.map((o) => o.value), [1, 2, 3, 4, 5, 6]);
    });

    test('prefers vvcurveto when both final deltas are zero', () {
      expect(shortestCurveto([1, 2, 3, 4, 0, 0]).operator, vvcurveto);
    });
  });
}
