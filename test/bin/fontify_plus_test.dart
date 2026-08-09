import 'dart:io';

import 'package:test/test.dart';

/// Runs the real CLI executable as a subprocess — `main()` calls `exit()` on
/// nearly every path, so it cannot be invoked in-process without killing the
/// test runner.
Future<ProcessResult> _runCli(List<String> args) => Process.run(
  Platform.executable,
  ['run', 'bin/fontify_plus.dart', ...args],
);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fontify_plus_bin_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('fontify_plus CLI', () {
    test('--help prints usage and exits with code 0', () async {
      final result = await _runCli(['--help']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('Usage:'));
    });

    test(
      'no positional args prints a usage error and exits with code 64',
      () async {
        final result = await _runCli([]);

        expect(result.exitCode, 64);
        expect(result.stdout, contains('Usage:'));
      },
    );

    test('a non-existent input directory exits with code 65', () async {
      final result = await _runCli([
        '${tempDir.path}/does_not_exist',
        '${tempDir.path}/font.otf',
      ]);

      expect(result.exitCode, 65);
    });

    test('converts a real SVG directory into an .otf file', () async {
      final fontPath = '${tempDir.path}/icons.otf';

      final result = await _runCli(['test/assets/svg', fontPath]);

      expect(result.exitCode, 0);
      expect(File(fontPath).existsSync(), isTrue);
      expect(File(fontPath).lengthSync(), greaterThan(0));
    });

    test('--output-class-file also generates a Flutter class', () async {
      final fontPath = '${tempDir.path}/icons.otf';
      final classPath = '${tempDir.path}/icons.dart';

      final result = await _runCli([
        'test/assets/svg',
        fontPath,
        '--output-class-file=$classPath',
        '--class-name=MyIcons',
      ]);

      expect(result.exitCode, 0);
      expect(File(classPath).existsSync(), isTrue);
      expect(File(classPath).readAsStringSync(), contains('class MyIcons'));
    });
  });
}
