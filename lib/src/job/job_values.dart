import '../common/stroke_width_range.dart';
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

  /// The [StrokeWidthRange] at [field], or null when the config does not set
  /// it.
  StrokeWidthRange? readStrokeWidthRange(JobField field) =>
      _read<StrokeWidthRange>(field, 'a stroke width range');

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
    case JobField.strokeWidthRange:
      return _coerceStrokeWidthRange(field, value);
  }
}

/// Coerces a YAML list of two numbers, or a CLI `"min,max"` string, into a
/// [StrokeWidthRange].
///
/// [StrokeWidthRange]'s own constructor already rejects `min <= 0` and
/// `max <= min`, naming the offending value in an [ArgumentError]. That is
/// caught here and rethrown as a [FontifyException] naming the config key —
/// so a bad range in YAML reads like a config mistake, not a stack trace
/// surfacing from deep inside font generation.
StrokeWidthRange _coerceStrokeWidthRange(JobField field, Object value) {
  final List<Object?> rawValues;
  if (value is List) {
    rawValues = value;
  } else if (value is String) {
    rawValues = value.split(',');
  } else {
    throw FontifyException(
      "'${configKey(field)}' must be a two-element list (YAML) or a "
      "comma-separated 'min,max' pair (CLI), got ${value.runtimeType}.",
    );
  }

  if (rawValues.length != 2) {
    throw FontifyException(
      "'${configKey(field)}' must have exactly two values, got "
      '${rawValues.length}.',
    );
  }

  final endpoints = [
    for (final raw in rawValues) _coerceStrokeWidthEndpoint(field, raw),
  ];

  try {
    return StrokeWidthRange(endpoints[0], endpoints[1]);
    // StrokeWidthRange signals an invalid endpoint with ArgumentError, which
    // is an Error. Letting it escape would crash with a stack trace instead
    // of naming the config key a YAML mistake actually belongs to.
    // ignore: avoid_catching_errors
  } on ArgumentError catch (e) {
    throw FontifyException(
      "'${configKey(field)}': ${e.message} (was ${e.invalidValue}).",
    );
  }
}

double _coerceStrokeWidthEndpoint(JobField field, Object? raw) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = num.tryParse(raw.trim())?.toDouble();
  }

  if (value == null) {
    throw FontifyException(
      "'${configKey(field)}' values must be numbers, got \"$raw\".",
    );
  }

  // num.tryParse accepts "NaN" and "Infinity", and YAML's .nan/.inf arrive
  // as non-finite doubles directly. StrokeWidthRange's own min <= 0 / max <=
  // min guards do not catch every non-finite case (NaN <= 0 is false, and
  // Infinity as the low endpoint slips past both), so a non-finite value
  // must be rejected here to keep it a config error rather than an internal
  // one surfacing later, mid-font-generation.
  if (!value.isFinite) {
    throw FontifyException(
      "'${configKey(field)}' values must be finite numbers, got $value.",
    );
  }

  return value;
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

  // Hoisted so the conflict checks below and the FontJob constructor read
  // the same resolved value instead of resolving each field twice.
  final outlineStrokes =
      merged.readBool(JobField.outlineStrokes) ??
      kJobBuiltInDefaults.requireBool(JobField.outlineStrokes);
  final useOpenType =
      merged.readBool(JobField.useOpenType) ??
      kJobBuiltInDefaults.requireBool(JobField.useOpenType);

  final strokeWidthRange = merged.readStrokeWidthRange(
    JobField.strokeWidthRange,
  );

  if (strokeWidthRange != null) {
    // Checked here rather than relying solely on svgToOtf's own validation
    // so the message can name the YAML keys the user actually wrote
    // ('stroke_width_range', 'outline_strokes', 'opentype') instead of
    // svgToOtf's parameter names.
    if (!outlineStrokes) {
      throw const FontifyException(
        "'stroke_width_range' varies the stroke outline, but "
        "'outline_strokes' is false so there is no stroke outline to vary.",
      );
    }

    if (!useOpenType) {
      throw const FontifyException(
        "'stroke_width_range' requires OpenType (CFF2) outlines, but "
        "'opentype' is false.",
      );
    }
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
    outlineStrokes: outlineStrokes,
    preview: merged.readBool(JobField.preview),
    useOpenType: useOpenType,
    strokeWidthRange: strokeWidthRange,
  );
}

bool resolveVerboseFromLayers(Iterable<JobValues> layers) {
  final merged = coerceJobValues(mergeJobValues(layers));
  return merged.readBool(JobField.verbose) ??
      kJobBuiltInDefaults.requireBool(JobField.verbose);
}
