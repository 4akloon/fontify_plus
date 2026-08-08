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

  // The layers currently open, innermost last, each recording whether it is a
  // mask region. A masked group emits
  // `saveLayer, content, mask, mask shape, restore, restore`, so geometry
  // between `mask` and its own `restore` describes the mask, not the icon.
  //
  // A depth counter is not enough. `saveLayer` and `clip` each open a layer and
  // each is closed by its own `restore`, so a clip or an opacity group nested
  // inside a mask emits a `restore` first — decrementing on that would end the
  // mask region early and let the rest of the mask through as ink.
  final layers = <bool>[];

  for (final command in instructions.commands) {
    switch (command.type) {
      case vg.DrawCommandType.mask:
        layers.add(true);
      case vg.DrawCommandType.saveLayer:
        layers.add(false);
      case vg.DrawCommandType.clip:
        layers.add(false);
        _warnDropped(name, 'a clip path');
      case vg.DrawCommandType.restore:
        if (layers.isNotEmpty) {
          layers.removeLast();
        }
      case vg.DrawCommandType.text:
        _warnDropped(name, 'text');
      case vg.DrawCommandType.image:
        _warnDropped(name, 'an image');
      case vg.DrawCommandType.path:
        if (layers.contains(true)) {
          continue;
        }

        final shape = _shapeOf(instructions, command);

        if (shape != null) {
          shapes.add(shape);
        }
      case vg.DrawCommandType.vertices:
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
  final filled = _paints(paint.fill);

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

/// Whether a fill puts ink on the page.
///
/// vgc reports a fully transparent fill as a `Fill` whose colour has zero alpha
/// rather than as no fill at all, so `fill="#00000000"` and `fill-opacity="0"`
/// both arrive here non-null. Icon sets use exactly that to carry invisible hit
/// targets, which would otherwise fill the whole glyph.
bool _paints(vg.Fill? fill) {
  if (fill == null) {
    return false;
  }

  // A gradient paints whatever its stops say; the base colour is not the
  // question.
  if (fill.shader != null) {
    return true;
  }

  return fill.color.value >> 24 & 0xFF != 0;
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
