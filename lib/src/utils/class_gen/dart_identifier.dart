final _illegal = RegExp(r'[^a-zA-Z0-9_$]');

/// Not anchored to the start: [toDartIdentifier] needs the first position
/// anywhere in the string that qualifies, so a leading run of digits gets
/// skipped rather than rejecting the whole string.
final _fromFirstLegalStart = RegExp(r'[a-zA-Z$].*');

/// [source] reduced to a legal Dart identifier, or the empty string when
/// nothing legal survives.
///
/// Characters an identifier may not contain are removed, then anything before
/// the first character an identifier may start with is dropped — an identifier
/// cannot begin with a digit. A leading underscore is dropped too, rather than
/// kept as a valid start: this feeds names into a generated public class, and
/// an underscore there would make that one member library-private by accident.
String toDartIdentifier(String source) {
  final legal = source.replaceAll(_illegal, '');

  return _fromFirstLegalStart.firstMatch(legal)?.group(0) ?? '';
}
