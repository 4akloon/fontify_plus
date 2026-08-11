import '../utils/logger.dart';
import 'font_job.dart';
import 'fontify_exception.dart';
import 'job_field.dart';

/// Raw config: field → value before coercion.
typedef JobValues = Map<JobField, Object?>;

/// Typed reads over [JobValues].
///
/// [coerceJobValues] has already checked these types, but that check happens
/// through a `Map<JobField, Object?>`, so the compiler cannot carry it to the
/// reads — which is why every read used to end in `as bool?`. Re-checking
/// costs nothing at config sizes and buys the difference between a bare
/// `_TypeError` naming nothing and the same `FontifyException`, naming the
/// config key, that every other config mistake produces.
extension JobValueReaders on Map<JobField, Object?> {
  /// The boolean at [field], or null when the config does not set it.
  bool? readBool(JobField field) => _read<bool>(field, 'a boolean');

  /// The integer at [field], or null when the config does not set it.
  int? readInt(JobField field) => _read<int>(field, 'an integer');

  /// The string at [field], or null when the config does not set it.
  String? readString(JobField field) => _read<String>(field, 'a string');

  /// The boolean at [field], or a failure naming the config key.
  bool requireBool(JobField field) => readBool(field) ?? _missing(field);

  /// The integer at [field], or a failure naming the config key.
  int requireInt(JobField field) => readInt(field) ?? _missing(field);

  /// The string at [field], or a failure naming the config key.
  String requireString(JobField field) => readString(field) ?? _missing(field);

  T? _read<T>(JobField field, String expected) {
    final value = this[field];

    if (value == null) {
      return null;
    }

    if (value case final T typed) {
      return typed;
    }

    throw FontifyException(
      "'${configKey(field)}' must be $expected, got ${value.runtimeType}.",
    );
  }

  Never _missing(JobField field) =>
      throw FontifyException("'${configKey(field)}' is required.");
}

/// Merges [layers] left-to-right; later layers override earlier ones.
JobValues mergeJobValues(Iterable<JobValues> layers) {
  final merged = <JobField, Object?>{};
  for (final layer in layers) {
    merged.addAll(layer);
  }
  return merged;
}

/// Parses a YAML map into [JobValues], warning on unknown keys.
JobValues jobValuesFromYamlMap(
  Map<dynamic, dynamic> yamlMap, {
  required Set<JobField> allowedFields,
  String context = 'config',
}) {
  final values = <JobField, Object?>{};
  for (final e in yamlMap.entries) {
    final rawKey = e.key;
    if (rawKey is! String) {
      logger.w('Unknown $context parameter "$rawKey"');
      continue;
    }
    final field = jobFieldForConfigKey(rawKey);
    if (field == null || !allowedFields.contains(field)) {
      logger.w('Unknown $context parameter "$rawKey"');
      continue;
    }
    values[field] = e.value;
  }
  return values;
}

/// Coerces raw values into typed [JobValues] for job resolution.
JobValues coerceJobValues(JobValues raw) {
  final coerced = <JobField, Object?>{};
  for (final e in raw.entries) {
    coerced[e.key] = _coerceField(e.key, e.value);
  }
  return coerced;
}

Object? _coerceField(JobField field, Object? value) {
  if (value == null) {
    return null;
  }

  switch (field) {
    case JobField.inputSvgDir:
    case JobField.outputFontFile:
    case JobField.outputClassFile:
    case JobField.className:
    case JobField.package:
    case JobField.fontName:
      if (value is! String) {
        throw FontifyException(
          '${configKey(field)} must be a string, got ${value.runtimeType}.',
        );
      }
      return value;
    case JobField.indent:
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed == null) {
          throw FontifyException(
            "'${configKey(field)}' must be an integer, was \"$value\".",
          );
        }
        return parsed;
      }
      throw FontifyException(
        "'${configKey(field)}' must be an integer, got ${value.runtimeType}.",
      );
    case JobField.normalize:
    case JobField.outlineStrokes:
    case JobField.useOpenType:
    case JobField.recursive:
    case JobField.verbose:
      if (value is! bool) {
        throw FontifyException(
          "'${configKey(field)}' must be a boolean, got ${value.runtimeType}.",
        );
      }
      return value;
  }
}

/// Builds a resolved [FontJob] from merged layers.
FontJob resolveFontJob({
  String? name,
  required Iterable<JobValues> layers,
}) {
  final merged = coerceJobValues(mergeJobValues(layers));

  final indent =
      merged.readInt(JobField.indent) ??
      kJobBuiltInDefaults.requireInt(JobField.indent);
  if (indent < 0) {
    throw FontifyException(
      'indent must be a non-negative integer, was $indent.',
    );
  }

  return FontJob(
    name: name,
    inputSvgDir: merged.requireString(JobField.inputSvgDir),
    outputFontFile: merged.requireString(JobField.outputFontFile),
    outputClassFile: merged.readString(JobField.outputClassFile),
    className: merged.readString(JobField.className),
    fontName: merged.readString(JobField.fontName),
    package: merged.readString(JobField.package),
    indent: indent,
    recursive:
        merged.readBool(JobField.recursive) ??
        kJobBuiltInDefaults.requireBool(JobField.recursive),
    normalize:
        merged.readBool(JobField.normalize) ??
        kJobBuiltInDefaults.requireBool(JobField.normalize),
    outlineStrokes:
        merged.readBool(JobField.outlineStrokes) ??
        kJobBuiltInDefaults.requireBool(JobField.outlineStrokes),
    useOpenType:
        merged.readBool(JobField.useOpenType) ??
        kJobBuiltInDefaults.requireBool(JobField.useOpenType),
  );
}

bool resolveVerboseFromLayers(Iterable<JobValues> layers) {
  final merged = coerceJobValues(mergeJobValues(layers));
  return merged.readBool(JobField.verbose) ??
      kJobBuiltInDefaults.requireBool(JobField.verbose);
}
