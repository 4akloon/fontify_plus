import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

import '../utils/exception.dart';
import '../utils/logger.dart';
import 'stroke/stroke_properties.dart';
import 'stroke_attributes.dart';

/// One painted shape of an SVG document, reduced to what a glyph needs.
///
/// A path can be both filled and stroked. Those are two independent regions —
/// the fill is the path's own interior, the stroke is the band it covers — so
/// both are carried rather than one being chosen.
class SvgShape {
  const SvgShape(this.path, {required this.filled, this.stroke});

  final vg.Path path;

  /// Whether the path's interior is painted.
  final bool filled;

  /// The stroke to outline, or null when the path is not stroked.
  final StrokeProperties? stroke;
}

/// The painted geometry of an SVG document.
class SvgGeometry {
  const SvgGeometry({
    required this.width,
    required this.height,
    required this.shapes,
  });

  /// Viewport extent. The viewBox minimum is already folded into the shapes'
  /// coordinates, so this is a size rather than a rectangle.
  final double width;
  final double height;

  final List<SvgShape> shapes;
}

/// Parses [xmlString] into the shapes a glyph is built from.
///
/// [name] identifies the icon in errors and warnings.
///
/// Throws [SvgParserException] for anything the parser rejects.
SvgGeometry parseSvgGeometry(String name, String xmlString) {
  final vg.VectorInstructions instructions;

  try {
    // Never the plain parse(): the masking and overdraw optimisers call into
    // path_ops, which needs a native library this package does not ship.
    instructions = vg.parseWithoutOptimizers(xmlString, key: name);
    // vgc signals malformed input with StateError, which is an Error. Letting
    // it escape would crash the CLI with a stack trace rather than name the
    // file that could not be read.
    // ignore: avoid_catching_errors
  } on Object catch (e) {
    throw SvgParserException('$name: ${_describe(e)}');
  }

  return SvgGeometry(
    width: instructions.width,
    height: instructions.height,
    shapes: _shapesOf(name, instructions),
  );
}

List<SvgShape> _shapesOf(String name, vg.VectorInstructions instructions) {
  final shapes = <SvgShape>[];

  // How many mask regions are currently open. A masked group emits
  // `saveLayer, content, mask, mask shape, restore, restore`, so everything
  // between `mask` and its matching `restore` is the mask's own geometry and
  // must not become ink.
  var maskDepth = 0;

  for (final command in instructions.commands) {
    switch (command.type) {
      case vg.DrawCommandType.mask:
        maskDepth++;
      case vg.DrawCommandType.restore:
        if (maskDepth > 0) {
          maskDepth--;
        }
      case vg.DrawCommandType.clip:
        _warnDropped(name, 'a clip path');
      case vg.DrawCommandType.text:
        _warnDropped(name, 'text');
      case vg.DrawCommandType.image:
        _warnDropped(name, 'an image');
      case vg.DrawCommandType.path:
        if (maskDepth > 0) {
          continue;
        }

        final shape = _shapeOf(instructions, command);

        if (shape != null) {
          shapes.add(shape);
        }
      case vg.DrawCommandType.vertices:
      case vg.DrawCommandType.saveLayer:
      case vg.DrawCommandType.pattern:
      case vg.DrawCommandType.textPosition:
        break;
    }
  }

  return shapes;
}

SvgShape? _shapeOf(
  vg.VectorInstructions instructions,
  vg.DrawCommand command,
) {
  final objectId = command.objectId;
  final paintId = command.paintId;

  if (objectId == null || paintId == null) {
    return null;
  }

  final paint = instructions.paints[paintId];
  final stroke = strokePropertiesOf(paint.stroke);
  final filled = paint.fill != null;

  // Neither filled nor stroked: the author switched this geometry off.
  if (!filled && stroke == null) {
    return null;
  }

  return SvgShape(
    instructions.paths[objectId],
    filled: filled,
    stroke: stroke,
  );
}

void _warnDropped(String name, String what) => logger.logOnce(
  Level.warning,
  '$name: $what is not supported by font glyphs and was dropped.',
);

/// The message of [error] without Dart's `Bad state:` prefix, which tells
/// someone looking at an SVG file nothing useful.
String _describe(Object error) {
  final message = error is StateError ? error.message : error.toString();

  return message.split('\n').first.trim();
}
