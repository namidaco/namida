import 'dart:io';

/// converts changelog with short has to long hash, usually for releases
void main(List<String> argumentsPre) async {
  final string = File('temp_changelog.md').readAsStringSync();
  final newString = string.replaceFirstMapped(
    RegExp(r'#([a-zA-Z0-9]{7}):', caseSensitive: false),
    (match) {
      final shortHash = match.group(1);
      if (shortHash != null) {
        final gitOutput = Process.runSync('git', <String>[
          'rev-parse',
          shortHash,
        ]);
        final long = gitOutput.stdout as String?;
        if (long != null) {
          final refined = long.trim();
          return "#$refined:";
        }
      }
      return match.input;
    },
  );
  File('temp_changelog_hash.md').writeAsStringSync(newString);
}
