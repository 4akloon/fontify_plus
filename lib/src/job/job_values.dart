import '../utils/logger.dart';
import 'font_job.dart';
import 'fontify_exception.dart';
import 'job_field.dart';

/// Raw config: field → value before coercion.
typedef JobValues = Map<JobField, Object?>;

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
    case JobField.preview:
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

  String requireString(JobField field) {
    final v = merged[field];
    if (v == null) {
      throw FontifyException("'${configKey(field)}' is required.");
    }
    return v as String;
  }

  final indent =
      merged[JobField.indent] as int? ??
      kJobBuiltInDefaults[JobField.indent]! as int;
  if (indent < 0) {
    throw FontifyException(
      'indent must be a non-negative integer, was $indent.',
    );
  }

  return FontJob(
    name: name,
    inputSvgDir: requireString(JobField.inputSvgDir),
    outputFontFile: requireString(JobField.outputFontFile),
    outputClassFile: merged[JobField.outputClassFile] as String?,
    className: merged[JobField.className] as String?,
    fontName: merged[JobField.fontName] as String?,
    package: merged[JobField.package] as String?,
    indent: indent,
    recursive:
        merged[JobField.recursive] as bool? ??
        kJobBuiltInDefaults[JobField.recursive]! as bool,
    normalize:
        merged[JobField.normalize] as bool? ??
        kJobBuiltInDefaults[JobField.normalize]! as bool,
    outlineStrokes:
        merged[JobField.outlineStrokes] as bool? ??
        kJobBuiltInDefaults[JobField.outlineStrokes]! as bool,
    preview:
        merged[JobField.preview] as bool? ??
        kJobBuiltInDefaults[JobField.preview]! as bool,
    useOpenType:
        merged[JobField.useOpenType] as bool? ??
        kJobBuiltInDefaults[JobField.useOpenType]! as bool,
  );
}

bool resolveVerboseFromLayers(Iterable<JobValues> layers) {
  final merged = coerceJobValues(mergeJobValues(layers));
  return merged[JobField.verbose] as bool? ??
      kJobBuiltInDefaults[JobField.verbose]! as bool;
}
