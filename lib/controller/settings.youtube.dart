part of 'settings_controller.dart';

class _YoutubeSettings with SettingsFileWriter {
  _YoutubeSettings._internal();

  String get defaultFilenameBuilder => _defaultFilenameBuilder;

  static const _defaultFilenameBuilder = '[%(playlist_autonumber)s] %(video_title)s [(%(channel)s)].%(ext)s';

  final ytVisibleShorts = <YTVisibleShortPlaces, bool>{}.obs;
  final ytVisibleMixes = <YTVisibleMixesPlaces, bool>{}.obs;
  final showChannelWatermarkFullscreen = true.obs;
  final showVideoEndcards = true.obs;
  final autoStartRadio = false.obs;
  final personalizedRelatedVideos = true.obs;

  final ytDownloadLocation = AppDirs.YOUTUBE_DOWNLOADS_DEFAULT.obs;
  final ytMiniplayerDimAfterSeconds = 15.obs;
  final ytMiniplayerDimOpacity = 0.5.obs;
  final youtubeStyleMiniplayer = true.obs;
  final preferNewComments = false.obs;
  final autoExtractVideoTagsFromInfo = true.obs;
  final fallbackExtractInfoDescription = true.obs;
  final isAudioOnlyMode = false.obs;
  final dataSaverMode = DataSaverMode.off.obs;
  final dataSaverModeMobile = DataSaverMode.medium.obs;
  final rememberAudioOnly = false.obs;
  final topComments = true.obs;
  final onYoutubeLinkOpen = OnYoutubeLinkOpenAction.alwaysAsk.obs;
  final tapToSeek = YTSeekActionMode.expandedMiniplayer.obs;
  final dragToSeek = YTSeekActionMode.all.obs;
  final downloadFilenameBuilder = _defaultFilenameBuilder.obs;
  final initialDefaultMetadataTags = <String, String>{};

  // -- currently used for windows
  final downloadNotifications = DownloadNotifications.showFailedOnly.obs;

  bool markVideoWatched = true;
  InnertubeClients? innertubeClient;
  bool whiteVideoBGInLightMode = false;
  bool enableDimInLightMode = true;
  bool allowExperimentalCodecs = false;

  void save({
    bool? showChannelWatermarkFullscreen,
    bool? showVideoEndcards,
    bool? autoStartRadio,
    bool? personalizedRelatedVideos,
    String? ytDownloadLocation,
    int? ytMiniplayerDimAfterSeconds,
    double? ytMiniplayerDimOpacity,
    bool? youtubeStyleMiniplayer,
    bool? preferNewComments,
    bool? isAudioOnlyMode,
    DataSaverMode? dataSaverMode,
    DataSaverMode? dataSaverModeMobile,
    bool? rememberAudioOnly,
    bool? topComments,
    bool? autoExtractVideoTagsFromInfo,
    bool? fallbackExtractInfoDescription,
    OnYoutubeLinkOpenAction? onYoutubeLinkOpen,
    YTSeekActionMode? tapToSeek,
    YTSeekActionMode? dragToSeek,
    String? downloadFilenameBuilder,
    DownloadNotifications? downloadNotifications,
    bool? markVideoWatched,
    InnertubeClients? innertubeClient,
    bool setDefaultInnertubeClient = false,
    bool? whiteVideoBGInLightMode,
    bool? enableDimInLightMode,
    bool? allowExperimentalCodecs,
  }) {
    if (showChannelWatermarkFullscreen != null) this.showChannelWatermarkFullscreen.value = showChannelWatermarkFullscreen;
    if (showVideoEndcards != null) this.showVideoEndcards.value = showVideoEndcards;
    if (autoStartRadio != null) this.autoStartRadio.value = autoStartRadio;
    if (personalizedRelatedVideos != null) this.personalizedRelatedVideos.value = personalizedRelatedVideos;

    if (ytDownloadLocation != null) this.ytDownloadLocation.value = ytDownloadLocation;
    if (ytMiniplayerDimAfterSeconds != null) this.ytMiniplayerDimAfterSeconds.value = ytMiniplayerDimAfterSeconds;
    if (ytMiniplayerDimOpacity != null) this.ytMiniplayerDimOpacity.value = ytMiniplayerDimOpacity;
    if (youtubeStyleMiniplayer != null) this.youtubeStyleMiniplayer.value = youtubeStyleMiniplayer;
    if (preferNewComments != null) this.preferNewComments.value = preferNewComments;
    if (isAudioOnlyMode != null) this.isAudioOnlyMode.value = isAudioOnlyMode;
    if (dataSaverMode != null) this.dataSaverMode.value = dataSaverMode;
    if (dataSaverModeMobile != null) this.dataSaverModeMobile.value = dataSaverModeMobile;
    if (rememberAudioOnly != null) this.rememberAudioOnly.value = rememberAudioOnly;
    if (topComments != null) this.topComments.value = topComments;
    if (autoExtractVideoTagsFromInfo != null) this.autoExtractVideoTagsFromInfo.value = autoExtractVideoTagsFromInfo;
    if (fallbackExtractInfoDescription != null) this.fallbackExtractInfoDescription.value = fallbackExtractInfoDescription;
    if (onYoutubeLinkOpen != null) this.onYoutubeLinkOpen.value = onYoutubeLinkOpen;
    if (tapToSeek != null) this.tapToSeek.value = tapToSeek;
    if (dragToSeek != null) this.dragToSeek.value = dragToSeek;
    if (downloadFilenameBuilder != null) this.downloadFilenameBuilder.value = downloadFilenameBuilder;
    if (downloadNotifications != null) this.downloadNotifications.value = downloadNotifications;

    if (markVideoWatched != null) this.markVideoWatched = markVideoWatched;
    if (innertubeClient != null || setDefaultInnertubeClient) this.innertubeClient = innertubeClient;
    if (whiteVideoBGInLightMode != null) this.whiteVideoBGInLightMode = whiteVideoBGInLightMode;
    if (enableDimInLightMode != null) this.enableDimInLightMode = enableDimInLightMode;
    if (allowExperimentalCodecs != null) this.allowExperimentalCodecs = allowExperimentalCodecs;
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

  @override
  void applyKuruSettings() {
    ytVisibleShorts.value = <YTVisibleShortPlaces, bool>{
      YTVisibleShortPlaces.history: false,
      YTVisibleShortPlaces.homeFeed: false,
      YTVisibleShortPlaces.relatedVideos: false,
      YTVisibleShortPlaces.search: false,
    };
    personalizedRelatedVideos.value = false;
    ytMiniplayerDimAfterSeconds.value = 0;
    ytMiniplayerDimOpacity.value = 0.6;
    fallbackExtractInfoDescription.value = false;
    rememberAudioOnly.value = true;
    whiteVideoBGInLightMode = true;
    enableDimInLightMode = false;
    dataSaverMode.value = DataSaverMode.medium;
  }

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      showChannelWatermarkFullscreen.value = json['showChannelWatermarkFullscreen'] ?? showChannelWatermarkFullscreen.value;
      showVideoEndcards.value = json['showVideoEndcards'] ?? showVideoEndcards.value;
      autoStartRadio.value = json['autoStartRadio'] ?? autoStartRadio.value;
      personalizedRelatedVideos.value = json['personalizedRelatedVideos'] ?? personalizedRelatedVideos.value;

      ytDownloadLocation.value = json['ytDownloadLocation'] ?? ytDownloadLocation.value;
      ytMiniplayerDimAfterSeconds.value = json['ytMiniplayerDimAfterSeconds'] ?? ytMiniplayerDimAfterSeconds.value;
      ytMiniplayerDimOpacity.value = json['ytMiniplayerDimOpacity'] ?? ytMiniplayerDimOpacity.value;
      youtubeStyleMiniplayer.value = json['youtubeStyleMiniplayer'] ?? youtubeStyleMiniplayer.value;
      preferNewComments.value = json['preferNewComments'] ?? preferNewComments.value;
      autoExtractVideoTagsFromInfo.value = json['autoExtractVideoTagsFromInfo'] ?? autoExtractVideoTagsFromInfo.value;
      fallbackExtractInfoDescription.value = json['fallbackExtractInfoDescription'] ?? fallbackExtractInfoDescription.value;
      rememberAudioOnly.value = json['rememberAudioOnly'] ?? rememberAudioOnly.value;
      if (rememberAudioOnly.value) isAudioOnlyMode.value = json['isAudioOnlyMode'] ?? isAudioOnlyMode.value;
      dataSaverMode.value = DataSaverMode.values.getEnum(json['dataSaverMode']) ?? dataSaverMode.value;
      dataSaverModeMobile.value = DataSaverMode.values.getEnum(json['dataSaverModeMobile']) ?? dataSaverModeMobile.value;
      topComments.value = json['topComments'] ?? topComments.value;
      onYoutubeLinkOpen.value = OnYoutubeLinkOpenAction.values.getEnum(json['onYoutubeLinkOpen']) ?? onYoutubeLinkOpen.value;
      tapToSeek.value = YTSeekActionMode.values.getEnum(json['tapToSeek']) ?? tapToSeek.value;
      dragToSeek.value = YTSeekActionMode.values.getEnum(json['dragToSeek']) ?? dragToSeek.value;

      ytVisibleShorts.value = (json['ytVisibleShorts'] as Map?)?.map((key, value) => MapEntry(YTVisibleShortPlaces.values.getEnum(key)!, value)) ?? ytVisibleShorts.value;
      ytVisibleMixes.value = (json['ytVisibleMixes'] as Map?)?.map((key, value) => MapEntry(YTVisibleMixesPlaces.values.getEnum(key)!, value)) ?? ytVisibleMixes.value;
      downloadFilenameBuilder.value = json['downloadFilenameBuilder'] ?? downloadFilenameBuilder.value;
      downloadNotifications.value = DownloadNotifications.values.getEnum(json['downloadNotifications']) ?? downloadNotifications.value;

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
      allowExperimentalCodecs = json['allowExperimentalCodecs'] ?? allowExperimentalCodecs;
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'showChannelWatermarkFullscreen': showChannelWatermarkFullscreen.value,
        'showVideoEndcards': showVideoEndcards.value,
        'autoStartRadio': autoStartRadio.value,
        'personalizedRelatedVideos': personalizedRelatedVideos.value,
        'ytDownloadLocation': ytDownloadLocation.value,
        'ytMiniplayerDimAfterSeconds': ytMiniplayerDimAfterSeconds.value,
        'ytMiniplayerDimOpacity': ytMiniplayerDimOpacity.value,
        'youtubeStyleMiniplayer': youtubeStyleMiniplayer.value,
        'preferNewComments': preferNewComments.value,
        'autoExtractVideoTagsFromInfo': autoExtractVideoTagsFromInfo.value,
        'fallbackExtractInfoDescription': fallbackExtractInfoDescription.value,
        'isAudioOnlyMode': isAudioOnlyMode.value,
        'dataSaverMode': dataSaverMode.value.name,
        'dataSaverModeMobile': dataSaverModeMobile.value.name,
        'rememberAudioOnly': rememberAudioOnly.value,
        'topComments': topComments.value,
        'onYoutubeLinkOpen': onYoutubeLinkOpen.value.name,
        'tapToSeek': tapToSeek.value.name,
        'dragToSeek': dragToSeek.value.name,
        'ytVisibleShorts': ytVisibleShorts.map((key, value) => MapEntry(key.name, value)),
        'ytVisibleMixes': ytVisibleMixes.map((key, value) => MapEntry(key.name, value)),
        'downloadFilenameBuilder': downloadFilenameBuilder.value,
        'downloadNotifications': downloadNotifications.value.name,
        'initialDefaultMetadataTags': initialDefaultMetadataTags,
        'markVideoWatched': markVideoWatched,
        'innertubeClient': innertubeClient?.name,
        'whiteVideoBGInLightMode': whiteVideoBGInLightMode,
        'enableDimInLightMode': enableDimInLightMode,
        'allowExperimentalCodecs': allowExperimentalCodecs,
      };

  Future<void> _writeToStorage() => writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_YOUTUBE;
}
