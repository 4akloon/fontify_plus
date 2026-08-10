import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The prototype glyphs, by the codepoint fontify_plus assigned them.
///
/// [kDot] is a pure fill: it has no stroke, so it is identical in every
/// master and must NOT change with the axis. Using it to prove the axis works
/// would prove the opposite.
const kDot = 0xE000;
const kPlus = 0xE001;
const kRing = 0xE002;

/// Renders one glyph and hands back its pixels, so a test can compare two
/// renderings produced by the same engine in the same frame.
class GlyphProbe extends StatelessWidget {
  const GlyphProbe({
    super.key,
    required this.boundaryKey,
    required this.family,
    this.weight,
    this.codePoint = kRing,
    this.size = 48,
  });

  final GlobalKey boundaryKey;
  final String family;
  final double? weight;
  final int codePoint;
  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: boundaryKey,
    child: Container(
      color: Colors.white,
      width: size * 2,
      height: size * 2,
      alignment: Alignment.center,
      child: Icon(
        // This probe exists to render a caller-chosen codePoint/family at
        // test time, so it cannot satisfy the icon tree-shaker's @mustBeConst
        // contract. That is expected: icon tree-shaking is disabled for this
        // debug/integration-test harness, never for app release code.
        // ignore: non_const_argument_for_const_parameter
        IconData(codePoint, fontFamily: family),
        size: size,
        weight: weight,
        color: Colors.black,
      ),
    ),
  );
}

/// The raw RGBA bytes of the boundary under [key].
Future<Uint8List> capture(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  return data!.buffer.asUint8List();
}

/// Share of bytes differing by more than [threshold], as a fraction of 1.
double difference(Uint8List a, Uint8List b, {int threshold = 8}) {
  if (a.length != b.length) {
    return 1;
  }

  var differing = 0;

  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > threshold) {
      differing++;
    }
  }

  return differing / a.length;
}
