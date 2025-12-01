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
    Map<SponsorBlockCategory, SponsorBlockCategoryConfig>? configs,
  ) : _configs = configs ?? {} {
    this.activeCategories = _getActiveCategories(_configs);
    this.activeCategoriesNames = _getActiveCategoriesNames(_configs);
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

  factory SponsorBlockSettings() => SponsorBlockSettings.custom(null, null, null, null, null, null);

  late final List<SponsorBlockCategory> activeCategories;
  late final List<String> activeCategoriesNames;

  bool get enabled => _enabled ?? true;
  bool get trackSkipCount => _trackSkipCount ?? true;
  String? get serverAddress => _serverAddress;
  int get hideSkipButtonAfterMS => _hideSkipButtonAfterMS ?? 3000;
  int get minimumSegmentDurationMS => _minimumSegmentDurationMS ?? 0;
  Map<SponsorBlockCategory, SponsorBlockCategoryConfig> get configs => _configs;

  final bool? _enabled;
  final bool? _trackSkipCount;
  final String? _serverAddress;
  final int? _hideSkipButtonAfterMS;
  final int? _minimumSegmentDurationMS;
  final Map<SponsorBlockCategory, SponsorBlockCategoryConfig> _configs;

  SponsorBlockSettings copyWith({
    bool? enabled,
    bool? trackSkipCount,
    String? serverAddress,
    int? hideSkipButtonAfterMS,
    int? minimumSegmentDurationMS,
    Map<SponsorBlockCategory, SponsorBlockCategoryConfig>? configs,
  }) =>
      SponsorBlockSettings.custom(
        enabled ?? this.enabled,
        trackSkipCount ?? this.trackSkipCount,
        serverAddress ?? this.serverAddress,
        hideSkipButtonAfterMS ?? this.hideSkipButtonAfterMS,
        minimumSegmentDurationMS ?? this.minimumSegmentDurationMS,
        configs ?? this.configs,
      );

  factory SponsorBlockSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SponsorBlockSettings();

    final enabled = json['enabled'] as bool?;
    final trackSkipCount = json['trackSkipCount'] as bool?;
    final serverAddress = json['serverAddress'] as String?;
    final hideSkipButtonAfterMS = json['hideSkipButtonAfterMS'] as int?;
    final minimumSegmentDurationMS = json['minimumSegmentDurationMS'] as int?;
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
      configs,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'trackSkipCount': trackSkipCount,
        'serverAddress': serverAddress,
        'hideSkipButtonAfterMS': hideSkipButtonAfterMS,
        'minimumSegmentDurationMS': minimumSegmentDurationMS,
        'configs': configs.map((k, v) => MapEntry(k.name, v.toJson())),
      };
}

class SponsorBlockCategoryConfig {
  final SponsorBlockAction action;
  final Color color;

  const SponsorBlockCategoryConfig(
    this.action,
    this.color,
  );

  SponsorBlockCategoryConfig copyWith({
    SponsorBlockAction? action,
    Color? color,
  }) =>
      SponsorBlockCategoryConfig(
        action ?? this.action,
        color ?? this.color,
      );

  factory SponsorBlockCategoryConfig.fromJson(Map<String, dynamic> valueJson, SponsorBlockCategory category) {
    final actionName = valueJson['action'] as String?;
    final action = SponsorBlockAction.values.getEnum(actionName);
    final color = valueJson['color'] as int?;

    return SponsorBlockCategoryConfig(
      action ?? category.defaultConfig.action,
      color != null ? Color(color) : category.defaultConfig.color,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'color': color.intValue,
      };
}

enum SponsorBlockCategory {
  sponsor(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB200D400))),
  selfpromo(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2FFFF00))),
  interaction(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2CC00FF))),
  poi_highlight(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2FF1684))),
  intro(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB200FFFF))),
  outro(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB20202ED))),
  preview(SponsorBlockCategoryConfig(SponsorBlockAction.disabled, Color(0xB2008FD6))),
  hook(SponsorBlockCategoryConfig(SponsorBlockAction.disabled, Color(0xB2395699))),
  filler(SponsorBlockCategoryConfig(SponsorBlockAction.disabled, Color(0xB27300FF))),
  music_offtopic(SponsorBlockCategoryConfig(SponsorBlockAction.showSkipButton, Color(0xB2FF9900)));

  const SponsorBlockCategory(this.defaultConfig);
  final SponsorBlockCategoryConfig defaultConfig;
}

enum SponsorBlockAction {
  autoSkip,
  autoSkipOnce,
  showSkipButton,
  showInSeekbar,
  disabled,
}
