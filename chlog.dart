// ignore_for_file: avoid_print

import 'dart:io';

import 'package:intl/intl.dart';

void main(List<String> argumentsPre) async {
  final changelog = File('CHANGELOG.md');
  DateTime? startDatetime;
  DateTime? stopDatetime;

  if (argumentsPre.isNotEmpty) {
    startDatetime = DateTime.tryParse(argumentsPre.first);
    if (argumentsPre.length == 2) stopDatetime = DateTime.tryParse(argumentsPre.last);
  }
  final fileLines = changelog.readAsLinesSync();
  if (startDatetime == null) {
    // fetching the latest date found inside [ChANGELOG.md]
    // format has to be [dd/MM/yyyy] if not found then it
    // should be at least parsable.
    for (final l in fileLines) {
      final line = l.split('#').last;
      final splitted = line.split('/');
      if (splitted.length == 3) {
        final y = int.tryParse(splitted[2]);
        final m = int.tryParse(splitted[1]);
        final d = int.tryParse(splitted[0]);
        if (y != null && m != null && d != null) {
          final datetime = DateTime(y, m, d);
          startDatetime = datetime;
          break;
        }
      }
    }
  }

  if (startDatetime == null) {
    for (final l in fileLines) {
      final line = l.split('#').last;
      final datetime = DateTime.tryParse(line);
      if (datetime != null) {
        startDatetime = datetime;
        break;
      }
    }
  }

  if (startDatetime == null) {
    print('Warning: first date isn\'t provided, fetching all changes...');
  }

  final gitOutput = await Process.run('git', <String>[
    'log',
    '--oneline',
    '--decorate',
    '--no-abbrev-commit',
    // '--pretty=%s',
    // '--first-parent',
    if (startDatetime != null) '--after="$startDatetime"',
    if (stopDatetime != null) '--before="$stopDatetime"',
  ]);

  final outputLines = (gitOutput.stdout as String).split('\n');

  final map = <String, List<String>>{};
  for (final line in outputLines) {
    final parts = line.split(':');
    final firstPart = parts.first.toLowerCase().trim().split(' ');
    final hash = firstPart.first;
    final key = firstPart.last;
    final val = "$hash: ${parts.skip(1).join('').trim()}";
    if (map[key] == null) {
      map[key] = [val];
    } else {
      map[key]!.add(val);
    }
  }
  final stringy = map.entries.map((e) => '- ${e.key}:\n${e.value.reversed.map((e) => '   - $e').join('\n')}');
  final dateText = DateFormat('dd/MM/yyyy').format(stopDatetime ?? DateTime.now());
  const title = '# Namida Changelog';
  final finalString = "$title\n\n## $dateText\n${stringy.join('\n')}\n${changelog.readAsStringSync().replaceFirst(title, '')}";
  changelog.writeAsStringSync(finalString);
}
