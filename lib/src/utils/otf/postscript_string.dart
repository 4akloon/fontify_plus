extension OTFStringExt on String {
  /// Returns ASCII-printable string
  String getAsciiPrintable() =>
      replaceAll(RegExp(r'([^\x00-\x7E]|[\(\[\]\(\)\{\}<>\/%])'), '');

  /// Returns ASCII-printable and PostScript-compatible string
  String getPostScriptString() =>
      getAsciiPrintable().replaceAll(RegExp(r'[^\x21-\x7E]'), '');
}
