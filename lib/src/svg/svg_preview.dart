import 'package:xml/xml.dart';

/// Metadata elements that cost bytes but do not draw.
const _kNonRenderingElements = {'title', 'desc', 'metadata'};

/// Exact `fill`/`stroke` values swapped for grey so previews stay legible
/// on dark hover backgrounds. Lowercase; compared case-insensitively.
const _kBlackValues = {'black', '#000', '#000000', 'currentcolor'};

/// Minifies an SVG document for embedding as a dartdoc preview.
///
/// Serializes only the root element (dropping the XML declaration, doctype,
/// and anything else outside it) with no inter-tag whitespace and
/// single-quoted attributes — single quotes survive percent-encoding in a
/// data URI, unlike `"` at three bytes each. Comments and
/// `<title>`/`<desc>`/`<metadata>` are removed.
///
/// The root is resized to `width='32' height='32'` — markdown images have no
/// width syntax, so sizing must live on the SVG itself. A missing `viewBox`
/// is synthesized from the author width/height first, otherwise the resize
/// would crop the drawing; with neither present, sizing is left alone.
///
/// Black is recolored `grey` so previews read on dark hover backgrounds:
/// exact `fill`/`stroke` attribute values in [_kBlackValues] are swapped,
/// and a root with no `fill` attribute gets `fill='grey'`, which paths
/// relying on SVG's default black fill inherit. CSS inside `style`
/// attributes or elements is not rewritten.
String minifySvgPreview(String xml) {
  final root = XmlDocument.parse(xml).rootElement;

  final dropped = [
    for (final node in root.descendants)
      if (node is XmlComment ||
          (node is XmlText && node.value.trim().isEmpty) ||
          (node is XmlElement &&
              _kNonRenderingElements.contains(node.localName)))
        node,
  ];

  for (final node in dropped) {
    node.parent!.children.remove(node);
  }

  if (root.getAttribute('viewBox') == null) {
    final width = _cssLength(root.getAttribute('width'));
    final height = _cssLength(root.getAttribute('height'));

    if (width != null && height != null) {
      root.setAttribute('viewBox', '0 0 ${_fmt(width)} ${_fmt(height)}');
    }
  }

  if (root.getAttribute('viewBox') != null) {
    root.setAttribute('width', '32');
    root.setAttribute('height', '32');
  }

  for (final element in [root, ...root.descendants.whereType<XmlElement>()]) {
    for (final attribute in element.attributes.toList()) {
      final name = attribute.localName;

      if ((name == 'fill' || name == 'stroke') &&
          _kBlackValues.contains(attribute.value.trim().toLowerCase())) {
        element.setAttribute(attribute.name.qualified, 'grey');
      }
    }
  }

  if (root.getAttribute('fill') == null) {
    root.setAttribute('fill', 'grey');
  }

  for (final element in [root, ...root.descendants.whereType<XmlElement>()]) {
    final singleQuoted = [
      for (final attribute in element.attributes)
        XmlAttribute(
          XmlName.qualified(attribute.name.qualified),
          attribute.value,
          XmlAttributeType.SINGLE_QUOTE,
        ),
    ];

    element.attributes.clear();
    element.attributes.addAll(singleQuoted);
  }

  return root.toXmlString();
}

/// Numeric value of a CSS length like `24` or `24px`; null for percentages
/// and anything else unparseable. SVG user units equal CSS px.
double? _cssLength(String? value) {
  if (value == null) {
    return null;
  }

  final match = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(?:px)?\s*$').firstMatch(value);

  return match == null ? null : double.parse(match.group(1)!);
}

/// `24.0` reads as `24`; non-integral values keep their fraction.
String _fmt(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();
