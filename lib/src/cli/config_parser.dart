import 'package:yaml/yaml.dart';

import '../utils/logger.dart';
import 'cli_argument.dart';

/// Parses config file.
///
/// Returns the arguments it declares, or null if the 'fontify_plus' key is not
/// present.
Map<CliArgument, dynamic>? parseConfig(String config) {
  final dynamic yamlMap = loadYaml(config);

  if (yamlMap is! YamlMap) {
    return null;
  }

  final dynamic fontifyYamlMap = yamlMap['fontify_plus'];

  if (fontifyYamlMap is! YamlMap) {
    return null;
  }

  return Map<CliArgument, dynamic>.fromEntries(
    fontifyYamlMap.entries
        .map(_mapConfigKeyEntry)
        .whereType<MapEntry<CliArgument, dynamic>>(),
  );
}

/// Maps one config entry onto its argument, warning about keys that match none.
MapEntry<CliArgument, dynamic>? _mapConfigKeyEntry(
  MapEntry<dynamic, dynamic> e,
) {
  final dynamic rawKey = e.key;

  void logUnknown() => logger.w('Unknown config parameter "$rawKey"');

  if (rawKey is! String) {
    logUnknown();
    return null;
  }

  final key = kConfigKeys.getKeyForValue(rawKey);

  if (key == null) {
    logUnknown();
    return null;
  }

  return MapEntry<CliArgument, dynamic>(key, e.value);
}

// Ignoring as CLI arguments are dynamically typed
// ignore_for_file: avoid_annotating_with_dynamic
