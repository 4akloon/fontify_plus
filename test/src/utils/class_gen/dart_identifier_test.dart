import 'package:fontify_plus/src/utils/class_gen/dart_identifier.dart';
import 'package:test/test.dart';

void main() {
  group('toDartIdentifier', () {
    test('leaves an already-legal identifier untouched', () {
      expect(toDartIdentifier('arrowUp'), 'arrowUp');
    });

    test('strips characters an identifier may not contain', () {
      expect(toDartIdentifier('arrow-up!'), 'arrowup');
    });

    test('keeps underscores and dollar signs, which are legal', () {
      expect(toDartIdentifier(r'a_b$c'), r'a_b$c');
    });

    test('drops everything before the first legal starting character', () {
      // An identifier cannot start with a digit.
      expect(toDartIdentifier('02_icon'), 'icon');
    });

    test('drops a leading underscore rather than starting there', () {
      // This feeds a generated public class; a leading underscore would make
      // that one member library-private by accident.
      expect(toDartIdentifier('_private'), 'private');
    });

    test('drops a leading run of underscores the same way', () {
      expect(toDartIdentifier('__private'), 'private');
    });

    test('keeps a leading dollar sign', () {
      expect(toDartIdentifier(r'$special'), r'$special');
    });

    test('returns empty when nothing legal survives', () {
      expect(toDartIdentifier('123'), '');
    });

    test('returns empty for an empty string', () {
      expect(toDartIdentifier(''), '');
    });
  });
}
