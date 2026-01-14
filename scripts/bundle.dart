// ignore_for_file: avoid_print

import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main(List<String> args) async {
  final start = DateTime.now();

  final linuxDistDir = _getDirectoryEnsureExistsAndCleaned('./dist');
  final bundleOutputDir = _getDirectoryEnsureExistsAndCleaned('./scripts/bundle_output');

  final isKuru = args.contains('-kuru');

  print('====> Parsing version...');

  final pubspecContent = File('pubspec.yaml').readAsStringSync();
  final pubspecParsed = loadYaml(pubspecContent);
  final versionWithBuildNumber = pubspecParsed['version'] as String;
  final versionOnly = versionWithBuildNumber.split('+').first.split('-').first;
  // final buildNumberOnly = versionWithBuildNumber.split('+').last;

  print('====> Parsed version: $versionOnly');

  // ensure not beta, rpm hates '-' and generally not useful like android
  // await _execute('dart', ['bump_version.dart', '-y', '-r', '--skip-git', versionOnly, buildNumberOnly]);

  // -- just bcz kernel_blob.bin is sometimes created for release mode
  await _execute('flutter', ["clean"]);

  final filename = 'namida-$versionOnly-beta';
  String buildOutputPath(String ext) {
    return "${bundleOutputDir.path}/$filename.linux.$ext";
  }

  // final directoriesToWatchToCopyFFmpeg = [
  //   MapEntry('build', Directory('build/linux/x64/release/bundle')),
  //   MapEntry('dist', Directory('dist/$versionWithBuildNumber/namida-$versionWithBuildNumber-linux_deb/usr/share/namida')),
  //   MapEntry('dist', Directory('dist/$versionWithBuildNumber/namida-$versionWithBuildNumber-linux_appimage/namida.AppDir')),
  // ];
  // for (final e in directoriesToWatchToCopyFFmpeg) {
  //   _watchAndCopyBinariesForDir(e);
  // }

  print('====> Building linux...${isKuru ? '(kuru)' : ''}');

  final buildExitCode = await _execute(
    'flutter',
    [
      "build",
      "linux",
      "--release",
      if (isKuru) "--dart-define=IS_KURU_BUILD=$isKuru",
    ],
  );

  if (buildExitCode != 0) {
    print('Error occured while building for linux.. aborting. (err code $buildExitCode)');
    return;
  }

  print('====> Packaging linux (.tar.gz)...');

  await _execute('tar', [
    "-czf",
    buildOutputPath('tar.gz'),
    "-C",
    "build/linux/x64/release/bundle",
    ".",
  ]);
  print('====> Success');

  const availableOutputFormats = [
    'deb',
    'rpm',
    // 'appimage',
  ];
  print('====> Packaging linux (${availableOutputFormats.join('/')})...');
  if (availableOutputFormats.contains('appimage')) {
    _ensureAppImageConfigHasAllDeps();
  }
  await _execute('fastforge', [
    "package",
    "--platform=linux",
    "--targets=${availableOutputFormats.join(',')}",
    "--skip-clean",
    "--flutter-build-args=release",
    if (isKuru) "--build-dart-define=IS_KURU_BUILD=$isKuru",
  ]);
  print('====> Success');

  print('====> Copying files');
  await for (final e in linuxDistDir.list(recursive: true)) {
    if (e is File) {
      for (final format in availableOutputFormats) {
        final extension = e.path.split('.').last;
        if (extension.toLowerCase().endsWith(format)) {
          e.copySync(buildOutputPath(format));
          break;
        }
      }
    }
  }

  // await _execute('dart', ['bump_version.dart', '-y', '--skip-git', versionOnly, buildNumberOnly]);

  final end = DateTime.now();
  print('====> All done in ${end.difference(start).inSeconds} seconds.');
}

void _ensureAppImageConfigHasAllDeps() {
  final file = File('linux/packaging/appimage/make_config.yaml');
  if (file.existsSync()) {
    final p = Process.runSync('ldd', ['build/linux/x64/release/bundle/namida']);
    final deps = (p.stdout as String).split('\n');
    final depsList = <String>[];
    final blackListDeps = Directory('build/linux/x64/release/bundle/lib').listSync().map((e) => e.path.split('/').last.split('.').first).toList();
    for (final d in deps) {
      final initialSplits = d.split(' =>');
      if (initialSplits.length < 2) {
        // -- means its virtual only and doesnt exist in a path
        continue;
      }
      var name = initialSplits.first.trim();
      name = name.split('(').first.trim();
      // name = name.split('/').last.trim();
      if (name.isNotEmpty && !name.contains('/')) {
        if (blackListDeps.any((bld) => name.startsWith(bld))) {
          // -- already bundled
        } else {
          depsList.add(name);
        }
      }
    }
    void addDepIfMissing(String name) {
      if (!depsList.contains(name)) {
        depsList.add(name);
      }
    }

    addDepIfMissing('libfuse.so.2');
    addDepIfMissing('libasound.so');
    addDepIfMissing('libasound.so.2');
    addDepIfMissing('libasound.so.2.0.0');

    final editor = YamlEditor(file.readAsStringSync());

    editor.update(['include'], depsList);

    file.writeAsStringSync(editor.toString());
  }
}

Directory _getDirectoryEnsureExistsAndCleaned(String path, {bool clean = true}) {
  final dir = Directory(path);
  try {
    if (clean) dir.deleteSync(recursive: true);
  } catch (_) {}
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

Future<int> _execute(String executable, List<String> arguments) async {
  final p = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  _activeProcesses.add(p);
  final code = await p.exitCode;
  _activeProcesses.remove(p);
  return code;
}

final _activeProcesses = <Process>[];
void _pauseActiveProcesses() {
  for (final p in _activeProcesses) {
    p.kill(ProcessSignal.sigstop);
  }
}

void _resumeActiveProcesses() {
  for (final p in _activeProcesses) {
    p.kill(ProcessSignal.sigcont);
  }
}

// -- using CMakeLists currently
// ignore: unused_element
Future<void> _watchAndCopyBinariesForDir(MapEntry<String, Directory> entry) async {
  // final parent = _getDirectoryEnsureExistsAndCleaned(entry.key, clean: false);
  // final stream = parent.watch(recursive: true); // doesnt reliably work
  final d = entry.value;
  try {
    d.deleteSync(recursive: true); // ensure deleted so that detection happens after building ends.
  } catch (_) {}
  while (!d.existsSync()) {
    await Future.delayed(Duration(milliseconds: 10));
  }
  print('====--> detected change in $d, copying binaries...');

  _pauseActiveProcesses();

  final releaseBinDir = Directory('${d.path}/bin');
  releaseBinDir.createSync(recursive: false);
  Directory('ffmpeg_build/linux').listSync().forEach(
    (element) {
      if (element is File) {
        final filename = element.path.split('/').last;
        element.copySync('${releaseBinDir.path}/$filename');
      }
    },
  );
  print('====--> copied binaries.');

  _resumeActiveProcesses();
}
