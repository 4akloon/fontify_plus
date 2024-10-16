class EnumClass<K, V> {
  const EnumClass(this._map);

  final Map<K, V> _map;

  K? getKeyForValue(V value) {
    for (final entry in _map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }

    return null;
  }

  V? getValueForKey(K key) {
    return _map[key];
  }

  Iterable<K> get keys => _map.keys;

  Iterable<V> get values => _map.values;

  Iterable<MapEntry<K, V>> get entries => _map.entries;

  Map<K, V> get map => _map;

  V? operator [](K key) => _map[key];
}
