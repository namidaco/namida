// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) async {
  final filesPathsAndText = <String, String>{};
  await for (final d in Directory('lib').list(recursive: true)) {
    if (d is File && d.path != _keysFilePath) {
      filesPathsAndText[d.path] = await File(d.path).readAsString();
    }
  }

  bool findMatchInProject(String value) {
    for (final f in filesPathsAndText.keys) {
      final string = filesPathsAndText[f] ?? '';
      if (string.contains(value)) return true;
    }
    return false;
  }

  final file = File(_keysFilePath);
  final lines = await file.readAsLines();

  final notUsedKeys = <String>[];
  for (final line in lines) {
    final regexRes = RegExp(r'(?<=String get )(.*)(?= =>)');
    final match = regexRes.firstMatch(line)?[0];
    if (match != null) {
      final hasMatch = findMatchInProject(match);
      if (!hasMatch) notUsedKeys.add(match);
    }
  }
  print("${notUsedKeys.length} not used keys were found");
  print("--------------------------------");
  print(notUsedKeys.toString());
}

const _keysFilePath = 'lib\\core\\translations\\keys.dart';
