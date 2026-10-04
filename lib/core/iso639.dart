// by claude
part 'iso639.data.dart';

/// ISO 639-3 languages with their 639-1/639-2 aliases, library keys are display labels like `English (eng)`.
abstract final class Iso639 {
  static const separators = [';', ',', '/', '|'];
  static final _separatorsRegex = RegExp('[${separators.join()}]');
  static final _labelCodeRegex = RegExp(r'\(([a-z]{3})\)$');

  static const _kAliases = <String, String>{
    'instrumental': 'zxx', 'not applicable': 'zxx', 'none': 'zxx', //
    'multiple': 'mul', 'multi': 'mul', //
    'missing': 'mis', 'uncoded': 'mis', //
    'unknown': 'und', 'undetermined': 'und', 'undefined': 'und', //
  };

  static Map<String, String>? _codesByLowercasedName;
  static Map<String, String>? _part1ByCode;

  static int get count => _kNames.length;

  static Iterable<MapEntry<String, String>> get entries => _kNames.entries;

  static String? nameOf(String code) => _kNames[code];

  static String? part1Of(String code) {
    final part1ByCode = _part1ByCode ??= {for (final e in _kPart1.entries) e.value: e.key};
    return part1ByCode[code];
  }

  static String labelOf(String code) => '${_kNames[code]} ($code)';

  /// `en`, `eng`, `ger`, `en-US`, `English`, `instrumental`, `English (eng)` -> the 639-3 code, null when nothing matches.
  static String? resolve(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    final fromLabel = _labelCodeRegex.firstMatch(text)?.group(1);
    if (fromLabel != null && _kNames.containsKey(fromLabel)) return fromLabel;

    final fromCode = _resolveCode(text);
    if (fromCode != null) return fromCode;

    final base = _withoutRegion(text);
    if (base != text) {
      final fromBaseCode = _resolveCode(base);
      if (fromBaseCode != null) return fromBaseCode;
    }

    final fromAlias = _kAliases[text];
    if (fromAlias != null) return fromAlias;

    return _codesByName()[text];
  }

  /// the display label, or the trimmed value itself when it isn't a known language.
  static String labelOfRaw(String raw) {
    final code = resolve(raw);
    return code == null ? raw.trim() : labelOf(code);
  }

  /// multi-value tag to unique labels, the common case of no tag costs nothing.
  static List<String> splitToLabels(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final parts = raw.split(_separatorsRegex);
    final labels = <String>[];
    for (final part in parts) {
      final label = labelOfRaw(part);
      if (label.isEmpty || labels.contains(label)) continue;
      labels.add(label);
    }
    return labels;
  }

  static String? _resolveCode(String text) {
    switch (text.length) {
      case 2:
        return _kPart1[text];
      case 3:
        if (_kNames.containsKey(text)) return text;
        return _kPart2B[text];
      default:
        return null;
    }
  }

  /// `en-us`, `zh_hans` -> `en`, `zh`.
  static String _withoutRegion(String text) {
    final length = text.length;
    for (int i = 0; i < length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x2D /* - */ || c == 0x5F /* _ */ ) return text.substring(0, i);
    }
    return text;
  }

  static Map<String, String> _codesByName() {
    return _codesByLowercasedName ??= {for (final e in _kNames.entries) e.value.toLowerCase(): e.key};
  }
}
