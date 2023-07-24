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
void main(List<String> argumentsPre) async {
  final args = List<String>.from(argumentsPre);
  final shouldRemove = args.remove('-r');
  final argKey = args[0].toUpperCase();

  // should remove
  if (shouldRemove) {
    await _removeKey(argKey);
    return;
  }

  // `KEY VALUE`
  if (args.length == 2) {
    // should add `KEY: value` normally
    final value = args[1];
    await _addKey(argKey, value);
  } else
  // want to add `KEY` with identical value
  // ex: `MY_NAME` : `My name`
  if (args.length == 1) {
    final valuePre = argKey.replaceAll('_', ' ').toLowerCase();
    final value = "${valuePre[0].toUpperCase()}${valuePre.substring(1)}";
    await _addKey(argKey, value);
  } else {
    print('Error(Missing Arguments): Supported arguments: `KEY VALUE` | `KEY` | `-r KEY`');
  }
}

Future<bool> _addKey(String argKey, String argValue) async {
  try {
    // -- Keys File
    final file = File(_keysFilePath);
    final keys = <String>[];
    final stream = file.openRead();
    final lines = stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      final pieces = line.split('late String ');
      if (pieces.length == 2) {
        final withoutSC = pieces.last.split('');
        withoutSC.removeLast();
        keys.add(withoutSC.join());
      }
    }
    keys.insertWithOrder(argKey);
    await file.writeAsString("""
// ignore_for_file: non_constant_identifier_names
// AUTO GENERATED FILE
  
class LanguageKeys {
${keys.map((e) => '  late String $e;').join('\n')}
}""");

    // -- Controller file
    final langFile = File(_controllerFilePath);
    final langController = await langFile.readAsString();
    const splitterOne = '// -- Keys Start ---------------------------------------------------------';
    const splitterTwo = '// -- Keys End ---------------------------------------------------------';
    final firstPiece = langController.split(splitterOne).first;
    final lastPiece = langController.split(splitterTwo).last;
    final mapText = keys.map((e) => '\t\t\t$e = getKey("$e");').join('\n');
    await langFile.writeAsString("""$firstPiece$splitterOne
$mapText
\t\t\t$splitterTwo$lastPiece
""");

    // -- All Langauges files
    const encoder = JsonEncoder.withIndent('  ');
    await for (final fileSystem in Directory(_languagesDirectoryPath).list()) {
      if (fileSystem is File) {
        if (fileSystem.path.endsWith('.json')) {
          final str = await fileSystem.readAsString();
          final map = await jsonDecode(str) as Map<String, dynamic>;
          map.addAll({argKey: argValue});
          final sorted = Map<String, dynamic>.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
          await fileSystem.writeAsString(encoder.convert(sorted));
        }
      }
    }
    print('Added Successfully');
    return true;
  } on Exception catch (e) {
    print('Error Adding: $e');
    return false;
  }
}

Future<bool> _removeKey(String keyToRemove) async {
  try {
    // -- Keys File
    final file = File(_keysFilePath);
    final lines = await file.readAsLines();
    final indToRemove = lines.indexWhere((element) => element.contains('late String $keyToRemove;'));
    lines.removeAt(indToRemove);
    await file.writeAsString(lines.join('\n'));

    // -- Controller file
    final langFile = File(_controllerFilePath);
    final langController = await langFile.readAsString();
    const splitterOne = '// -- Keys Start ---------------------------------------------------------';
    const splitterTwo = '// -- Keys End ---------------------------------------------------------';
    final firstPiece = langController.split(splitterOne).first;
    final lastPiece = langController.split(splitterTwo).last;
    final oldMapText = langController.split(splitterOne).last.split(splitterTwo).first;
    final mapLines = const LineSplitter().convert(oldMapText);
    mapLines.removeWhere((element) => element.contains("$keyToRemove = "));
    await langFile.writeAsString("$firstPiece$splitterOne${mapLines.join('\n')}$splitterTwo$lastPiece");

    // -- All Langauges files
    const encoder = JsonEncoder.withIndent('  ');
    await for (final fileSystem in Directory(_languagesDirectoryPath).list()) {
      if (fileSystem is File) {
        if (fileSystem.path.endsWith('.json')) {
          final str = await fileSystem.readAsString();
          final map = await jsonDecode(str) as Map<String, dynamic>;
          map.remove(keyToRemove);
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
const _controllerFilePath = 'lib/controller/language_controller.dart';
const _languagesDirectoryPath = 'assets/language/translations';
