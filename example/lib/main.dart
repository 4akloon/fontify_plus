import 'package:flutter/material.dart';
import 'package:fontify_plus_example/my_icons.dart';

void main() {
  runApp(const FontifyPlusExampleApp());
}

class FontifyPlusExampleApp extends StatelessWidget {
  const FontifyPlusExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fontify_plus example',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1B4D3E),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1A1A1A),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const IconGalleryPage(),
    );
  }
}

class IconGalleryPage extends StatelessWidget {
  const IconGalleryPage({super.key});

  static const _icons = <(String, IconData)>[
    ('arrowRight', MyIcons.arrowRight),
    ('plus', MyIcons.plus),
    ('check', MyIcons.check),
    ('menu', MyIcons.menu),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('fontify_plus', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Icons generated from example/svg via dart run tool/generate.dart',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  for (final (name, icon) in _icons)
                    SizedBox(
                      width: 96,
                      child: Column(
                        children: [
                          Icon(icon, size: 40),
                          const SizedBox(height: 8),
                          Text(name, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
