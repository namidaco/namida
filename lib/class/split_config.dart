import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

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

  List<String> multiSplit(String text, List<String> blacklist) {
    if (_regex == null) return [text];

    final listToAddLater = <String>[];
    String filteredString = '';
    if (blacklist.isNotEmpty) {
      blacklist.loop((b) {
        final withoutBL = text.split(b);
        withoutBL.loop((s) => filteredString += s.trim());
        if (withoutBL.length > 1) listToAddLater.add(b);
      });
    } else {
      filteredString = text;
    }

    final splitted = filteredString.split(_regex).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    splitted.addAll(listToAddLater);
    if (splitted.length > 1) splitted.sortBy((e) => text.indexOf(e));
    return splitted;
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

  List<String> splitText(String? string, {required String fallback}) {
    if (string == null) return [fallback];
    final config = this;
    final splitted = config.delimiter.multiSplit(string.trimAll(), config.separatorsBlacklist);
    if (splitted.isEmpty) return [fallback];
    return splitted;
  }
}
