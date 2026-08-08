final _illegal = RegExp(r'[^a-zA-Z0-9_$]');
final _fromFirstLegalStart = RegExp(r'^[a-zA-Z$].*');

/// [source] reduced to a legal Dart identifier, or the empty string when
/// nothing legal survives.
///
/// Characters an identifier may not contain are removed, then anything before
/// the first character an identifier may start with is dropped — an identifier
/// cannot begin with a digit.
String toDartIdentifier(String source) {
  final legal = source.replaceAll(_illegal, '');

  return _fromFirstLegalStart.firstMatch(legal)?.group(0) ?? '';
}
