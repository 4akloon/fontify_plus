import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontify_plus_example/main.dart';
import 'package:fontify_plus_example/my_icons.dart';

/// Writes the example gallery into repo-root `screenshots/example_gallery.png`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final data = await rootBundle.load('fonts/my_icons.otf');
    final loader = FontLoader(MyIcons.iconFontFamily)..addFont(Future.value(data));
    await loader.load();
  });

  testWidgets('write example gallery screenshot', (tester) async {
    // Tight frame: header + one icon row, no empty lower third.
    await tester.binding.setSurfaceSize(const Size(720, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
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
