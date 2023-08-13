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
      addFeatArtist: addFeatArtist ?? SettingsController.inst.extractFeatArtistFromTitle.value,
      separators: separators ?? SettingsController.inst.trackArtistsSeparators,
      separatorsBlacklist: separatorsBlacklist ?? SettingsController.inst.trackArtistsSeparatorsBlacklist,
    );
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
      separators: separators ?? SettingsController.inst.trackGenresSeparators,
      separatorsBlacklist: separatorsBlacklist ?? SettingsController.inst.trackGenresSeparatorsBlacklist,
    );
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
