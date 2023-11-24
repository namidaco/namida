// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  Future<Map<String, dynamic>?> parseJSONFile(File file) async {
    try {
      final str = await file.readAsString();
      final langMap = await jsonDecode(str) as Map<String, dynamic>;
      return langMap;
    } catch (e) {
      print('Error parsing the map $e');
    }
    return null;
  }

  const engJsonFileName = 'en_US.json';
  final mainMap = <String, dynamic>{};
  final mainFile = File("$_languagesDirectoryPath\\$engJsonFileName");
  final mainParsed = await parseJSONFile(mainFile);
  if (mainParsed == null || mainParsed.isEmpty) {
    print('Error parsing the main map, aborting...');
    return;
  }
  mainMap.addAll(mainParsed);

  const encoder = JsonEncoder.withIndent('  ');
  await for (final fileSystem in Directory(_languagesDirectoryPath).list()) {
    if (fileSystem is File) {
      if (p.basename(fileSystem.path) != engJsonFileName && fileSystem.path.endsWith('.json')) {
        final copyMap = Map<String, String>.from(mainMap);
        final langMap = await parseJSONFile(fileSystem);
        if (langMap == null || langMap.isEmpty) {
          print('Error parsing the json of $fileSystem, skipping...');
          continue;
        }
        for (final e in langMap.keys) {
          if (copyMap[e] != null) {
            // -- only assign if the key exists in the main map
            // -- remaining keys (ones exists in main but not in lang) will have the same value of default map.
            copyMap[e] = langMap[e];
          }
        }
        await fileSystem.writeAsString(encoder.convert(copyMap));
      }
    }
  }
}

const _languagesDirectoryPath = 'assets\\language\\translations';
