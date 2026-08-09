class FontifyException implements Exception {
  FontifyException(this.message);

  final String message;

  @override
  String toString() => message;
}

const kLegacyConfigMessage = '''
Legacy flat fontify_plus config is no longer supported. Use named fonts:

fontify_plus:
  defaults:
    recursive: true
  fonts:
    icons:
      input_svg_dir: assets/icons/
      output_font_file: fonts/icons.otf
''';
