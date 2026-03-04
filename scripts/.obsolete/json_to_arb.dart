import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) {
  final dirPath = 'assets/language/translations';
  const baseLocaleOverrides = {
    'en_us': 'en',
    'zh_cn': 'zh',
  };

  final allFiles = Directory(dirPath).listSync().whereType<File>().toList();
  final langCodeCount = <String, int>{};
  for (final f in allFiles) {
    final name = p.basenameWithoutExtension(f.path);
    final code = name.split('_').first;
    langCodeCount[code] = (langCodeCount[code] ?? 0) + 1;
  }

  for (final e in allFiles) {
    var localeNamePre = p.basenameWithoutExtension(e.path).toLowerCase();
    localeNamePre = baseLocaleOverrides[localeNamePre] ?? localeNamePre;

    final localeNameSplits = localeNamePre.split('_');
    final code = localeNameSplits.first;
    var countryCode = localeNameSplits.length > 1 ? localeNameSplits[1] : null;

    if (countryCode != null && langCodeCount[code] == 1) {
      countryCode = null;
    }

    final localeName = [
      code,
      ?countryCode?.toUpperCase(),
    ].join('_');
    final arbFile = File('$dirPath/$localeName.arb');
    _convertJsonFileToArb(e, arbFile, localeName);
  }
}

void _convertJsonFileToArb(File jsonFile, File arbFile, String localeName) {
  final map = jsonDecode(jsonFile.readAsStringSync()) as Map;
  final newMap = <String, dynamic>{};
  final isEn = localeName == 'en';

  newMap['@@locale'] = localeName;

  for (final e in map.entries) {
    final key = ensureLangKeyValidForArb(e.key as String);
    if (_pluralKeyVariable.containsKey(key)) {
      final variable = _pluralKeyVariable[key]!;

      final valuesMap = isEn ? _pluralKeys[key]! : <String, String>{'other': convertPlaceholders(e.value)};
      final other = valuesMap['other']!;
      final one = valuesMap['one'];
      final oneText = one == null ? '' : ' one{$one}';
      newMap[key] = '{$variable, plural,$oneText other{$other}}';
      final placeholders = extractPlaceholders(e.value); // from old value
      newMap['@$key'] = {
        'placeholders': {
          for (final p in placeholders) p.name: {'type': p.type},
        },
      };

      continue;
    }

    final value = e.value as String;

    final placeholders = extractPlaceholders(value);
    final convertedValue = convertPlaceholders(value);

    newMap[key] = convertedValue;

    if (placeholders.isNotEmpty) {
      newMap['@$key'] = {
        'placeholders': {
          for (final p in placeholders)
            p.name: {
              'type': p.type,
            },
        },
      };
    }
  }

  arbFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(newMap));
}

class Placeholder {
  final String name;
  final String type;

  Placeholder(this.name, this.type);
}

/// Finds all _VARIABLE_ tokens in the string and returns placeholder info.
List<Placeholder> extractPlaceholders(String value) {
  final regex = RegExp(r'_([A-Z][A-Z0-9_]*)_');
  final seen = <String>{};
  final result = <Placeholder>[];

  for (final match in regex.allMatches(value)) {
    final raw = match.group(1)!; // e.g. FILES_COUNT
    final name = _toPlaceholderName(raw);
    if (seen.contains(name)) continue;
    seen.add(name);

    final isNumeric = raw.split('_').any(_numericKeywords.contains);
    result.add(
      Placeholder(
        name,
        isNumeric ? 'int' : 'String',
      ),
    );
  }

  return result;
}

/// Replaces _VARIABLE_ tokens with {camelCaseName}.
String convertPlaceholders(String value) {
  return value.replaceAllMapped(RegExp(r'_([A-Z][A-Z0-9_]*)_'), (m) {
    return '{${_toPlaceholderName(m.group(1)!)}}';
  });
}

/// Converts RAW_VAR_NAME → rawVarName, avoiding Dart reserved words.
String _toPlaceholderName(String raw) {
  var camel = raw.toCamelCase();
  if (camel == 'num') {
    camel = 'number';
  }
  return _reservedWords.contains(camel) ? '${camel}Value' : camel;
}

String ensureLangKeyValidForArb(String key) {
  var newKey = key.toCamelCase();
  if (_reservedWords.contains(newKey)) newKey += 'Label';
  return newKey;
}

extension on String {
  String toCamelCase() {
    final parts = split(RegExp(r'[_\-\s]+'));
    if (parts.isEmpty) return this;
    return parts.first.toLowerCase() + parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1).toLowerCase()).join();
  }
}

const _reservedWords = {
  'default', 'if', 'else', 'for', 'while', 'switch', 'case',
  'break', 'return', 'new', 'class', 'null', 'true', 'false',
  'this', 'super', 'void', 'var', 'final', 'const', 'static',
  'num', 'int', 'double', 'string', 'of', //
};
// Words that suggest a numeric placeholder
const _numericKeywords = {
  'NUM',
  'COUNT',
  'SECONDS',
  'NUMBER',
  'SIZE',
  'AMOUNT',
  'TOTAL',
  'AGE',
  'YEAR',
  'DAYS',
  'HOURS',
  'MINUTES',
  'INDEX',
  'LIMIT',
  'NEW',
  'DELETED',
  'FILES',
  'LISTENS',
  'REMAINING',
  'COLOR',
  'PALETTES',
};

const _pluralKeys = {
  'clearTrackItemMultiple': {
    'one': 'Clear {number} Track\'s',
    'other': 'Clear {number} Tracks\'',
  },
  'crossfadeTriggerSeconds': {
    'one': 'Trigger Crossfade automatically in the last {seconds} second',
    'other': 'Trigger Crossfade automatically in the last {seconds} seconds',
  },
  'deleteFileCacheSubtitle': {
    'one': 'Delete {number} file representing {totalSize}?',
    'other': 'Delete {filesCount} files representing {totalSize}?',
  },
  'deleteNTracksFromStorage': {
    'one': 'Permanently delete {number} track from your storage',
    'other': 'Permanently delete {number} tracks from your storage',
  },
  'dimMiniplayerAfterSeconds': {
    'one': 'Dim miniplayer after {seconds} second of inactivity',
    'other': 'Dim miniplayer after {seconds} seconds of inactivity',
  },
  'historyListensReplaceWarning': {
    'one': '{number} listen for {oldTrackInfo} will be replaced with {newTrackInfo}, confirm?',
    'other': '{listensCount} listens for {oldTrackInfo} will be replaced with {newTrackInfo}, confirm?',
  },
  'importedNChannelsSuccessfully': {
    'one': 'Imported {number} channel successfully',
    'other': 'Imported {number} channels successfully',
  },
  'importedNPlaylistsSuccessfully': {
    'one': 'Imported {number} playlist successfully',
    'other': 'Imported {number} playlists successfully',
  },
  'lostMemoriesSubtitle': {
    'one': 'around this time, {number} year ago',
    'other': 'around this time, {number} years ago',
  },
  'minimumOneItemSubtitle': {
    'one': 'At least {number} item should remain',
    'other': 'At least {number} items should remain',
  },
  'repeatForNTimes': {
    'one': 'Repeat for {number} more time',
    'other': 'Repeat for {number} more times',
  },
  'resumeIfWasPausedForLessThanNMin': {
    'one': 'Resume if was paused for less than {number} minute',
    'other': 'Resume if was paused for less than {number} minutes',
  },
  'extractAllColorPalettesSubtitle': {
    'one': 'Extract Remaining {remainingColorPalettes}?',
    'other': 'Extract Remaining {remainingColorPalettes}?',
  },
};

// the plural selector variable for each key
const _pluralKeyVariable = {
  'clearTrackItemMultiple': 'number',
  'crossfadeTriggerSeconds': 'seconds',
  'deleteFileCacheSubtitle': 'filesCount',
  'deleteNTracksFromStorage': 'number',
  'dimMiniplayerAfterSeconds': 'seconds',
  'historyListensReplaceWarning': 'listensCount',
  'importedNChannelsSuccessfully': 'number',
  'importedNPlaylistsSuccessfully': 'number',
  'lostMemoriesSubtitle': 'number',
  'minimumOneItemSubtitle': 'number',
  'repeatForNTimes': 'number',
  'resumeIfWasPausedForLessThanNMin': 'number',
  'extractAllColorPalettesSubtitle': 'number',
};
