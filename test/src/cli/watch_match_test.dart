import 'package:fontify_plus/src/cli/watch_match.dart';
import 'package:fontify_plus/src/job/font_job.dart';
import 'package:test/test.dart';

void main() {
  test('isSvgPath', () {
    expect(isSvgPath('a/b/Icon.SVG'), isTrue);
    expect(isSvgPath('a/b/readme.md'), isFalse);
  });

  test('jobsForSvgPath matches by input prefix', () {
    const icons = FontJob(
      inputSvgDir: 'assets/icons',
      outputFontFile: 'fonts/icons.otf',
    );
    const brand = FontJob(
      inputSvgDir: 'assets/brand',
      outputFontFile: 'fonts/brand.otf',
    );
    expect(
      jobsForSvgPath([icons, brand], 'assets/icons/nav/a.svg'),
      [icons],
    );
    expect(
      jobsForSvgPath([icons, brand], 'assets/brand/x.svg'),
      [brand],
    );
    expect(
      jobsForSvgPath([icons, brand], 'assets/other/x.svg'),
      isEmpty,
    );
  });

  test('isConfigPath', () {
    expect(isConfigPath('fontify_plus.yaml', 'fontify_plus.yaml'), isTrue);
    expect(isConfigPath('other.yaml', 'fontify_plus.yaml'), isFalse);
  });
}
