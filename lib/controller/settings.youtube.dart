part of 'settings_controller.dart';

class _YoutubeSettings with SettingsFileWriter {
  _YoutubeSettings._internal();

  final ytVisibleShorts = <YTVisibleShortPlaces, bool>{}.obs;
  final ytVisibleMixes = <YTVisibleMixesPlaces, bool>{}.obs;
  final showChannelWatermarkFullscreen = true.obs;

  int addToPlaylistsTabIndex = 0;
  bool markVideoWatched = true;
  InnertubeClients? innertubeClient;
  bool whiteVideoBGInLightMode = false;
  bool enableDimInLightMode = true;

  void save({
    bool? showChannelWatermarkFullscreen,
    int? addToPlaylistsTabIndex,
    bool? markVideoWatched,
    InnertubeClients? innertubeClient,
    bool setDefaultInnertubeClient = false,
    bool? whiteVideoBGInLightMode,
    bool? enableDimInLightMode,
  }) {
    if (showChannelWatermarkFullscreen != null) this.showChannelWatermarkFullscreen.value = showChannelWatermarkFullscreen;
    if (addToPlaylistsTabIndex != null) this.addToPlaylistsTabIndex = addToPlaylistsTabIndex;
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

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json == null) return;
    try {
      json as Map;
      showChannelWatermarkFullscreen.value = json['showChannelWatermarkFullscreen'] ?? showChannelWatermarkFullscreen.value;
      ytVisibleShorts.value = (json['ytVisibleShorts'] as Map?)?.map((key, value) => MapEntry(YTVisibleShortPlaces.values.getEnum(key)!, value)) ?? ytVisibleShorts.value;
      ytVisibleMixes.value = (json['ytVisibleMixes'] as Map?)?.map((key, value) => MapEntry(YTVisibleMixesPlaces.values.getEnum(key)!, value)) ?? ytVisibleMixes.value;
      addToPlaylistsTabIndex = json['addToPlaylistsTabIndex'] ?? addToPlaylistsTabIndex;
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
        'showChannelWatermarkFullscreen': showChannelWatermarkFullscreen,
        'ytVisibleShorts': ytVisibleShorts.map((key, value) => MapEntry(key.convertToString, value)),
        'ytVisibleMixes': ytVisibleMixes.map((key, value) => MapEntry(key.convertToString, value)),
        'addToPlaylistsTabIndex': addToPlaylistsTabIndex,
        'markVideoWatched': markVideoWatched,
        'innertubeClient': innertubeClient?.convertToString,
        'whiteVideoBGInLightMode': whiteVideoBGInLightMode,
        'enableDimInLightMode': enableDimInLightMode,
      };

  Future<void> _writeToStorage() => writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_YOUTUBE;
}
