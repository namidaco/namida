part of 'settings_controller.dart';

class _YoutubeSettings with SettingsFileWriter {
  _YoutubeSettings._internal();

  static const _defaultFilenameBuilder = '[%(playlist_autonumber)s] %(video_title)s [(%(channel)s)].%(ext)s';

  final ytVisibleShorts = <YTVisibleShortPlaces, bool>{}.obs;
  final ytVisibleMixes = <YTVisibleMixesPlaces, bool>{}.obs;
  final showChannelWatermarkFullscreen = true.obs;
  final showVideoEndcards = true.obs;
  final autoStartRadio = false.obs;

  final ytDownloadLocation = AppDirs.YOUTUBE_DOWNLOADS_DEFAULT.obs;
  final ytMiniplayerDimAfterSeconds = 15.obs;
  final ytMiniplayerDimOpacity = 0.5.obs;
  final youtubeStyleMiniplayer = true.obs;
  final preferNewComments = false.obs;
  final autoExtractVideoTagsFromInfo = true.obs;
  final isAudioOnlyMode = false.obs;
  final rememberAudioOnly = false.obs;
  final topComments = true.obs;
  final onYoutubeLinkOpen = OnYoutubeLinkOpenAction.alwaysAsk.obs;
  final tapToSeek = YTSeekActionMode.expandedMiniplayer.obs;
  final dragToSeek = YTSeekActionMode.all.obs;
  final downloadFilenameBuilder = _defaultFilenameBuilder.obs;
  final initialDefaultMetadataTags = <String, String>{};

  bool markVideoWatched = true;
  InnertubeClients? innertubeClient;
  bool whiteVideoBGInLightMode = false;
  bool enableDimInLightMode = true;

  void save({
    bool? showChannelWatermarkFullscreen,
    bool? showVideoEndcards,
    bool? autoStartRadio,
    String? ytDownloadLocation,
    int? ytMiniplayerDimAfterSeconds,
    double? ytMiniplayerDimOpacity,
    bool? youtubeStyleMiniplayer,
    bool? preferNewComments,
    bool? isAudioOnlyMode,
    bool? rememberAudioOnly,
    bool? topComments,
    bool? autoExtractVideoTagsFromInfo,
    OnYoutubeLinkOpenAction? onYoutubeLinkOpen,
    YTSeekActionMode? tapToSeek,
    YTSeekActionMode? dragToSeek,
    String? downloadFilenameBuilder,
    bool? markVideoWatched,
    InnertubeClients? innertubeClient,
    bool setDefaultInnertubeClient = false,
    bool? whiteVideoBGInLightMode,
    bool? enableDimInLightMode,
  }) {
    if (showChannelWatermarkFullscreen != null) this.showChannelWatermarkFullscreen.value = showChannelWatermarkFullscreen;
    if (showVideoEndcards != null) this.showVideoEndcards.value = showVideoEndcards;
    if (autoStartRadio != null) this.autoStartRadio.value = autoStartRadio;

    if (ytDownloadLocation != null) this.ytDownloadLocation.value = ytDownloadLocation;
    if (ytMiniplayerDimAfterSeconds != null) this.ytMiniplayerDimAfterSeconds.value = ytMiniplayerDimAfterSeconds;
    if (ytMiniplayerDimOpacity != null) this.ytMiniplayerDimOpacity.value = ytMiniplayerDimOpacity;
    if (youtubeStyleMiniplayer != null) this.youtubeStyleMiniplayer.value = youtubeStyleMiniplayer;
    if (preferNewComments != null) this.preferNewComments.value = preferNewComments;
    if (isAudioOnlyMode != null) this.isAudioOnlyMode.value = isAudioOnlyMode;
    if (rememberAudioOnly != null) this.rememberAudioOnly.value = rememberAudioOnly;
    if (topComments != null) this.topComments.value = topComments;
    if (autoExtractVideoTagsFromInfo != null) this.autoExtractVideoTagsFromInfo.value = autoExtractVideoTagsFromInfo;
    if (onYoutubeLinkOpen != null) this.onYoutubeLinkOpen.value = onYoutubeLinkOpen;
    if (tapToSeek != null) this.tapToSeek.value = tapToSeek;
    if (dragToSeek != null) this.dragToSeek.value = dragToSeek;
    if (downloadFilenameBuilder != null) this.downloadFilenameBuilder.value = downloadFilenameBuilder;

    if (markVideoWatched != null) this.markVideoWatched = markVideoWatched;
    if (innertubeClient != null || setDefaultInnertubeClient) this.innertubeClient = innertubeClient;
    if (whiteVideoBGInLightMode != null) this.whiteVideoBGInLightMode = whiteVideoBGInLightMode;
    if (enableDimInLightMode != null) this.enableDimInLightMode = enableDimInLightMode;
    _writeToStorage();
  }

  void updateShortsVisible(YTVisibleShortPlaces place, bool show) {
    ytVisibleShorts[place] = show;
    _writeToStorage();
  }

  void updateMixesVisible(YTVisibleMixesPlaces place, bool show) {
    ytVisibleMixes[place] = show;
    _writeToStorage();
  }

  void prepareSettingsFile() {
    final json = prepareSettingsFile_();
    if (json is! Map) return;

    try {
      showChannelWatermarkFullscreen.value = json['showChannelWatermarkFullscreen'] ?? showChannelWatermarkFullscreen.value;
      showVideoEndcards.value = json['showVideoEndcards'] ?? showVideoEndcards.value;
      autoStartRadio.value = json['autoStartRadio'] ?? autoStartRadio.value;

      ytDownloadLocation.value = json['ytDownloadLocation'] ?? ytDownloadLocation.value;
      ytMiniplayerDimAfterSeconds.value = json['ytMiniplayerDimAfterSeconds'] ?? ytMiniplayerDimAfterSeconds.value;
      ytMiniplayerDimOpacity.value = json['ytMiniplayerDimOpacity'] ?? ytMiniplayerDimOpacity.value;
      youtubeStyleMiniplayer.value = json['youtubeStyleMiniplayer'] ?? youtubeStyleMiniplayer.value;
      preferNewComments.value = json['preferNewComments'] ?? preferNewComments.value;
      autoExtractVideoTagsFromInfo.value = json['autoExtractVideoTagsFromInfo'] ?? autoExtractVideoTagsFromInfo.value;
      rememberAudioOnly.value = json['rememberAudioOnly'] ?? rememberAudioOnly.value;
      if (rememberAudioOnly.value) isAudioOnlyMode.value = json['isAudioOnlyMode'] ?? isAudioOnlyMode.value;
      topComments.value = json['topComments'] ?? topComments.value;
      onYoutubeLinkOpen.value = OnYoutubeLinkOpenAction.values.getEnum(json['onYoutubeLinkOpen']) ?? onYoutubeLinkOpen.value;
      tapToSeek.value = YTSeekActionMode.values.getEnum(json['tapToSeek']) ?? tapToSeek.value;
      dragToSeek.value = YTSeekActionMode.values.getEnum(json['dragToSeek']) ?? dragToSeek.value;

      ytVisibleShorts.value = (json['ytVisibleShorts'] as Map?)?.map((key, value) => MapEntry(YTVisibleShortPlaces.values.getEnum(key)!, value)) ?? ytVisibleShorts.value;
      ytVisibleMixes.value = (json['ytVisibleMixes'] as Map?)?.map((key, value) => MapEntry(YTVisibleMixesPlaces.values.getEnum(key)!, value)) ?? ytVisibleMixes.value;
      downloadFilenameBuilder.value = json['downloadFilenameBuilder'] ?? downloadFilenameBuilder.value;

      final initialDefaultMetadataTagsInStorage = (json['initialDefaultMetadataTags'] as Map?);
      if (initialDefaultMetadataTagsInStorage != null) {
        for (final e in initialDefaultMetadataTagsInStorage.entries) {
          initialDefaultMetadataTags[e.key] = e.value;
        }
      }

      markVideoWatched = json['markVideoWatched'] ?? markVideoWatched;
      innertubeClient = InnertubeClients.values.getEnum(json['innertubeClient']);
      whiteVideoBGInLightMode = json['whiteVideoBGInLightMode'] ?? whiteVideoBGInLightMode;
      enableDimInLightMode = json['enableDimInLightMode'] ?? enableDimInLightMode;
    } catch (e) {
      printy(e, isError: true);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'showChannelWatermarkFullscreen': showChannelWatermarkFullscreen.value,
        'showVideoEndcards': showVideoEndcards.value,
        'autoStartRadio': autoStartRadio.value,
        'ytDownloadLocation': ytDownloadLocation.value,
        'ytMiniplayerDimAfterSeconds': ytMiniplayerDimAfterSeconds.value,
        'ytMiniplayerDimOpacity': ytMiniplayerDimOpacity.value,
        'youtubeStyleMiniplayer': youtubeStyleMiniplayer.value,
        'preferNewComments': preferNewComments.value,
        'autoExtractVideoTagsFromInfo': autoExtractVideoTagsFromInfo.value,
        'isAudioOnlyMode': isAudioOnlyMode.value,
        'rememberAudioOnly': rememberAudioOnly.value,
        'topComments': topComments.value,
        'onYoutubeLinkOpen': onYoutubeLinkOpen.value.name,
        'tapToSeek': tapToSeek.value.name,
        'dragToSeek': dragToSeek.value.name,
        'ytVisibleShorts': ytVisibleShorts.map((key, value) => MapEntry(key.name, value)),
        'ytVisibleMixes': ytVisibleMixes.map((key, value) => MapEntry(key.name, value)),
        'downloadFilenameBuilder': downloadFilenameBuilder.value,
        'initialDefaultMetadataTags': initialDefaultMetadataTags,
        'markVideoWatched': markVideoWatched,
        'innertubeClient': innertubeClient?.name,
        'whiteVideoBGInLightMode': whiteVideoBGInLightMode,
        'enableDimInLightMode': enableDimInLightMode,
      };

  Future<void> _writeToStorage() => writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_YOUTUBE;
}
