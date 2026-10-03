import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class SplitArtistGenreConfigsWrapper {
  final String dbPath;
  final ArtistsSplitConfig artistsConfig;
  final GenresSplitConfig genresConfig;
  final SimpleSplitConfig albumConfig;
  final GeneralSplitConfig generalConfig;

  const SplitArtistGenreConfigsWrapper({
    required this.dbPath,
    required this.artistsConfig,
    required this.genresConfig,
    required this.albumConfig,
    required this.generalConfig,
  });

  factory SplitArtistGenreConfigsWrapper.settings() {
    return SplitArtistGenreConfigsWrapper(
      dbPath: AppPaths.TRACKS_DB_INFO.file.path,
      artistsConfig: ArtistsSplitConfig.settings(),
      genresConfig: GenresSplitConfig.settings(),
      albumConfig: SimpleSplitConfig(),
      generalConfig: GeneralSplitConfig(),
    );
  }
}

class ArtistsSplitConfig extends SplitterConfig {
  final bool addFeatArtist;

  ArtistsSplitConfig({
    required this.addFeatArtist,
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory ArtistsSplitConfig.settings({
    final bool? addFeatArtist,
    final List<String>? separators,
    final List<String>? separatorsBlacklist,
  }) {
    return ArtistsSplitConfig(
      addFeatArtist: addFeatArtist ?? settings.extractFeatArtistFromTitle.value,
      separators: separators ?? settings.trackArtistsSeparators.value,
      separatorsBlacklist: separatorsBlacklist ?? settings.trackArtistsSeparatorsBlacklist.value,
    );
  }

  factory ArtistsSplitConfig.fromMap(Map<String, dynamic> map) {
    return ArtistsSplitConfig(
      addFeatArtist: map["addFeatArtist"],
      separators: map["separators"],
      separatorsBlacklist: map["separatorsBlacklist"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "addFeatArtist": addFeatArtist,
      "separators": separators,
      "separatorsBlacklist": separatorsBlacklist,
    };
  }
}

class GenresSplitConfig extends SplitterConfig {
  GenresSplitConfig({
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory GenresSplitConfig.settings({
    final List<String>? separators,
    final List<String>? separatorsBlacklist,
  }) {
    return GenresSplitConfig(
      separators: separators ?? settings.trackGenresSeparators.value,
      separatorsBlacklist: separatorsBlacklist ?? settings.trackGenresSeparatorsBlacklist.value,
    );
  }

  factory GenresSplitConfig.fromMap(Map<String, dynamic> map) {
    return GenresSplitConfig(
      separators: map["separators"],
      separatorsBlacklist: map["separatorsBlacklist"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "separators": separators,
      "separatorsBlacklist": separatorsBlacklist,
    };
  }
}

class SimpleSplitConfig extends SplitterConfig {
  SimpleSplitConfig._({
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory SimpleSplitConfig() {
    // `/` are pretty common for album names
    // `\` could exist too
    final finalSplitters = {';', r'\\', '\u00A0'};
    return SimpleSplitConfig._(
      separators: finalSplitters.toList(),
      separatorsBlacklist: [],
    );
  }
}

class GeneralSplitConfig extends SplitterConfig {
  GeneralSplitConfig._({
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory GeneralSplitConfig() {
    return GeneralSplitConfig._(
      separators: buildSeparatorsSet().toList(),
      separatorsBlacklist: [],
    );
  }

  static Set<String> buildSeparatorsSet() {
    final finalSplitters = <String>{};
    finalSplitters.addAll(settings.trackArtistsSeparators.value);
    finalSplitters.addAll(settings.trackGenresSeparators.value);
    finalSplitters.addAll({';', ',', '//', r'\\'});
    return finalSplitters;
  }
}

class SplitDelimiter {
  final RegExp? _regex;
  const SplitDelimiter._(this._regex);

  factory SplitDelimiter.fromSingle(String singleDelimiter) {
    assert(singleDelimiter.length == 1);
    final regex = RegExp(RegExp.escape(singleDelimiter), caseSensitive: false);
    return SplitDelimiter._(regex);
  }

  factory SplitDelimiter.fromList(Iterable<String> delimiters) {
    if (delimiters.isEmpty) return const SplitDelimiter._(null);
    final regexString = delimiters.map(RegExp.escape).join('|');
    final regex = RegExp(regexString, caseSensitive: false);
    return SplitDelimiter._(regex);
  }

  // -- split before trimming, `trimAll()` turns nbsp separators into spaces
  List<String> multiSplit(String text, List<String> blacklist) {
    if (_regex == null) return [text.trimAll()];
    if (blacklist.isEmpty) return _splitTrimmed(text, _regex);
    if (blacklist.any((element) => element == text)) return [text]; // 3 times faster if true, otherwise no difference.

    final listToAddLater = <String>[];
    String filteredString = text;
    for (final b in blacklist) {
      final withoutBL = filteredString.split(b);
      if (withoutBL.length > 1) {
        filteredString = withoutBL.join();
        listToAddLater.add(b);
      }
    }

    final splitted = _splitTrimmed(filteredString, _regex);
    if (listToAddLater.isEmpty) return splitted;
    splitted.addAll(listToAddLater);
    final textTrimmed = text.trimAll();
    splitted.sort((a, b) => textTrimmed.indexOf(a).compareTo(textTrimmed.indexOf(b)));
    return splitted;
  }

  static List<String> _splitTrimmed(String text, RegExp regex) {
    return text.split(regex).map((e) => e.trimAll()).where((e) => e.isNotEmpty).toList();
  }
}

interface class SplitterConfig {
  final List<String> separators;
  final List<String> separatorsBlacklist;
  late final SplitDelimiter delimiter;

  SplitterConfig({
    required this.separators,
    required this.separatorsBlacklist,
  }) {
    delimiter = SplitDelimiter.fromList(separators);
  }

  List<String> splitText(String? string, {String? fallback}) {
    if (string == null) return fallback == null ? [] : [fallback];
    final config = this;
    final splitted = config.delimiter.multiSplit(string, config.separatorsBlacklist);
    if (splitted.isEmpty) return fallback == null ? [] : [fallback];
    return splitted;
  }
}
