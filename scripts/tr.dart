import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final e = File('external/language/translations/en.arb');
  final map = (jsonDecode(e.readAsStringSync()) as Map).cast<String, dynamic>();

  for (final value in args) {
    if (value.isNotEmpty) {
      final keyPre = value.replaceAll(RegExp(r'''[\.!?%,{}‘’*'"()]'''), '').replaceAll(RegExp(r'[ /-]'), '_').replaceAll(r'\n', '_');
      final key = ensureLangKeyValidForArb(keyPre);
      map[key] = value.replaceAll('\\n', '\n');

      final placeholders = extractPlaceholders(value);

      map[key] = value;

      if (placeholders.isNotEmpty) {
        map['@$key'] = {
          'placeholders': {
            for (final p in placeholders)
              p.name: {
                'type': p.type,
              },
          },
        };
      }
    }
  }

  final sorted = Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

  e.writeAsStringSync(JsonEncoder.withIndent('  ').convert(sorted));

  Process.runSync('dart', ['format', e.path], runInShell: true);

  Process.runSync('flutter', ['gen-l10n'], runInShell: true);
}

class Placeholder {
  final String name;
  final String type;

  Placeholder(this.name, this.type);
}

String convertPlaceholders(String value) {
  return value.replaceAllMapped(RegExp(r'\{([A-Z][A-Z0-9_]*)\}'), (m) {
    return '{${_toPlaceholderName(m.group(1)!)}}';
  });
}

String _toPlaceholderName(String raw) {
  var camel = raw.toCamelCase();
  if (camel == 'num') {
    camel = 'number';
  }
  return _reservedWords.contains(camel) ? '${camel}Value' : camel;
}

List<Placeholder> extractPlaceholders(String value) {
  final regex = RegExp(r'\{([A-Z][A-Z0-9_]*)\}', caseSensitive: false);
  final seen = <String>{};
  final result = <Placeholder>[];

  for (final match in regex.allMatches(value)) {
    final raw = match.group(1)!;
    final name = _toPlaceholderName(raw);
    if (seen.contains(name)) continue;
    seen.add(name);

    final isNumeric = _numericKeywords.contains(raw);
    result.add(
      Placeholder(
        name,
        isNumeric ? 'int' : 'String',
      ),
    );
  }

  return result;
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
  'num', 'int', 'double', 'string', 'of', 'continue', //
};

const _numericKeywords = {
  'number',
  'num',
  'current',
  'total',
  'missing',
  'remaining',
  'completed_count',
  'total_count',
};
