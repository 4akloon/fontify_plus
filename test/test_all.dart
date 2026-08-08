import 'package:test/test.dart';

import 'cli_test.dart' as cli;
import 'e2e_test.dart' as e2e;
import 'normalize_test.dart' as norm;
import 'stroke_test.dart' as stroke;
import 'svg_test.dart' as svg;
import 'ttf_test.dart' as ttf;

void main() {
  group('TTF', ttf.main);
  group('SVG', svg.main);
  group('CLI', cli.main);
  group('Normalization', norm.main);
  group('End to end', e2e.main);
  group('Stroke', stroke.main);
}
