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
/// renderings produced by the same engine on the same device.
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

  double get side => size * 2;

  @override
  Widget build(BuildContext context) => Center(
    // Center, not a bare Container. A Container placed directly under the
    // home widget receives tight constraints, and BoxConstraints.enforce
    // clamps its requested size up to the whole window — the boundary then
    // captures the full screen and the glyph becomes a rounding error in the
    // denominator, which silently makes every threshold in the tests
    // unreachable.
    child: RepaintBoundary(
      key: boundaryKey,
      child: Container(
        color: Colors.white,
        width: side,
        height: side,
        alignment: Alignment.center,
        child: Icon(
          // This probe exists to render a caller-chosen codePoint/family at
          // test time, so it cannot satisfy the icon tree-shaker's
          // @mustBeConst contract. That is expected: icon tree-shaking is
          // disabled for this debug/integration-test harness, never for app
          // release code.
          // ignore: non_const_argument_for_const_parameter
          IconData(codePoint, fontFamily: family),
          size: size,
          weight: weight,
          color: Colors.black,
        ),
      ),
    ),
  );
}

/// The raw RGBA bytes of the boundary under [key].
///
/// [expectedSide] is checked rather than trusted: a boundary bigger than the
/// probe asked for is the one failure mode that makes every measurement in
/// this file look fine while meaning nothing.
Future<Uint8List> capture(GlobalKey key, {required double expectedSide}) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  final size = boundary.size;

  if ((size.width - expectedSide).abs() > 0.5 ||
      (size.height - expectedSide).abs() > 0.5) {
    throw StateError(
      'Probe captured $size but asked for ${expectedSide}x$expectedSide. '
      'A larger boundary inflates the denominator and makes every threshold '
      'in this suite unreachable.',
    );
  }

  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  return data!.buffer.asUint8List();
}

/// How many colour bytes in [pixels] are dark.
///
/// Reported alongside the comparisons below, because the comparisons are
/// differences and a difference cannot say what was drawn. Two renders that
/// come out identical give 0 whether they are the same correct glyph, the
/// same wrong glyph, or the same fallback box — and the fix differs in each
/// case. This is what told the three apart when the render matrix went red:
/// every family and every weight reported exactly 624, which no set of three
/// genuinely different masters can do, and pointed at the fonts holding the
/// wrong glyphs rather than at the axis.
int inkCount(Uint8List pixels) {
  var dark = 0;

  for (var i = 0; i < pixels.length; i++) {
    if (i % 4 == 3) {
      continue;
    }

    if (pixels[i] < 200) {
      dark++;
    }
  }

  return dark;
}

/// Share of colour bytes differing by more than [threshold], as a fraction
/// of 1.
///
/// Alpha is skipped: it is 255 in every capture here, so counting it would
/// dilute every measurement by a quarter while carrying no signal.
double difference(Uint8List a, Uint8List b, {int threshold = 8}) {
  if (a.length != b.length) {
    return 1;
  }

  var differing = 0;
  var counted = 0;

  for (var i = 0; i < a.length; i++) {
    if (i % 4 == 3) {
      continue;
    }

    counted++;

    if ((a[i] - b[i]).abs() > threshold) {
      differing++;
    }
  }

  return counted == 0 ? 0 : differing / counted;
}
