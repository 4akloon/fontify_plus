import 'package:yaml/yaml.dart';

import 'font_job.dart';
import 'fontify_exception.dart';
import 'job_field.dart';
import 'job_values.dart';

/// Parsed multi-font configuration from a `fontify_plus:` YAML section.
class FontifyConfig {
  const FontifyConfig({required this.defaults, required this.fonts});

  final JobValues defaults;
  final Map<String, JobValues> fonts;

  /// Resolves jobs, optionally filtered to [fontFilter].
  List<FontJob> resolve({
    JobValues cliOverrides = const {},
    String? fontFilter,
  }) {
    if (fontFilter != null && !fonts.containsKey(fontFilter)) {
      throw FontifyException(
        'Unknown font "$fontFilter". Known: ${fonts.keys.join(', ')}.',
      );
    }

    final names = fontFilter != null ? [fontFilter] : fonts.keys;

    return [
      for (final name in names)
        resolveFontJob(
          name: name,
          layers: [defaults, fonts[name]!, cliOverrides],
        ),
    ];
  }

  /// Resolves [JobField.verbose] from defaults and [cliOverrides].
  bool resolveVerbose({JobValues cliOverrides = const {}}) {
    return resolveVerboseFromLayers([defaults, cliOverrides]);
  }
}

/// {@category api}
/// Parses a YAML document containing a `fontify_plus:` section.
FontifyConfig parseFontifyConfig(String yamlSource) {
  final dynamic root = loadYaml(yamlSource);

  if (root is! YamlMap) {
    throw const FontifyException('Config root must be a YAML map.');
  }

  final dynamic section = root['fontify_plus'];

  if (section is! YamlMap) {
    throw const FontifyException("Config must contain a 'fontify_plus' map.");
  }

  if (section.containsKey('input_svg_dir') ||
      section.containsKey('output_font_file')) {
    throw const FontifyException(kLegacyConfigMessage);
  }

  final dynamic fontsYaml = section['fonts'];
  if (fontsYaml is! YamlMap || fontsYaml.isEmpty) {
    throw const FontifyException(
      'fontify_plus.fonts must be a non-empty map of named font sets.',
    );
  }

  JobValues defaults = {};
  final dynamic defaultsYaml = section['defaults'];
  if (defaultsYaml != null) {
    if (defaultsYaml is! YamlMap) {
      throw const FontifyException('fontify_plus.defaults must be a map.');
    }
    defaults = jobValuesFromYamlMap(
      defaultsYaml,
      allowedFields: kJobDefaultsFields,
      context: 'defaults',
    );
  }

  final fonts = <String, JobValues>{};
  for (final e in fontsYaml.entries) {
    final name = e.key;
    final fontYaml = e.value;
    if (name is! String) {
      throw const FontifyException('fontify_plus.fonts keys must be strings.');
    }
    if (fontYaml is! YamlMap) {
      throw FontifyException('fontify_plus.fonts.$name must be a map.');
    }
    fonts[name] = jobValuesFromYamlMap(
      fontYaml,
      allowedFields: JobField.values.toSet(),
      context: 'fonts.$name',
    );
  }

  return FontifyConfig(defaults: defaults, fonts: fonts);
}

/// Returns parsed config when [yamlSource] has a `fontify_plus:` section.
FontifyConfig? tryParseFontifyConfig(String yamlSource) {
  final dynamic root = loadYaml(yamlSource);
  if (root is! YamlMap) {
    return null;
  }
  final dynamic section = root['fontify_plus'];
  if (section is! YamlMap) {
    return null;
  }
  return parseFontifyConfig(yamlSource);
}
