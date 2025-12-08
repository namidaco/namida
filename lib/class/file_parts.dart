import 'dart:io';

import 'package:path/path.dart' as p;

class FileParts {
  const FileParts._();

  static String joinPath(String part1, String part2, [String? part3, String? part4]) {
    return p.join(part1, part2, part3, part4);
  }

  static String joinAllPath(Iterable<String> parts) {
    return p.joinAll(parts);
  }

  static File join(String part1, String part2, [String? part3, String? part4]) {
    return File(joinPath(part1, part2, part3, part4));
  }

  static File joinAll(Iterable<String> parts) {
    return File(joinAllPath(parts));
  }
}
