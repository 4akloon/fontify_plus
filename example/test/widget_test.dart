import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontify_plus_example/main.dart';
import 'package:fontify_plus_example/my_icons.dart';

/// Writes the example gallery into repo-root `screenshots/example_gallery.png`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Widget tests default to Ahem (tofu blocks). Load Roboto from the SDK
    // and the generated icon font for a readable pub.dev screenshot.
    await _loadFileFont('Roboto', _robotoPath());
    await _loadAssetFont(MyIcons.iconFontFamily, 'fonts/my_icons.otf');
  });

  testWidgets('write example gallery screenshot', (tester) async {
    // Tight frame: header + one icon row, no empty lower third.
    await tester.binding.setSurfaceSize(const Size(720, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B4D3E),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1A1A1A),
          ),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        home: const IconGalleryPage(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/example_gallery.png'),
    );

    final golden = File('test/goldens/example_gallery.png');
    final dest = File('../screenshots/example_gallery.png');
    dest.parent.createSync(recursive: true);
    golden.copySync(dest.path);
  });
}

String _robotoPath() {
  final which = Process.runSync('which', ['flutter']);
  if (which.exitCode != 0) {
    throw StateError('flutter not on PATH: ${which.stderr}');
  }
  final flutterBin = File(
    (which.stdout as String).trim(),
  ).resolveSymbolicLinksSync();
  // .../bin/flutter → SDK root
  final sdk = File(flutterBin).parent.parent.path;
  return '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
}

Future<void> _loadFileFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}

Future<void> _loadAssetFont(String family, String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}
