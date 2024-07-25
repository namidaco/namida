// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// - `-r` to bump release version
/// - `-b` to build apk
/// - `-v` to print build details
void main(List<String> args) async {
  final pubspec = File('pubspec.yaml');
  final pubspecLines = pubspec.readAsLinesSync();
  const versionLinePrefix = 'version: ';
  bool didBump = false;
  bool didAddToGit = false;
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
      didBump = true;
      pubspec.writeAsStringSync("""${pubspecLines.join('\n')}
""");

      print('git: adding changed files');
      didAddToGit = await _runGitAdd(oldLine: line, newLine: newLine, args: []);
      break;
    }
  }
  if (!didAddToGit) print('couldn\'t add to git stage');
  if (!didBump) {
    print('couldnt bump version');
    return;
  }
  print('version bumped');
  if (args.contains('-b')) {
    print('building...');
    final didBuild = await _buildAPK(verbose: args.contains('-v'));
    print(didBuild ? 'build success' : 'build error');
  }
}

Future<bool> _buildAPK({required bool verbose}) async {
  final v = verbose ? ' -v' : '';
  final buildCommand = 'build apk --target-platform android-arm,android-arm64 --release --split-per-abi$v';
  final success = await _runProcess(
    program: 'flutter',
    command: buildCommand,
    onOutput: verbose ? (data, _) => print(data) : null,
  );
  return success;
}

Future<bool> _runGitAdd({required String oldLine, required String newLine, required List<String> args}) async {
  bool added = false;
  bool executedFirstCommand = false;
  final success = await _runProcess(
    program: 'git',
    command: 'add pubspec.yaml -p',
    onOutput: (data, stdinStream) {
      if (executedFirstCommand) return;
      executedFirstCommand = true;
      stdinStream.writeln('s');
      stdinStream.writeln('/');
      stdinStream.writeln('^version: ');
      stdinStream.writeln('y');
      stdinStream.writeln('q');
      added = true;
    },
  );
  return success && added;
}

Future<bool> _runProcess({
  required String program,
  required String command,
  void Function(String data, IOSink stdinStream)? onOutput,
}) async {
  final process = await Process.start(program, command.split(' '), runInShell: true);

  final stdinStream = process.stdin;

  if (onOutput != null) {
    final stdoutStream = process.stdout;
    stdoutStream.transform(utf8.decoder).listen((data) => onOutput(data, stdinStream));
  }

  final stderrStream = process.stderr;
  stderrStream.transform(utf8.decoder).listen(
        (data) => print('$program error: $data'),
      );

  final exitCode = await process.exitCode;
  stdinStream.close();
  return exitCode == 0;
}
