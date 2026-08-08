import 'package:fontify_plus/src/utils/enum_class.dart';
import 'package:test/test.dart';

enum _Fruit { apple, banana }

const _map = EnumClass<_Fruit, String>({
  _Fruit.apple: 'a',
  _Fruit.banana: 'b',
});

void main() {
  group('EnumClass', () {
    test('getValueForKey looks up by key', () {
      expect(_map.getValueForKey(_Fruit.apple), 'a');
    });

    test('getValueForKey returns null for a key not present', () {
      const partial = EnumClass<_Fruit, String>({_Fruit.apple: 'a'});

      expect(partial.getValueForKey(_Fruit.banana), isNull);
    });

    test('getKeyForValue looks up the other way', () {
      expect(_map.getKeyForValue('b'), _Fruit.banana);
    });

    test('getKeyForValue returns null for a value not present', () {
      expect(_map.getKeyForValue('z'), isNull);
    });

    test('operator[] is the same as getValueForKey', () {
      expect(_map[_Fruit.banana], _map.getValueForKey(_Fruit.banana));
    });

    test('keys, values and entries mirror the underlying map', () {
      expect(_map.keys, _map.map.keys);
      expect(_map.values, _map.map.values);
      expect(_map.entries.length, _map.map.entries.length);
    });
  });
}
