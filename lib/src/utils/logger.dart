/// Severity of a log record, from most to least verbose.
enum Level {
  trace,
  debug,
  info,
  warning,
  error,
}

/// Minimal levelled logger.
///
/// Records go through `print` rather than `dart:io`, so the package keeps
/// working on the web — the same reason its file access sits behind a
/// conditional `stub`/`io` export.
class Logger {
  Logger({this.level = Level.info});

  /// Records below this level are dropped.
  Level level;

  final Set<int> _loggedOnce = {};

  void t(Object message) => log(Level.trace, message);

  void d(Object message) => log(Level.debug, message);

  void i(Object message) => log(Level.info, message);

  void w(Object message) => log(Level.warning, message);

  void e(Object message) => log(Level.error, message);

  /// Logs [message] the first time it is seen and never again.
  ///
  /// Used for advisories about the icon set as a whole, which would otherwise
  /// repeat once per glyph.
  void logOnce(Level level, Object message) {
    if (!_loggedOnce.add(message.hashCode)) {
      return;
    }

    log(level, message);
  }

  void log(Level level, Object message) {
    if (level.index < this.level.index) {
      return;
    }

    // ignore: avoid_print
    print('[${level.name.toUpperCase()}] $message');
  }
}

final Logger logger = Logger();
