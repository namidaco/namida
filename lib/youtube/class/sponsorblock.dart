// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';

class SponsorBlockSettings {
  final defaultServerAddress = 'https://sponsor.ajay.app';

  SponsorBlockSettings.custom(
    this._enabled,
    this._trackSkipCount,
    this._serverAddress,
    this._hideSkipButtonAfterMS,
    this._minimumSegmentDurationMS,
    this._removeSegmentsFromDownloads,
    Map<SponsorBlockCategory, SponsorBlockCategoryConfig>? configs,
  ) : _configs = configs ?? {} {
    this.activeCategories = _getActiveCategories(_configs);
    this.activeCategoriesNames = _getActiveCategoriesNames(_configs);
    this.downloadsRemovedCategoriesNames = _getDownloadsRemovedCategoriesNames(_configs);
  }

  static List<T> _getActiveCategoriesGlobal<T>(Map<SponsorBlockCategory, SponsorBlockCategoryConfig> configs, T Function(SponsorBlockCategory category) onMatch) {
    final list = <T>[];
    for (final category in SponsorBlockCategory.values) {
      final c = configs[category] ?? category.defaultConfig;
      if (c.action != SponsorBlockAction.disabled) {
        final item = onMatch(category);
        list.add(item);
      }
    }
    return list;
  }

  static List<SponsorBlockCategory> _getActiveCategories(Map<SponsorBlockCategory, SponsorBlockCategoryConfig> configs) {
    return _getActiveCategoriesGlobal(configs, (category) => category);
  }

  static List<String> _getActiveCategoriesNames(Map<SponsorBlockCategory, SponsorBlockCategoryConfig> configs) {
    return _getActiveCategoriesGlobal(configs, (category) => category.name);
  }

  static List<String> _getDownloadsRemovedCategoriesNames(Map<SponsorBlockCategory, SponsorBlockCategoryConfig> configs) {
    final list = <String>[];
    for (final category in SponsorBlockCategory.values) {
      if (!category.canBeRemovedFromDownloads) continue;
      final c = configs[category] ?? category.defaultConfig;
      if (c.removeFromDownloads) list.add(category.name);
    }
    return list;
  }

  factory SponsorBlockSettings() => SponsorBlockSettings.custom(null, null, null, null, null, null, null);

  late final List<SponsorBlockCategory> activeCategories;
  late final List<String> activeCategoriesNames;
  late final List<String> downloadsRemovedCategoriesNames;

  bool get enabled => _enabled ?? true;
  bool get trackSkipCount => _trackSkipCount ?? true;
  String? get serverAddress => _serverAddress;
  int get hideSkipButtonAfterMS => _hideSkipButtonAfterMS ?? 4000;
  int get minimumSegmentDurationMS => _minimumSegmentDurationMS ?? 0;
  bool get removeSegmentsFromDownloads => _removeSegmentsFromDownloads ?? false;
  Map<SponsorBlockCategory, SponsorBlockCategoryConfig> get configs => _configs;

  final bool? _enabled;
  final bool? _trackSkipCount;
  final String? _serverAddress;
  final int? _hideSkipButtonAfterMS;
  final int? _minimumSegmentDurationMS;
  final bool? _removeSegmentsFromDownloads;
  final Map<SponsorBlockCategory, SponsorBlockCategoryConfig> _configs;

  SponsorBlockSettings copyWith({
    bool? enabled,
    bool? trackSkipCount,
    String? serverAddress,
    int? hideSkipButtonAfterMS,
    int? minimumSegmentDurationMS,
    bool? removeSegmentsFromDownloads,
    Map<SponsorBlockCategory, SponsorBlockCategoryConfig>? configs,
  }) => SponsorBlockSettings.custom(
    enabled ?? this.enabled,
    trackSkipCount ?? this.trackSkipCount,
    serverAddress ?? this.serverAddress,
    hideSkipButtonAfterMS ?? this.hideSkipButtonAfterMS,
    minimumSegmentDurationMS ?? this.minimumSegmentDurationMS,
    removeSegmentsFromDownloads ?? this.removeSegmentsFromDownloads,
    configs ?? this.configs,
  );

  factory SponsorBlockSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SponsorBlockSettings();

    final enabled = json['enabled'] as bool?;
    final trackSkipCount = json['trackSkipCount'] as bool?;
    final serverAddress = json['serverAddress'] as String?;
    final hideSkipButtonAfterMS = json['hideSkipButtonAfterMS'] as int?;
    final minimumSegmentDurationMS = json['minimumSegmentDurationMS'] as int?;
    final removeSegmentsFromDownloads = json['removeSegmentsFromDownloads'] as bool?;
    final config = json['configs'] as Map?;

    final configs = <SponsorBlockCategory, SponsorBlockCategoryConfig>{};
    if (config != null) {
      for (final c in config.entries) {
        final categoryName = c.key as String?;
        final value = c.value;
        final category = SponsorBlockCategory.values.getEnum(categoryName);
        if (category != null && value is Map<String, dynamic>) {
          configs[category] = SponsorBlockCategoryConfig.fromJson(value, category);
        }
      }
    }

    return SponsorBlockSettings.custom(
      enabled,
      trackSkipCount,
      serverAddress,
      hideSkipButtonAfterMS,
      minimumSegmentDurationMS,
      removeSegmentsFromDownloads,
      configs,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'trackSkipCount': trackSkipCount,
    'serverAddress': serverAddress,
    'hideSkipButtonAfterMS': hideSkipButtonAfterMS,
    'minimumSegmentDurationMS': minimumSegmentDurationMS,
    'removeSegmentsFromDownloads': removeSegmentsFromDownloads,
    'configs': configs.map((k, v) => MapEntry(k.name, v.toJson())),
  };
}

class SponsorBlockCategoryConfig {
  final SponsorBlockAction action;
  final Color color;
  final bool removeFromDownloads;

  const SponsorBlockCategoryConfig(
    this.action,
    this.color,
    this.removeFromDownloads,
  );

  SponsorBlockCategoryConfig copyWith({
    SponsorBlockAction? action,
    Color? color,
    bool? removeFromDownloads,
  }) => SponsorBlockCategoryConfig(
    action ?? this.action,
    color ?? this.color,
    removeFromDownloads ?? this.removeFromDownloads,
  );

  factory SponsorBlockCategoryConfig.fromJson(Map<String, dynamic> valueJson, SponsorBlockCategory category) {
    final actionName = valueJson['action'] as String?;
    final action = SponsorBlockAction.values.getEnum(actionName);
    final color = valueJson['color'] as int?;
    final removeFromDownloads = valueJson['removeFromDownloads'] as bool?;

    return SponsorBlockCategoryConfig(
      action ?? category.defaultConfig.action,
      color != null ? Color(color) : category.defaultConfig.color,
      removeFromDownloads ?? category.defaultConfig.removeFromDownloads,
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'color': color.intValue,
    'removeFromDownloads': removeFromDownloads,
  };
}

enum SponsorBlockCategory {
  sponsor(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB200D400), true)),
  selfpromo(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2FFFF00), true)),
  interaction(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2CC00FF), true)),
  poi_highlight(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2FF1684), false)),
  intro(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB200FFFF), false)),
  outro(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB20202ED), false)),
  preview(SponsorBlockCategoryConfig(SponsorBlockAction.disabled, Color(0xB2008FD6), false)),
  hook(SponsorBlockCategoryConfig(SponsorBlockAction.disabled, Color(0xB2395699), false)),
  filler(SponsorBlockCategoryConfig(SponsorBlockAction.disabled, Color(0xB27300FF), false)),
  music_offtopic(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2FF9900), false));

  const SponsorBlockCategory(this.defaultConfig);
  final SponsorBlockCategoryConfig defaultConfig;

  /// [poi_highlight] is a single point in time rather than a range, there is nothing to cut out.
  bool get canBeRemovedFromDownloads => this != SponsorBlockCategory.poi_highlight;
}

enum SponsorBlockAction {
  autoSkip,
  autoSkipOnce,
  showSkipButton,
  showInSeekbar,
  disabled,
}
