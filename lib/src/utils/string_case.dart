/// Characters that mark a word boundary without being part of any word.
const _separators = {' ', '.', '/', '_', r'\', '-'};

final _upperCase = RegExp('[A-Z]');

/// Splits [source] into words on separators and camelCase humps.
///
/// An all-uppercase string is taken as a single word, so `SVG` yields one word
/// rather than three.
List<String> splitWords(String source) {
  final words = <String>[];
  final word = StringBuffer();

  // Applied to the whole string, not per word: only a string that is uppercase
  // throughout can be read as an acronym.
  final isAllCaps = source.toUpperCase() == source;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];

    if (_separators.contains(char)) {
      continue;
    }

    word.write(char);

    final next = i + 1 == source.length ? null : source[i + 1];
    final endsWord =
        next == null ||
        _separators.contains(next) ||
        (!isAllCaps && _upperCase.hasMatch(next));

    if (endsWord) {
      words.add(word.toString());
      word.clear();
    }
  }

  return words;
}

extension StringCaseExtension on String {
  /// This string in lowerCamelCase.
  ///
  /// Dart's convention for members and constants, and the shape the generated
  /// icon class needs so that it passes `constant_identifier_names` in the
  /// project that consumes it.
  String get camelCase {
    final words = splitWords(this);

    if (words.isEmpty) {
      return '';
    }

    final result = StringBuffer(words.first.toLowerCase());

    for (final word in words.skip(1)) {
      result
        ..write(word.substring(0, 1).toUpperCase())
        ..write(word.substring(1).toLowerCase());
    }

    return result.toString();
  }
}
