import 'package:path/path.dart' as p;

import '../string_case.dart';
import 'dart_identifier.dart';

const _kUnnamedIconName = 'unnamed';

/// Hands out unique lowerCamelCase identifiers for icon names.
///
/// Holds the names already handed out, so two files whose names normalize to
/// the same identifier cannot both claim it.
class IconNameAllocator {
  final _taken = <String>{};

  /// An identifier for [iconName], distinct from every one returned before.
  ///
  /// [iconName] may be a file name or a path relative to the input directory;
  /// any extension is dropped.
  String allocate(String iconName) {
    // Case conversion runs before sanitization: separators such as "-" and " "
    // are what mark word boundaries, and stripping them first would collapse
    // "arrow-up" to "arrowup" instead of "arrowUp".
    final stem = toDartIdentifier(
      p.withoutExtension(iconName.replaceAll(r'\', '/')).camelCase,
    );

    var name = stem.isEmpty ? _kUnnamedIconName : stem;

    if (_taken.contains(name)) {
      name = _disambiguate(name);
    }

    _taken.add(name);

    return name;
  }

  /// Appends a counter to [name] until it is free.
  ///
  /// The counter is appended directly rather than after an underscore, which
  /// would break lowerCamelCase again.
  ///
  /// Trailing digits already in [name] are deliberately not read as a counter:
  /// an icon named `alert_02` becomes `alert02`, and continuing from that `02`
  /// would hand the duplicate `alert03` — most likely a different icon in the
  /// same set.
  String _disambiguate(String name) {
    var count = 1;
    String candidate;

    do {
      candidate = '$name${++count}';
    } while (_taken.contains(candidate));

    return candidate;
  }
}
