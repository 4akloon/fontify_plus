import 'package:path/path.dart' as p;

import '../job/font_job.dart';

bool isSvgPath(String path) {
  final basename = p.basename(path);
  return basename.toLowerCase().endsWith('.svg');
}

bool _isUnder(String dir, String file) {
  final nDir = p.normalize(dir);
  final nFile = p.normalize(file);
  return nFile == nDir || p.isWithin(nDir, nFile);
}

List<FontJob> jobsForSvgPath(List<FontJob> jobs, String filePath) {
  return jobs.where((job) => _isUnder(job.inputSvgDir, filePath)).toList();
}

bool isConfigPath(String eventPath, String configFilePath) {
  return p.normalize(eventPath) == p.normalize(configFilePath);
}
