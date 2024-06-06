import 'package:namida/controller/settings_controller.dart';

class ArtistsSplitConfig extends _SplitterConfig {
  final bool addFeatArtist;

  const ArtistsSplitConfig({
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

class GenresSplitConfig extends _SplitterConfig {
  const GenresSplitConfig({
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

interface class _SplitterConfig {
  final List<String> separators;
  final List<String> separatorsBlacklist;

  const _SplitterConfig({
    required this.separators,
    required this.separatorsBlacklist,
  });
}
