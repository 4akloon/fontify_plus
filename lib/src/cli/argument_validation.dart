import 'dart:io';

import 'cli_argument.dart';
import 'cli_exception.dart';
import 'formatter.dart';

extension CliArgumentMapExtension on Map<CliArgument, dynamic> {
  /// Validates and formats CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  Map<CliArgument, dynamic> validateAndFormat() {
    _validateRaw();

    return formatArguments(this).._validateFormatted();
  }

  /// Validates raw CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  void _validateRaw() {
    for (final e in kArgAllowedTypes.entries) {
      final arg = e.key;
      final argType = (this[arg] as Object?).runtimeType;
      final allowedTypes = e.value;

      if (argType != Null && !allowedTypes.contains(argType)) {
        throw CliArgumentException(
          "'${argumentNames[arg]}' argument's type "
          'must be one of following: $allowedTypes, '
          "instead got '$argType'.",
        );
      }
    }
  }

  /// Validates formatted CLI arguments.
  ///
  /// Throws [CliArgumentException], if argument is not valid.
  void _validateFormatted() {
    final svgDir = this[CliArgument.svgDir] as Directory?;
    final fontFile = this[CliArgument.fontFile] as File?;
    final indent = this[CliArgument.indent] as int?;

    if (svgDir == null) {
      throw CliArgumentException('The input directory is not specified.');
    }

    if (fontFile == null) {
      throw CliArgumentException('The output font file is not specified.');
    }

    if (svgDir.statSync().type != FileSystemEntityType.directory) {
      throw CliArgumentException(
        "The input directory is not a directory or it doesn't exist.",
      );
    }

    if (indent != null && indent < 0) {
      throw CliArgumentException(
        'indent must be a non-negative integer, was $indent.',
      );
    }
  }
}

// Ignoring as CLI arguments are dynamically typed
// ignore_for_file: avoid_annotating_with_dynamic
