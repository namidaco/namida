// ignore_for_file: constant_identifier_names

class ReturnYoutubeDislikeSettings {
  final defaultWebsiteUrl = 'https://returnyoutubedislike.com';

  ReturnYoutubeDislikeSettings.custom(
    this._enabled,
  );

  factory ReturnYoutubeDislikeSettings() => ReturnYoutubeDislikeSettings.custom(null);

  bool get enabled => _enabled ?? false;

  final bool? _enabled;

  ReturnYoutubeDislikeSettings copyWith({
    bool? enabled,
  }) =>
      ReturnYoutubeDislikeSettings.custom(
        enabled ?? this.enabled,
      );

  factory ReturnYoutubeDislikeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReturnYoutubeDislikeSettings();

    final enabled = json['enabled'] as bool?;

    return ReturnYoutubeDislikeSettings.custom(
      enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
      };
}
