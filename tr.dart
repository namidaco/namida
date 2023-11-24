// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// * Use Cases:
///   - `KEY VALUE` => Adds [KEY] and [VALUE]
///   - `KEY` => Adds [KEY] with a value identical to the key, ex: `MY_NAME` : `My name`.
///   - Appending `-r` anywhere removes the key
/// * Notes:
///   - Key is not case sensitive, ex: `my_key`, `MY_KEY` & `My_key` are all valid.
///   - Key words should be separated with underscore.
/// * NEW:
///   - now supports multiple insertions, deletions.
///   - only: `KEY` format is approved, ex: `KEY1,KEY2,KEY3`.
///   - separated by commas (,)
///   - if `KEY1,KEY2 VALUE` was used, only first key will be inserted
void main(List<String> argumentsPre) async {
  final args = List<String>.from(argumentsPre);
  final shouldRemove = args.remove('-r');
  final argKeyhh = args[0].toUpperCase();
  final argKeys = argKeyhh.split(',');

  // should remove
  if (shouldRemove) {
    await _removeKeys(argKeys);
    return;
  }

  // `KEY VALUE`
  if (args.length == 2) {
    // should add `KEY: value` normally
    final value = args[1];
    await _addKey({argKeys.first: value});
  } else
  // want to add `KEY` with identical value
  // ex: `MY_NAME` : `My name`
  if (args.length == 1) {
    final map = <String, String>{};
    for (final argKey in argKeys) {
      final valuePre = argKey.replaceAll('_', ' ').toLowerCase();
      final value = "${valuePre[0].toUpperCase()}${valuePre.substring(1)}";
      map[argKey] = value;
    }
    await _addKey(map);
  } else {
    print('Error(Missing Arguments): Supported arguments: `KEY VALUE` | `KEY` | `KEY1,KEY2` |`-r KEY`');
  }
}

Future<bool> _addKey(Map<String, String> argKeysVals) async {
  try {
    // -- Keys File
    final file = File(_keysFilePath);
    final keys = <String>[];
    final stream = file.openRead();
    final lines = stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      final regexRes = RegExp(r'(?<=String get )(.*)(?= =>)');
      final match = regexRes.firstMatch(line)?[0];
      if (match != null) keys.add(match);

      // final pieces = line.split('String get ');
      // if (pieces.length == 2) {
      //   final withoutSC = pieces.last.split('');
      //   withoutSC.removeLast();
      //   keys.add(withoutSC.join());
      // }
    }
    for (final argKey in argKeysVals.keys) {
      keys.insertWithOrder(argKey);
    }
    await file.writeAsString("""
// ignore_for_file: non_constant_identifier_names
// AUTO GENERATED FILE

abstract class LanguageKeys {
  Map<String, String> get languageMap;
  Map<String, String> get languageMapDefault;
  String _getKey(String key) => languageMap[key] ?? languageMapDefault[key] ?? '';

${keys.map((e) => "  String get $e => _getKey('$e');").join('\n')}
}
""");

    // -- Controller file
//     final langFile = File(_controllerFilePath);
//     final langController = await langFile.readAsString();
//     const splitterOne = '// -- Keys Start ---------------------------------------------------------';
//     const splitterTwo = '// -- Keys End ---------------------------------------------------------';
//     final firstPiece = langController.split(splitterOne).first;
//     final lastPiece = langController.split(splitterTwo).last;
//     final mapText = keys.map((e) => '\t\t\t$e = getKey("$e");').join('\n');
//     await langFile.writeAsString("""$firstPiece$splitterOne
// $mapText
// \t\t\t$splitterTwo$lastPiece""");

    // -- All Langauges files
    const encoder = JsonEncoder.withIndent('  ');
    await for (final fileSystem in Directory(_languagesDirectoryPath).list()) {
      if (fileSystem is File) {
        if (fileSystem.path.endsWith('.json')) {
          final str = await fileSystem.readAsString();
          final map = await jsonDecode(str) as Map<String, dynamic>;
          map.addAll(argKeysVals);
          final sorted = Map<String, dynamic>.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
          await fileSystem.writeAsString(encoder.convert(sorted));
        }
      }
    }
    print('Added ${argKeysVals.length} ${argKeysVals.length > 1 ? 'keys' : 'key'} Successfully');
    return true;
  } on Exception catch (e) {
    print('Error Adding: $e\nRemoving Keys...');
    _removeKeys(argKeysVals.keys);
    return false;
  }
}

Future<bool> _removeKeys(Iterable<String> keysToRemove) async {
  try {
    // -- Keys File
    final file = File(_keysFilePath);
    final lines = await file.readAsLines();
    // -- reverse looping for index-related issues
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (keysToRemove.any((keyToRemove) => line.contains("String get $keyToRemove => _getKey('$keyToRemove');"))) {
        lines.removeAt(i);
      }
    }
    await file.writeAsString('${lines.join('\n')}\n');

    // -- Controller file
    // final langFile = File(_controllerFilePath);
    // final langController = await langFile.readAsString();
    // const splitterOne = '// -- Keys Start ---------------------------------------------------------';
    // const splitterTwo = '// -- Keys End ---------------------------------------------------------';
    // final firstPiece = langController.split(splitterOne).first;
    // final lastPiece = langController.split(splitterTwo).last;
    // final oldMapText = langController.split(splitterOne).last.split(splitterTwo).first;
    // final mapLines = const LineSplitter().convert(oldMapText);
    // mapLines.removeWhere((element) => element.contains("$keyToRemove = "));
    // await langFile.writeAsString("$firstPiece$splitterOne${mapLines.join('\n')}$splitterTwo$lastPiece");

    // -- All Langauges files
    const encoder = JsonEncoder.withIndent('  ');
    await for (final fileSystem in Directory(_languagesDirectoryPath).list()) {
      if (fileSystem is File) {
        if (fileSystem.path.endsWith('.json')) {
          final str = await fileSystem.readAsString();
          final map = await jsonDecode(str) as Map<String, dynamic>;
          for (final keyToRemove in keysToRemove) {
            map.remove(keyToRemove);
          }
          await fileSystem.writeAsString(encoder.convert(map));
        }
      }
    }
    print('Removed Successfully');
    return true;
  } catch (e) {
    print('Error Removing: $e');
    return false;
  }
}

extension OrderedInsert<T extends Comparable> on List<T> {
  void insertWithOrder(T item) {
    int left = 0;
    int right = length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      if (this[mid] == item) {
        // -- If the string is already in the list, dont do anything
        return;
      } else if (this[mid].compareTo(item) < 0) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    // If the string is not in the list, insert it at the appropriate position
    insert(left, item);
  }
}

const _keysFilePath = 'lib/core/translations/keys.dart';
// const _controllerFilePath = 'lib/core/translations/language.dart';
const _languagesDirectoryPath = 'assets/language/translations';
