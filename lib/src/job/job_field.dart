/// Config / job field identifiers shared by YAML parsing and CLI.
enum JobField {
  inputSvgDir,
  outputFontFile,
  outputClassFile,
  className,
  indent,
  package,
  fontName,
  normalize,
  outlineStrokes,
  preview,
  strokeWidthRange,
  defaultStrokeWidth,
  useOpenType,
  recursive,
  verbose,
}

/// YAML key for each [JobField].
const kJobConfigKeys = <JobField, String>{
  JobField.inputSvgDir: 'input_svg_dir',
  JobField.outputFontFile: 'output_font_file',
  JobField.outputClassFile: 'output_class_file',
  JobField.className: 'class_name',
  JobField.indent: 'indent',
  JobField.package: 'package',
  JobField.fontName: 'font_name',
  JobField.normalize: 'normalize',
  JobField.outlineStrokes: 'outline_strokes',
  JobField.preview: 'preview',
  JobField.strokeWidthRange: 'stroke_width_range',
  JobField.defaultStrokeWidth: 'default_stroke_width',
  JobField.useOpenType: 'opentype',
  JobField.recursive: 'recursive',
  JobField.verbose: 'verbose',
};

/// CLI long-option name for each [JobField], when applicable.
const kJobCliOptions = <JobField, String>{
  JobField.outputClassFile: 'output-class-file',
  JobField.className: 'class-name',
  JobField.indent: 'indent',
  JobField.package: 'package',
  JobField.fontName: 'font-name',
  JobField.normalize: 'normalize',
  JobField.outlineStrokes: 'outline-strokes',
  JobField.preview: 'preview',
  JobField.strokeWidthRange: 'stroke-width-range',
  JobField.defaultStrokeWidth: 'default-stroke-width',
  JobField.useOpenType: 'opentype',
  JobField.recursive: 'recursive',
  JobField.verbose: 'verbose',
};

/// Built-in defaults applied when resolving a [FontJob].
const kJobBuiltInDefaults = <JobField, Object>{
  JobField.indent: 2,
  JobField.recursive: false,
  JobField.normalize: true,
  JobField.outlineStrokes: true,
  JobField.preview: true,
  JobField.useOpenType: true,
  JobField.verbose: false,
};

/// Fields allowed in `defaults:` (paths are per-font only).
const kJobDefaultsFields = {
  JobField.outputClassFile,
  JobField.className,
  JobField.indent,
  JobField.package,
  JobField.fontName,
  JobField.normalize,
  JobField.outlineStrokes,
  JobField.preview,
  JobField.strokeWidthRange,
  JobField.defaultStrokeWidth,
  JobField.useOpenType,
  JobField.recursive,
  JobField.verbose,
};

JobField? jobFieldForConfigKey(String key) {
  for (final e in kJobConfigKeys.entries) {
    if (e.value == key) {
      return e.key;
    }
  }
  return null;
}

JobField? jobFieldForCliOption(String option) {
  for (final e in kJobCliOptions.entries) {
    if (e.value == option) {
      return e.key;
    }
  }
  return null;
}

String configKey(JobField field) => kJobConfigKeys[field]!;

String? cliOption(JobField field) => kJobCliOptions[field];
