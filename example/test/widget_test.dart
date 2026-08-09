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
    const galleryKey = Key('gallery-shot');

    // Sharp PNG for pub.dev; logical crop stays content-sized.
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);

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
        home: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.white,
            child: KeyedSubtree(
              key: galleryKey,
              child: const _GalleryShot(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contentSize = tester.getSize(find.byKey(galleryKey));
    await tester.binding.setSurfaceSize(contentSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(galleryKey),
      matchesGoldenFile('goldens/example_gallery.png'),
    );

    final golden = File('test/goldens/example_gallery.png');
    final dest = File('../screenshots/example_gallery.png');
    dest.parent.createSync(recursive: true);
    golden.copySync(dest.path);
  });
}

/// Same content as [IconGalleryPage], but shrink-wrapped for a tight crop.
class _GalleryShot extends StatelessWidget {
  const _GalleryShot();

  static const _icons = IconGalleryPage.icons;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('fontify_plus', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Icons generated from example/svg via dart run tool/generate.dart',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _icons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 24),
                  SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        Icon(_icons[i].$2, size: 40),
                        const SizedBox(height: 8),
                        Text(_icons[i].$1, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
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
