class TableDataFormatException implements Exception {
  TableDataFormatException(this.message);

  final String message;

  @override
  String toString() => 'Table data format exception: $message';
}

class ChecksumException implements Exception {
  ChecksumException(this.entityName);
  ChecksumException.font() : entityName = 'font';
  ChecksumException.table(String tableName) : entityName = '$tableName table';

  final String entityName;

  @override
  String toString() => 'Wrong checksum for $entityName';
}

class SvgParserException implements Exception {
  SvgParserException([this.message]);

  final String? message;

  @override
  String toString() => 'SvgParserException($message)';
}

/// Thrown when two masters of the same glyph do not share a topology.
///
/// Variation deltas are per point, so masters that disagree on how many points
/// they have cannot be interpolated. Reaching this means a width-dependent
/// decision escaped the stroke plan; failing the build is the only honest
/// outcome, because the alternative is a font that renders subtly wrong.
class IncompatibleMastersException implements Exception {
  IncompatibleMastersException(this.glyphName, this.detail);

  final String glyphName;
  final String detail;

  @override
  String toString() => 'Incompatible masters for glyph "$glyphName": $detail';
}
