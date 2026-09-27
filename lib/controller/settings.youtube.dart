part of 'settings_controller.dart';

class _YoutubeSettings extends _SettingsKeysWriter {
  _YoutubeSettings._internal();

  int get kMaxDaysForPageCacheDuration => kDefaultMaxDaysForPageCacheDuration;
  int get kMinutesInMaxDaysForPageCache => kDefaultMinutesInMaxDaysForPageCache;

  static const int kDefaultMaxDaysForPageCacheDuration = 90;
  static const int kDefaultMinutesInMaxDaysForPageCache = kDefaultMaxDaysForPageCacheDuration * (24 * 60);

  String get defaultFilenameBuilder => _defaultFilenameBuilder;

  static const _defaultFilenameBuilder = '[%(playlist_autonumber)s] %(video_title)s [(%(channel)s)].%(ext)s';

  static const _kKuruHiddenShorts = {
    YTVisibleShortPlaces.history: false,
    YTVisibleShortPlaces.homeFeed: false,
    YTVisibleShortPlaces.relatedVideos: false,
    YTVisibleShortPlaces.search: false,
  };

  late final ytVisibleShorts = _keyMap<YTVisibleShortPlaces, bool>('ytVisibleShorts', isKuru ? _kKuruHiddenShorts : const {}, key: YTVisibleShortPlaces.values.asCodec());
  late final ytVisibleMixes = _keyMap<YTVisibleMixesPlaces, bool>('ytVisibleMixes', const {}, key: YTVisibleMixesPlaces.values.asCodec());

  late final ytHomePageItems = _keyEnumList(
    'ytHomePageItems',
    const [HomePageItems.mixes, HomePageItems.recentListens, HomePageItems.topRecentListens, HomePageItems.lostMemories],
    HomePageItems.values,
  );
  late final showChannelWatermarkFullscreen = _key('showChannelWatermarkFullscreen', true);
  late final showVideoEndcards = _key('showVideoEndcards', true);
  late final autoStartRadio = _key('autoStartRadio', false);
  late final personalizedRelatedVideos = _key('personalizedRelatedVideos', isKuru ? false : true);
  late final personalizedMixPlaylists = _key('personalizedMixPlaylists', isKuru ? false : true);
  late final preferMixRelatedVideos = _key('preferMixRelatedVideos', isKuru ? true : false);
  late final searchCleanup = _key('searchCleanup', true);
  late final showLikeStatusOnCards = _key('showLikeStatusOnCards', false);
  late final useNewNotificationExtractor = _key('useNewNotificationExtractor', false);
  late final preferLikeButtonOverFavourite = _key('preferLikeButtonOverFavourite', true);

  late final ytDownloadLocation = _key('ytDownloadLocation', AppDirs.YOUTUBE_DOWNLOADS_DEFAULT, sync: false);
  late final ytMiniplayerDimAfterSeconds = _key('ytMiniplayerDimAfterSeconds', isKuru ? 0 : 15);
  late final ytMiniplayerDimOpacity = _key('ytMiniplayerDimOpacity', isKuru ? 0.6 : 0.5);
  late final youtubeStyleMiniplayer = _key('youtubeStyleMiniplayer', true);
  late final preferNewComments = _key('preferNewComments', false);
  late final autoExtractVideoTagsFromInfo = _key('autoExtractVideoTagsFromInfo', true);
  late final fallbackExtractInfoDescription = _key('fallbackExtractInfoDescription', isKuru ? false : true);
  late final isAudioOnlyMode = _key('isAudioOnlyMode', false, sync: false);
  late final dataSaverMode = _keyEnum('dataSaverMode', isKuru ? DataSaverMode.medium : DataSaverMode.off, DataSaverMode.values, sync: false);
  late final dataSaverModeMobile = _keyEnum('dataSaverModeMobile', DataSaverMode.medium, DataSaverMode.values, sync: false);
  late final rememberAudioOnly = _key('rememberAudioOnly', isKuru ? true : false);
  late final topComments = _key('topComments', true);
  late final enableStreamSegments = _key('enableStreamSegments', true);
  late final splitDownloadsByChapters = _key('splitDownloadsByChapters', false);
  late final enableHeatMap = _key('enableHeatMap', true);
  late final onYoutubeLinkOpen = _keyEnum('onYoutubeLinkOpen', OnYoutubeLinkOpenAction.alwaysAsk, OnYoutubeLinkOpenAction.values);
  late final tapToSeek = _keyEnum('tapToSeek', YTSeekActionMode.expandedMiniplayer, YTSeekActionMode.values);
  late final dragToSeek = _keyEnum('dragToSeek', YTSeekActionMode.all, YTSeekActionMode.values);
  late final horizontalDrag = _keyEnum('horizontalDrag', YTHorizontalDragMode.fullscreen, YTHorizontalDragMode.values);
  late final downloadFilenameBuilder = _key('downloadFilenameBuilder', _defaultFilenameBuilder);
  late final downloadParallelCount = _key('downloadParallelCount_v2', 4, sync: false);
  late final downloadThreadsCount = _key('downloadThreadsCount', 3, sync: false);
  late final initialDefaultMetadataTags = _keyMap<String, String>('initialDefaultMetadataTags', const {});

  // -- currently used for windows
  late final downloadNotifications = _keyEnum('downloadNotifications', DownloadNotifications.showFailedOnly, DownloadNotifications.values);

  late final markVideoWatched = _key('markVideoWatched', true);
  late final linkLikeButtonWithFavourites = _key('linkLikeButtonWithFavourites', true);
  late final innertubeClient = _key<InnertubeClients?>('innertubeClient_v2', null, codec: InnertubeClients.values.asCodec());
  late final whiteVideoBGInLightMode = _key('whiteVideoBGInLightMode', isKuru ? true : false);
  late final enableDimInLightMode = _key('enableDimInLightMode', isKuru ? false : true);
  late final allowExperimentalCodecs = _key('allowExperimentalCodecs', false);
  late final preferOpusFormat = _key('preferOpusFormat', false);
  late final enableGifThumbnails = _key('enableGifThumbnails', false);
  late final maxPageCacheDurationMin = _key('maxPageCacheDurationMin_v2', kDefaultMinutesInMaxDaysForPageCache, sync: false);

  late final sponsorBlockSettings = _keyObject('sponsorBlockSettings', SponsorBlockSettings(), SponsorBlockSettings.fromJson, (v) => v.toJson());
  late final ryd = _keyObject('ryd', ReturnYoutubeDislikeSettings(), ReturnYoutubeDislikeSettings.fromJson, (v) => v.toJson());

  @override
  void _migrateLegacy() {
    _dropKey('innertubeClient');
    _dropKey('downloadParallelCount');
    _dropKey('maxPageCacheDurationMin');
  }

  @override
  void _onLoaded() {
    if (!rememberAudioOnly.value) isAudioOnlyMode._setValue(isAudioOnlyMode.fallback);
  }

  @override
  bool get syncable => true;

  @override
  String get filePath => AppPaths.SETTINGS_YOUTUBE;
}
