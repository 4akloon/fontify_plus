import '../element.dart';
import '../path.dart';
import 'stroke_outliner.dart';
import 'stroke_properties_resolver.dart';

/// Replaces stroked paths with the filled region their stroke covers.
///
/// Groups are already flattened by this point, so [elementList] holds every
/// path in the document.
List<SvgElement> outlineStrokedPaths(List<SvgElement> elementList) {
  final result = <SvgElement>[];

  for (final element in elementList) {
    if (element is! PathElement) {
      result.add(element);
      continue;
    }

    final stroke = resolveStroke(element);

    if (stroke == null) {
      result.add(element);
      continue;
    }

    // A path can be both filled and stroked; the fill is its own region and
    // survives independently of the stroke.
    if (_isFilled(element)) {
      result.add(element);
    }

    final outlined = StrokeOutliner(stroke).outline(element.data);

    if (outlined == null) {
      continue;
    }

    result.add(
      PathElement(
        element.fillRule,
        outlined,
        element.parent,
        element.xmlElement,
        transform: element.transform,
      ),
    );
  }

  return result;
}

/// Whether a path paints a fill in addition to its stroke.
///
/// SVG's initial fill is black, so a path is filled unless it opts out — but
/// outline-style icons universally set `fill="none"`, which is what makes the
/// distinction worth drawing.
bool _isFilled(PathElement element) {
  SvgElement? current = element;

  while (current != null) {
    final fill = current.xmlElement?.getAttribute('fill')?.trim();

    if (fill != null) {
      return fill != 'none' && fill.isNotEmpty;
    }

    current = current.parent;
  }

  return true;
}
