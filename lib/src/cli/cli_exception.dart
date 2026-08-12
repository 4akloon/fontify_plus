class CliArgumentException implements Exception {
  const CliArgumentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when `--help` is present, so the caller prints usage and stops.
class CliHelpException implements Exception {}
