part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleBoolean extends SmartPlaylistRuleBase<Null, Null, SmartPlaylistRuleFilterBoolean, SmartPlaylistRuleFilterBooleanSource> {
  SmartPlaylistRuleBoolean({
    required super.filter,
    required super.source,
    required super.enableCleanup,
  }) : super(type: SmartPlaylistFilterType.boolean, data: null, data2: null, clockOnly: false, relativeDuration: null);

  @override
  SmartPlaylistRuleBoolean copyWith({
    (Null data, Null data2)? datas,
    SmartPlaylistRuleFilterBoolean? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleBoolean(
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
  );

  @override
  String datasDisplayText() => data ?? '';

  @override
  Null textToData(String? value) => null;

  @override
  Null textToData2(String? value) => textToData(value);

  @override
  String? dataToText(Null data) => null;

  @override
  String? data2ToText(Null data2) => null;

  @override
  String? toHintText() => null;

  @override
  String? dataValidator(String? value) {
    if (value == null || value.isEmpty) return lang.emptyValue;
    return null;
  }

  @override
  String? validate() {
    return null;
  }

  late final bool Function(bool? trackBoolean) _booleanFn = switch (filter) {
    SmartPlaylistRuleFilterBoolean.isTrue => (trackBoolean) => trackBoolean == true,
    SmartPlaylistRuleFilterBoolean.isFalse => (trackBoolean) => trackBoolean == false,
  };

  @override
  bool isMatch(Track track) {
    return switch (source) {
      SmartPlaylistRuleFilterBooleanSource.isLossless => _booleanFn(track.isLossless),
      SmartPlaylistRuleFilterBooleanSource.isFavourite => _booleanFn(track.isFavourite),
      SmartPlaylistRuleFilterBooleanSource.isSingle => _booleanFn(track.albumsIdentifiersModified.any((albumIdentifier) => albumIdentifier.isSingle())),
    };
  }

  factory SmartPlaylistRuleBoolean.fromMap(Map map) {
    return SmartPlaylistRuleBoolean(
      filter: SmartPlaylistRuleFilterBoolean.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterBooleanSource.values.getEnum(map['source'])!,
      enableCleanup: map['enableCleanup'] == true,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'filter': filter.name,
      'source': source.name,
      if (enableCleanup) 'enableCleanup': enableCleanup,
    };
  }
}

enum SmartPlaylistRuleFilterBoolean with SmartPlaylistRuleFilter {
  isTrue,
  isFalse,
  ;

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.boolean;

  @override
  final bool requiresDataField;
  @override
  final bool requiresData2Field;

  // ignore: unused_element_parameter
  const SmartPlaylistRuleFilterBoolean({this.requiresDataField = false, this.requiresData2Field = false});

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterBoolean.isTrue => lang.isTrue,
    SmartPlaylistRuleFilterBoolean.isFalse => lang.isFalse,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterBoolean.isTrue => Broken.tick_circle,
    SmartPlaylistRuleFilterBoolean.isFalse => Broken.close_circle,
  };

  @override
  String? toIconText() => null;
}

enum SmartPlaylistRuleFilterBooleanSource with SmartPlaylistRuleFilterSource {
  isLossless,
  isFavourite,
  isSingle,
  ;

  const SmartPlaylistRuleFilterBooleanSource();

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.boolean;

  @override
  SmartPlaylistRuleFilter get recommendedFilter => SmartPlaylistRuleFilterBoolean.isTrue;

  @override
  bool get supportsCleanup => false;

  @override
  bool get supportsClockOnly => false;

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterBooleanSource.isLossless => lang.lossless,
    SmartPlaylistRuleFilterBooleanSource.isFavourite => lang.favourite,
    SmartPlaylistRuleFilterBooleanSource.isSingle => lang.single,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterBooleanSource.isLossless => Broken.voice_cricle,
    SmartPlaylistRuleFilterBooleanSource.isFavourite => Broken.heart,
    SmartPlaylistRuleFilterBooleanSource.isSingle => Broken.music_square,
  };
}
