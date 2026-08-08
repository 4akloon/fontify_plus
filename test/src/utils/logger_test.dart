import 'dart:async';

import 'package:fontify_plus/src/utils/logger.dart';
import 'package:test/test.dart';

/// Runs [body] with `print` captured instead of written to stdout.
List<String> capturePrints(void Function() body) {
  final lines = <String>[];

  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );

  return lines;
}

void main() {
  group('Level', () {
    test('is ordered from most to least verbose', () {
      expect(Level.trace.index, lessThan(Level.debug.index));
      expect(Level.debug.index, lessThan(Level.info.index));
      expect(Level.info.index, lessThan(Level.warning.index));
      expect(Level.warning.index, lessThan(Level.error.index));
    });
  });

  group('Logger', () {
    test('defaults to info level', () {
      expect(Logger().level, Level.info);
    });

    test('shorthand methods do not throw at any level', () {
      final logger = Logger(level: Level.trace);

      expect(() {
        logger
          ..t('trace')
          ..d('debug')
          ..i('info')
          ..w('warning')
          ..e('error');
      }, returnsNormally);
    });

    test('level can be changed after construction', () {
      final logger = Logger()..level = Level.error;

      expect(logger.level, Level.error);
    });

    test('drops records below the configured level', () {
      final logger = Logger(level: Level.warning);

      final lines = capturePrints(() => logger.i('should not print'));

      expect(lines, isEmpty);
    });

    test('prints records at or above the configured level', () {
      final logger = Logger(level: Level.warning);

      final lines = capturePrints(() => logger.e('should print'));

      expect(lines, hasLength(1));
      expect(lines.single, contains('should print'));
    });

    test('logOnce prints a given message only the first time', () {
      final logger = Logger();

      final lines = capturePrints(() {
        for (var i = 0; i < 3; i++) {
          logger.logOnce(Level.warning, 'repeated message');
        }
      });

      expect(lines, hasLength(1));
    });

    test('logOnce tracks distinct messages independently', () {
      final logger = Logger();

      final lines = capturePrints(() {
        logger.logOnce(Level.warning, 'first');
        logger.logOnce(Level.warning, 'second');
      });

      expect(lines, hasLength(2));
    });

    test('the shared logger instance exists', () {
      expect(logger, isNotNull);
    });
  });
}
