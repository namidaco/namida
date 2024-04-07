// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final pubspec = File('pubspec.yaml');
  final pubspecLines = pubspec.readAsLinesSync();
  const versionLinePrefix = 'version: ';
  bool didUpdate = false;
  for (int i = 0; i < pubspecLines.length; i++) {
    final line = pubspecLines[i];
    if (line.startsWith(versionLinePrefix)) {
      final currentName = line.split(versionLinePrefix).last.split('+').first;
      final currentVersion = currentName.split('-').first; // stripping `-beta`
      if (args.isEmpty) {
        print('please provide version name, current is: $currentVersion');
        break;
      }
      final versionName = args[0];
      if (currentVersion == versionName) {
        print('you entered the same version name: $currentVersion, enter `y` to force bump');
        final input = stdin.readLineSync();
        if (input?.toLowerCase() != 'y') break;
      }
      final isRelease = args.contains('-r');
      final suffix = isRelease ? '' : '-beta';
      final newVersionName = "$versionName$suffix";

      final date = DateTime.now().toUtc();
      final year = date.year.toString();
      String padLeft(int number) => number.toString().padLeft(2, '0');
      final minutesPercentage = (date.minute / 60).toString().substring(2, 3);
      final newBuildNumber = "${year.substring(2)}${padLeft(date.month)}${padLeft(date.day)}${padLeft(date.hour)}$minutesPercentage";
      final newLine = '$versionLinePrefix$newVersionName+$newBuildNumber';
      print("old $line");
      pubspecLines[i] = newLine;
      print("new $newLine");
      didUpdate = true;
      pubspec.writeAsStringSync("""${pubspecLines.join('\n')}
""");
      break;
    }
  }
  if (!didUpdate) {
    print('couldnt bump version');
  }
}
