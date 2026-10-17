// ignore_for_file: avoid_rx_value_getter_outside_obx, constant_identifier_names
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/progress_percentage.dart';
import 'package:namida/class/search_matcher.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/taglib_res.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class JsonToHistoryParser {
  static JsonToHistoryParser get inst => _instance;
  static final JsonToHistoryParser _instance = JsonToHistoryParser._internal();
  JsonToHistoryParser._internal();

  final parsedHistoryJson = 0.obs;
  final totalJsonToParse = 0.obs;
  late final parsingProgress = ProgressPercentage(parsedHistoryJson, totalJsonToParse);
  final isParsing = false.obs;
  final _loadingFileProgress = (0, 0).obs;
  final _updatingYoutubeStatsDirectoryProgress = 0.obs;
  final _updatingYoutubeStatsDirectoryTotal = 0.obs;
  final Rx<TrackSource> currentParsingSource = TrackSource.local.obs;
  final _currentOldestDate = Rxn<DateTime>();
  final _currentNewestDate = Rxn<DateTime>();
  final _importStep = _HistoryImportStep.loadingFiles.obs;
  final _historyBackupFilename = ''.obs;
  final _importMatched = <_ImportTarget, int>{}.obs;
  final _importAdded = <_ImportTarget, int>{}.obs;
  List<_ImportTarget> _importTargets = const [];
  bool _includesHistoryBackupStep = false;
  Set<DataImportType> _currentTypes = const {};

  double get _percentageR {
    final p = parsedHistoryJson.valueR / totalJsonToParse.valueR;
    return p.isFinite ? p : 0;
  }

  static String getImportTitle(TrackSource source) {
    final sourceText = source.toText();
    return lang.importSourceData(source: sourceText);
  }

  bool _isShowingParsingMenu = false;

  void _hideParsingDialog() => _isShowingParsingMenu = false;

  void _closeParsingDialog() {
    if (!_isShowingParsingMenu) return;
    _hideParsingDialog();
    NamidaNavigator.inst.closeDialog();
  }

  void showParsingProgressDialog() {
    if (_isShowingParsingMenu) return;
    _isShowingParsingMenu = true;

    final oldestDate = _currentOldestDate.value;
    final newestDate = _currentNewestDate.value;
    final dateRangeText = oldestDate != null && newestDate != null ? "${oldestDate.dateFormattedOriginal} → ${newestDate.dateFormattedOriginal}" : null;
    final types = _currentTypes;
    final typesText = types.map((e) => e.toText()).join(', ');
    final isYTHistory = currentParsingSource.value == TrackSource.youtube && types.contains(DataImportType.history);

    NamidaNavigator.inst.navigateDialog(
      onDismissing: _hideParsingDialog,
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: getImportTitle(currentParsingSource.value),
        trailingWidgets: const [
          _ImportDoneCheckMark(),
        ],
        actions: [
          NamidaTextButton(
            text: lang.confirm,
            onTap: _closeParsingDialog,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                [
                      const SizedBox(height: 8.0),
                      _ImportStepTile(
                        step: _HistoryImportStep.loadingFiles,
                        title: lang.loadingFile,
                        trailing: const _LoadingFilesProgressText(),
                      ),
                      if (_includesHistoryBackupStep)
                        _ImportStepTile(
                          step: _HistoryImportStep.backup,
                          title: '${lang.createBackup} ($typesText)',
                          details: const _HistoryBackupFilenameText(),
                        ),
                      _ImportStepTile(
                        step: _HistoryImportStep.parsing,
                        title: lang.extractingInfo,
                        trailing: const _ParsingPercentageText(),
                        details: _ParsingProgressDetails(
                          dateRangeText: dateRangeText,
                          targets: _importTargets,
                        ),
                      ),
                      if (isYTHistory)
                        _ImportStepTile(
                          step: _HistoryImportStep.updatingStats,
                          title: lang.stats,
                          trailing: const _StatsProgressText(),
                        ),
                      if (types.contains(DataImportType.playlists))
                        _ImportStepTile(
                          step: _HistoryImportStep.playlists,
                          title: lang.playlists,
                        ),
                      if (types.contains(DataImportType.subscriptions))
                        _ImportStepTile(
                          step: _HistoryImportStep.subscriptions,
                          title: lang.subscriptions,
                        ),
                      _ImportStepTile(
                        step: _HistoryImportStep.saving,
                        title: lang.saving,
                      ),
                    ]
                    .addSeparators(
                      separator: const SizedBox(
                        height: 18.0,
                      ),
                    )
                    .toFixedList(),
          ),
        ),
      ),
    );
  }

  bool get shouldShowMissingEntriesDialog => _latestMissingMap.valueR.isNotEmpty && _latestMissingMap.length != _latestMissingMapAddedStatus.length;
  final _latestMissingMap = <_MissingListenEntry, List<int>>{}.obs;
  final _latestMissingMapAddedStatus = <_MissingListenEntry, Track>{}.obs;

  void showMissingEntriesDialog() {
    if (_latestMissingMap.value.isEmpty) return;

    Future<void> addChosenTrack(MapEntry<_MissingListenEntry, List<int>> entry, Track choosen) async {
      final missing = entry.key;
      final twds = entry.value.map(
        (e) => TrackWithDate(
          dateAdded: e,
          track: choosen,
          source: missing.source,
        ),
      );
      if (missing.isFavourite) {
        await PlaylistController.inst.importTracksToPlaylist(PlaylistController.inst.favouritesPlaylist.value, twds);
      } else {
        await HistoryController.inst.addTracksToHistory(twds.toList());
      }
      _latestMissingMapAddedStatus[missing] = choosen;
    }

    List<int> addTrackToHistoryOnly(MapEntry<_MissingListenEntry, List<int>> entry, Track choosen) {
      final twds = entry.value.map(
        (e) => TrackWithDate(
          dateAdded: e,
          track: choosen,
          source: entry.key.source,
        ),
      );
      final days = HistoryController.inst.addTracksToHistoryOnly(twds.toList(), preventDuplicate: true);
      _latestMissingMapAddedStatus[entry.key] = choosen;
      return days;
    }

    void pickTrack(MapEntry<_MissingListenEntry, List<int>> entry) {
      showLibraryTracksChooseDialog(
        trackName: "${entry.key.artistOrChannel} - ${entry.key.title}",
        onChoose: (choosenTrack) async {
          await addChosenTrack(entry, choosenTrack);
          NamidaNavigator.inst.closeDialog();
        },
      );
    }

    Track getDummyTrack(_MissingListenEntry missingListen) {
      return Track.explicit('namida_dummy/${missingListen.source.name}/${missingListen.artistOrChannel} - ${missingListen.title}');
    }

    void confirmAddAsDummy({required String confirmMessage, required Future<void> Function() onConfirm}) {
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          normalTitleStyle: true,
          isWarning: true,
          title: lang.confirm,
          bodyText: confirmMessage,
          actions: [
            const CancelButton(),
            NamidaButton(
              onTap: () async {
                await onConfirm();
                NamidaNavigator.inst.closeDialog();
              },
              text: lang.confirm,
            ),
          ],
        ),
      );
    }

    final showAddAsDummyIcon = false.obs;

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        showAddAsDummyIcon.close();
      },
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.missingEntries,
        trailingWidgets: [
          const SizedBox(width: 4.0),
          Obx(
            (context) => NamidaIconButton(
              horizontalPadding: 4.0,
              icon: Broken.command_square,
              iconSize: 24.0,
              onPressed: () async {
                final listensCount = _latestMissingMap.value.keys.where((e) => !e.isFavourite).length;
                confirmAddAsDummy(
                  confirmMessage: 'Add $listensCount as dummy tracks?',
                  onConfirm: () async {
                    final historyDays = <int>[];
                    for (var e in _latestMissingMap.value.entries) {
                      if (e.key.isFavourite) continue;
                      final replacedWithTrack = _latestMissingMapAddedStatus[e.key];
                      if (replacedWithTrack == null) {
                        historyDays.addAll(addTrackToHistoryOnly(e, getDummyTrack(e.key)));
                      }
                    }

                    HistoryController.inst.removeDuplicatedItems(historyDays);
                    HistoryController.inst.sortHistoryTracks(historyDays);
                    await HistoryController.inst.saveHistoryToStorage(historyDays);
                    HistoryController.inst.updateMostPlayedPlaylist();

                    NamidaNavigator.inst.closeDialog();
                  },
                );
              },
            ).animateEntrance(showWhen: showAddAsDummyIcon.valueR),
          ),
          NamidaIconButton(
            horizontalPadding: 4.0,
            icon: Broken.eye,
            onPressed: () {
              showAddAsDummyIcon.toggle();
            },
          ),
          const SizedBox(width: 4.0),
        ],
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  lang.historyImportMissingEntriesNote,
                  style: namida.textTheme.displaySmall,
                ),
              ),
              Expanded(
                child: Obx(
                  (context) {
                    final missing = _latestMissingMap.valueR.entries.toFixedList();
                    return NamidaScrollbarWithController(
                      child: (sc) => SuperSmoothListView.separated(
                        controller: sc,
                        separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                        itemCount: missing.length,
                        itemBuilder: (context, index) {
                          final entry = missing[index];
                          final isFavourite = entry.key.isFavourite;
                          return Obx(
                            (context) {
                              final replacedWithTrack = _latestMissingMapAddedStatus[entry.key];
                              return IgnorePointer(
                                ignoring: replacedWithTrack != null,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: replacedWithTrack != null ? 0.6 : 1.0,
                                  child: NamidaInkWell(
                                    onTap: () => pickTrack(entry),
                                    bgColor: namida.theme.cardTheme.color,
                                    borderRadius: 12.0,
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        NamidaInkWell(
                                          bgColor: namida.theme.cardTheme.color,
                                          borderRadius: 42.0,
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                          child: isFavourite
                                              ? const Icon(
                                                  Broken.heart,
                                                  size: 14.0,
                                                )
                                              : Text(
                                                  entry.value.length.formatDecimal(),
                                                  style: namida.textTheme.displaySmall,
                                                ),
                                        ),
                                        const SizedBox(width: 12.0),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                entry.key.title,
                                                style: namida.textTheme.displayMedium,
                                              ),
                                              Text(
                                                "${entry.key.artistOrChannel} - ${entry.key.source.name}",
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.ellipsis,
                                                style: namida.textTheme.displaySmall,
                                              ),
                                              if (replacedWithTrack != null)
                                                Text(
                                                  "→ ${replacedWithTrack.originalArtist} - ${replacedWithTrack.title}",
                                                  maxLines: 2,
                                                  softWrap: false,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: namida.textTheme.displaySmall?.copyWith(fontSize: 11.5),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4.0),
                                        NamidaIconButton(
                                          horizontalPadding: 4.0,
                                          icon: Broken.repeat_circle,
                                          iconSize: 24.0,
                                          onPressed: () => pickTrack(entry),
                                        ),
                                        if (!isFavourite)
                                          Obx(
                                            (context) => NamidaIconButton(
                                              horizontalPadding: 2.0,
                                              icon: Broken.command,
                                              iconSize: 20.0,
                                              onPressed: () => confirmAddAsDummy(
                                                confirmMessage: 'Add "${entry.key.artistOrChannel} - ${entry.key.title}" as dummy track?',
                                                onConfirm: () async => await addChosenTrack(entry, getDummyTrack(entry.key)),
                                              ),
                                            ).animateEntrance(showWhen: showAddAsDummyIcon.valueR),
                                          ),
                                        const SizedBox(width: 2.0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetValues() {
    isParsing.value = false;
    _loadingFileProgress.value = (0, 0);

    totalJsonToParse.value = 0;
    parsedHistoryJson.value = 0;
    _updatingYoutubeStatsDirectoryProgress.value = 0;
    _updatingYoutubeStatsDirectoryTotal.value = 0;
    _currentOldestDate.value = null;
    _currentNewestDate.value = null;
    _importStep.value = _HistoryImportStep.loadingFiles;
    _historyBackupFilename.value = '';
    _importMatched.value = {};
    _importAdded.value = {};
  }

  Timer? _notificationTimer;

  Future<void> importSourceFiles({
    required List<File> files,
    Directory? mainDirectory,
    required TrackSource source,
    required Set<DataImportType> types,
    bool matchAll = false,
    bool ytIsMatchingTypeLink = true,
    bool isMatchingTypeTitleAndArtist = false,
    bool ytMatchYT = true,
    bool ytMatchYTMusic = true,
    DateTime? oldestDate,
    DateTime? newestDate,
    required bool backupFirst,
  }) async {
    final isYT = source == TrackSource.youtube || source == TrackSource.youtubeMusic;
    final importHistory = types.contains(DataImportType.history);
    final importFavourites = types.contains(DataImportType.favourites);
    final importPlaylists = types.contains(DataImportType.playlists);
    final importSubscriptions = types.contains(DataImportType.subscriptions);

    _resetValues();
    isParsing.value = true;
    _currentOldestDate.value = oldestDate;
    _currentNewestDate.value = newestDate;
    currentParsingSource.value = isYT ? TrackSource.youtube : source;
    _currentTypes = types;
    _importTargets = [
      if (importHistory) ...[
        _ImportTarget.history,
        if (isYT) _ImportTarget.historyYT,
      ],
      if (importFavourites) ...[
        _ImportTarget.favourites,
        if (isYT) _ImportTarget.favouritesYT,
      ],
      if (importPlaylists) _ImportTarget.playlists,
      if (importSubscriptions) _ImportTarget.subscriptions,
    ];
    final importTitle = getImportTitle(currentParsingSource.value);
    _includesHistoryBackupStep = backupFirst;
    showParsingProgressDialog();

    Directory? tempZipMainDestination;

    try {
      final contents = mainDirectory != null && files.isEmpty ? await mainDirectory.listAllIsolate(recursive: true, followLinks: false) : files;
      final sourceFiles = await _filterFilesFromPossibleZips(
        contents,
        source,
        () async => tempZipMainDestination ??= await Directory.systemTemp.createTemp('namida_parser_'),
        (progress, total) => _loadingFileProgress.value = (progress, total),
      );

      final playlistsDirectories = sourceFiles.playlistsDirectories;
      final hasHistoryFiles = importHistory && sourceFiles.history.isNotEmpty;
      final hasFavouritesFiles = importFavourites && (sourceFiles.favourites.isNotEmpty || playlistsDirectories.isNotEmpty);
      final hasPlaylistsFiles = importPlaylists && playlistsDirectories.isNotEmpty;
      final subscriptionsFile = importSubscriptions ? sourceFiles.subscriptions.firstOrNull : null;
      if (!hasHistoryFiles && !hasFavouritesFiles && !hasPlaylistsFiles && subscriptionsFile == null) {
        snackyy(message: 'No related files were found in this directory.', isError: true);
        _closeParsingDialog();
        _resetValues();
        return;
      }

      if (backupFirst) {
        _importStep.value = _HistoryImportStep.backup;
        final backupItems = <AppPathsBackupEnum>{
          if (importHistory) ...[
            ...AppPathsBackupEnumCategories.history,
            if (isYT) ...[
              ...AppPathsBackupEnumCategories.history_yt,
              AppPathsBackupEnum.YT_STATS,
            ],
          ],
          if (importFavourites) ...[
            AppPathsBackupEnum.FAVOURITES_PLAYLIST,
            if (isYT) AppPathsBackupEnum.YT_LIKES_PLAYLIST,
          ],
          if (importPlaylists) ...AppPathsBackupEnumCategories.playlists_yt,
          if (importSubscriptions) AppPathsBackupEnum.YT_SUBSCRIPTIONS,
        };
        final backupFile = await BackupController.inst.createBackupFile(
          backupItems.map((e) => e.resolve()).toList(),
          filenamePrefix: 'Namida History Backup',
        );
        if (backupFile == null) {
          _closeParsingDialog();
          _resetValues();
          return;
        }
        _historyBackupFilename.value = backupFile.path.getFilename;
      }

      _importStep.value = _HistoryImportStep.parsing;

      await Future.delayed(Duration.zero);

      NotificationManager.instance.ensurePermissionGranted();
      final startTime = DateTime.now();
      _notificationTimer?.cancel();
      _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        NotificationManager.instance.importHistoryNotification(importTitle, parsedHistoryJson.value, totalJsonToParse.value, startTime);
      });

      final datesAdded = <int>[];
      final datesAddedYoutube = <int>[];
      int addedHistoryCount = 0;
      int addedYTHistoryCount = 0;
      final favourites = <TrackWithDate>[];
      var ytLikedVideos = const <_TakeoutLikedVideo>[];
      YoutubePlaylistImportDetails? ytPlaylists;
      var allMissingEntriesSorted = <_MissingListenEntry, List<int>>{};

      Future<void> addGeneralSource(Future<_GeneralSourceResult?> Function(_GeneralSourceParserParams params) parser) async {
        final needsListensForLoves = importFavourites && source == TrackSource.listenbrainz;
        final shouldReadListens = importHistory || needsListensForLoves;
        final historyFiles = shouldReadListens ? sourceFiles.history : const <File>[];
        final favouriteFiles = importFavourites ? sourceFiles.favourites : const <File>[];
        if (historyFiles.isEmpty && favouriteFiles.isEmpty) return;

        final res = await _addGeneralSource(
          files: historyFiles,
          favouriteFiles: favouriteFiles,
          addHistory: importHistory,
          matchAll: matchAll,
          oldestDate: oldestDate,
          newestDate: newestDate,
          parser: parser,
        );
        if (res == null) return;
        allMissingEntriesSorted = res.missingEntriesSorted;
        datesAdded.addAll(res.historyDays);
        addedHistoryCount += res.addedHistoryCount;
        favourites.addAll(res.favourites);
      }

      switch (source) {
        case TrackSource.youtube || TrackSource.youtubeMusic:
          YoutubePlaylistImportDetails? takeoutPlaylists;
          if ((importFavourites || importPlaylists) && playlistsDirectories.isNotEmpty) {
            takeoutPlaylists = await YoutubeImportController.scanPlaylistsDirectories(playlistsDirectories);
          }
          if (importPlaylists) ytPlaylists = takeoutPlaylists;
          if (importFavourites && takeoutPlaylists != null) {
            ytLikedVideos = _takeoutLikedVideosInRange(takeoutPlaylists.likedVideos, oldestDate, newestDate);
            _addMatched(_ImportTarget.favouritesYT, ytLikedVideos.length);
          }

          final historyFiles = importHistory ? sourceFiles.history : const <File>[];
          if (historyFiles.isEmpty && ytLikedVideos.isEmpty) break;

          final res = await _parseYTHistoryJsonAndAdd(
            files: historyFiles,
            likedVideos: ytLikedVideos,
            isMatchingTypeLink: ytIsMatchingTypeLink,
            isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist,
            matchYT: ytMatchYT,
            matchYTMusic: ytMatchYTMusic,
            oldestDate: oldestDate,
            newestDate: newestDate,
            matchAll: matchAll,
          );
          if (res != null) {
            allMissingEntriesSorted = res.missingEntriesSorted;
            datesAdded.addAll(res.historyDays);
            datesAddedYoutube.addAll(res.ytHistoryDays);
            addedHistoryCount += res.addedHistoryCount;
            addedYTHistoryCount += res.addedYTHistoryCount;
            favourites.addAll(res.favourites);
            if (res.hasUnreadableHtml) snackyy(title: lang.error, message: lang.historyImportHtmlUnreadable, isError: true);
          }

        case TrackSource.lastfm:
          await addGeneralSource(_addLastFmSourceIsolate);

        case TrackSource.spotify:
          await addGeneralSource(_addSpotifySourceIsolate);

        case TrackSource.listenbrainz:
          await addGeneralSource(_addListenBrainzSourceIsolate);

        case TrackSource.local:
          break;
      }

      int newPlaylistsCount = 0;
      if (ytPlaylists != null) {
        _importStep.value = _HistoryImportStep.playlists;
        _addMatched(_ImportTarget.playlists, ytPlaylists.countAfterMerging);
        newPlaylistsCount = await YoutubeImportController.inst.addPlaylists(ytPlaylists, PlaylistAddDuplicateAction.mergeAndSortByAddedDate);
      }

      if (subscriptionsFile != null) {
        _importStep.value = _HistoryImportStep.subscriptions;
        final subscriptionsCount = await YoutubeImportController.inst.importSubscriptions(subscriptionsFile.path);
        _addMatched(_ImportTarget.subscriptions, subscriptionsCount);
      }

      _importStep.value = _HistoryImportStep.saving;

      // -- local history --
      if (datesAdded.isNotEmpty) {
        addedHistoryCount -= HistoryController.inst.removeDuplicatedItems(datesAdded);
        HistoryController.inst.sortHistoryTracks(datesAdded);
        await HistoryController.inst.saveHistoryToStorage(datesAdded);
        HistoryController.inst.updateMostPlayedPlaylist();
      }

      // -- youtube history --
      if (datesAddedYoutube.isNotEmpty) {
        addedYTHistoryCount -= YoutubeHistoryController.inst.removeDuplicatedItems(datesAddedYoutube);
        YoutubeHistoryController.inst.sortHistoryTracks(datesAddedYoutube);
        await YoutubeHistoryController.inst.saveHistoryToStorage(datesAddedYoutube);
        YoutubeHistoryController.inst.updateMostPlayedPlaylist();
      }

      // -- favourites --
      int addedFavouritesCount = 0;
      if (favourites.isNotEmpty) {
        addedFavouritesCount = await PlaylistController.inst.importTracksToPlaylist(PlaylistController.inst.favouritesPlaylist.value, favourites);
      }
      int addedYTFavouritesCount = 0;
      if (ytLikedVideos.isNotEmpty) {
        final ytFavouritesPlaylist = YoutubePlaylistController.inst.favouritesPlaylist.value;
        final ytFavourites = ytLikedVideos.map(
          (e) => YoutubeID(
            id: e.id,
            watchNull: YTWatch(dateMSNull: e.dateMS, isYTMusic: false),
            playlistID: ytFavouritesPlaylist.playlistID,
          ),
        );
        addedYTFavouritesCount = await YoutubePlaylistController.inst.importTracksToPlaylist(ytFavouritesPlaylist, ytFavourites);
      }

      _importAdded.value = {
        _ImportTarget.history: addedHistoryCount,
        _ImportTarget.historyYT: addedYTHistoryCount,
        _ImportTarget.favourites: addedFavouritesCount,
        _ImportTarget.favouritesYT: addedYTFavouritesCount,
        _ImportTarget.playlists: newPlaylistsCount,
      };

      isParsing.value = false;
      HomePageRefresher.requestRefresh();

      _notificationTimer?.cancel();
      final resultsText = _importTargets.map(_getImportResultText).join(' | ');
      NotificationManager.instance.doneImportingHistoryNotification(importTitle, resultsText);

      _latestMissingMap.value = allMissingEntriesSorted;
      _latestMissingMapAddedStatus.clear();
      showMissingEntriesDialog();
    } catch (e, st) {
      printo(e, isError: true);
      _notificationTimer?.cancel();
      NotificationManager.instance.failedImportingHistoryNotification(importTitle, e.toString());
      _closeParsingDialog();
      _resetValues();
      snackyy(title: lang.error, message: e.toString(), isError: true);
      logger.error('Error importing history (${source.name})', e: e, st: st);
    } finally {
      tempZipMainDestination?.delete(recursive: true);
    }
  }

  @visibleForTesting
  // ignore: library_private_types_in_public_api
  static Future<_SourceFiles> debugFilterFiles(List<FileSystemEntity> contents, TrackSource source) {
    return inst._filterFilesFromPossibleZips(contents, source, () => Directory.systemTemp.createTemp('namida_parser_'), (progress, total) {});
  }

  Future<_SourceFiles> _filterFilesFromPossibleZips(
    List<FileSystemEntity> contents,
    TrackSource source,
    Future<Directory> Function() tempZipMainDestination,
    void Function(int progress, int total) onProgress,
  ) async {
    final files = <File>[];
    final favouriteFiles = <File>[];
    final playlistsDirectories = <String>{};
    final subscriptionsFiles = <File>[];
    final sourceFiles = (history: files, favourites: favouriteFiles, playlistsDirectories: playlistsDirectories, subscriptions: subscriptionsFiles);

    late final zipManager = ZipManager.platform();

    Stream<FileSystemEntity> listDir(Directory dir) => dir.list(recursive: true, followLinks: false);
    FutureOr<void> executeFileEnsureZipExtracted(File file, void Function(File file) onMatch) async {
      if (NamidaFileExtensionsWrapper.zip.isPathValid(file.path)) {
        final tempDir = (await tempZipMainDestination()).path;
        final destinationDir = Directory(FileParts.joinPath(tempDir, file.path.getFilenameWOExt));
        try {
          await zipManager.extractZip(zipFile: file, destinationDir: destinationDir);
          final zipContents = listDir(destinationDir);
          await for (final file in zipContents) {
            if (file is File) {
              onMatch(file);
            }
          }
        } catch (_) {
          // on windows: most likely RangeError in package:archive.InputMemoryStream.readByte
        }
      } else {
        onMatch(file);
      }
    }

    int progress = 0;
    final int total = contents.length;
    if (total == 0) return sourceFiles;

    switch (source) {
      case TrackSource.youtube || TrackSource.youtubeMusic:
        final htmlFiles = <File>[];
        for (final file in contents) {
          progress++;
          onProgress(progress, total);
          if (file is File) {
            await executeFileEnsureZipExtracted(
              file,
              (file) {
                if (NamidaFileExtensionsWrapper.csv.isPathValid(file.path)) {
                  if (file.path.getFilename == 'subscriptions.csv') {
                    subscriptionsFiles.add(file);
                    return;
                  }
                  final dirPath = file.path.getDirectoryPath;
                  if (YoutubeImportController.isTakeoutPlaylistsDirectory(dirPath)) playlistsDirectories.add(dirPath);
                  return;
                }
                if (!file.path.getFilename.contains('watch-history')) return;
                if (NamidaFileExtensionsWrapper.json.isPathValid(file.path)) {
                  files.add(file);
                } else if (NamidaFileExtensionsWrapper.html.isPathValid(file.path)) {
                  htmlFiles.add(file);
                }
              },
            );
          }
        }
        // -- json first (date more precise and just easier)
        files.addAll(htmlFiles);

      case TrackSource.lastfm:
        for (final file in contents) {
          progress++;
          onProgress(progress, total);
          if (file is File) {
            await executeFileEnsureZipExtracted(
              file,
              (file) {
                if (NamidaFileExtensionsWrapper.csv.isPathValid(file.path)) {
                  // folder shouldnt contain yt playlists/etc csv files tho, otherwise wer cooked
                  final name = file.path.getFilename;
                  if (name != 'subscriptions.csv') files.add(file);
                }
              },
            );
          }
        }
      case TrackSource.spotify:
        for (final file in contents) {
          progress++;
          onProgress(progress, total);
          if (file is File) {
            await executeFileEnsureZipExtracted(
              file,
              (file) {
                if (NamidaFileExtensionsWrapper.json.isPathValid(file.path)) {
                  final name = file.path.getFilename;
                  if (name == 'YourLibrary.json') {
                    favouriteFiles.add(file);
                    return;
                  }
                  final nameLC = name.toLowerCase();
                  if (nameLC.contains('podcast')) return;
                  if (nameLC.contains('streaming') || nameLC.contains('history') || name.startsWith('endsong')) {
                    files.add(file);
                  }
                }
              },
            );
          }
        }
      case TrackSource.listenbrainz:
        for (final file in contents) {
          progress++;
          onProgress(progress, total);
          if (file is File) {
            await executeFileEnsureZipExtracted(
              file,
              (file) {
                if (NamidaFileExtensionsWrapper.jsonl.isPathValid(file.path)) {
                  final name = file.path.getFilename;
                  if (name == 'feedback.jsonl') {
                    favouriteFiles.add(file);
                  } else if (name != 'pinned_recording.jsonl') {
                    files.add(file);
                  }
                }
              },
            );
          }
        }
      case TrackSource.local:
        null;
    }

    return sourceFiles;
  }

  static List<_TakeoutLikedVideo> _takeoutLikedVideosInRange(List<({String id, int? dateAddedMS})> videos, DateTime? oldestDate, DateTime? newestDate) {
    final oldestDay = oldestDate?.toDaysSince1970();
    final newestDay = newestDate?.toDaysSince1970();
    final importTimeMS = currentTimeMS;
    final liked = <_TakeoutLikedVideo>[];
    for (final video in videos) {
      final dateMS = video.dateAddedMS ?? importTimeMS;
      if (_isInDaysRange(dateMS, oldestDay, newestDay)) liked.add((id: video.id, dateMS: dateMS));
    }
    return liked;
  }

  void _addMatched(_ImportTarget target, int count) {
    final matched = _importMatched.value;
    matched[target] = (matched[target] ?? 0) + count;
    _importMatched.refresh();
  }

  void _onMatchedProgress(Object? message) {
    final (target, count) = message as (_ImportTarget, int);
    _addMatched(target, count);
  }

  String _getImportResultText(_ImportTarget target) {
    final matched = _importMatched.value[target] ?? 0;
    final added = _importAdded.value[target];
    return _importResultToText(target, matched, added);
  }

  static String _importResultToText(_ImportTarget target, int matched, int? added) {
    final targetText = target.toText();
    final matchedText = matched.formatDecimalShort();
    if (added == null || added <= 0) return '$targetText • $matchedText';
    final addedText = added.formatDecimalShort();
    return '$targetText • $matchedText (+$addedText)';
  }

  static bool _isInDaysRange(int dateMS, int? oldestDay, int? newestDay) {
    if (oldestDay == null || newestDay == null) return true;
    final day = dateMS.toDaysSince1970();
    return day >= oldestDay && day <= newestDay;
  }

  Future<
    ({
      List<int> historyDays,
      List<int> ytHistoryDays,
      int addedHistoryCount,
      int addedYTHistoryCount,
      Map<_MissingListenEntry, List<int>> missingEntriesSorted,
      bool hasUnreadableHtml,
      List<TrackWithDate> favourites,
    })?
  >
  _parseYTHistoryJsonAndAdd({
    required List<File> files,
    required List<_TakeoutLikedVideo> likedVideos,
    required bool isMatchingTypeLink,
    required bool isMatchingTypeTitleAndArtist,
    required bool matchYT,
    required bool matchYTMusic,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required bool matchAll,
  }) async {
    final portProgressParsed = RawReceivePort((message) {
      parsedHistoryJson.value += message as int;
    });
    final portProgressMatched = RawReceivePort(_onMatchedProgress);
    final portLoadingProgress = ReceivePort();

    final addHistory = files.isNotEmpty;
    final localHistory = addHistory ? HistoryController.inst.historyMap.value : SplayTreeMap<int, List<TrackWithDate>>();
    final ytHistory = addHistory ? YoutubeHistoryController.inst.historyMap.value : SplayTreeMap<int, List<YoutubeID>>();

    final _YTTakeoutParserParams params = (
      tracks: Indexer.inst.allTracksMappedByPath.values
          .map(
            (e) => (
              title: e.title,
              album: e.originalAlbum,
              artist: e.originalArtist,
              path: e.path,
              comment: e.comment,
              isVideo: e.isVideo,
            ),
          )
          .toFixedList(),
      files: files,
      likedVideos: likedVideos,
      isMatchingTypeLink: isMatchingTypeLink,
      isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist,
      matchYT: matchYT,
      matchYTMusic: matchYTMusic,
      oldestDay: oldestDate?.toDaysSince1970(),
      newestDay: newestDate?.toDaysSince1970(),
      matchAll: matchAll,
      artistsSplitConfig: ArtistsSplitConfig.settings(),
      portProgressParsed: portProgressParsed.sendPort,
      portProgressMatched: portProgressMatched.sendPort,
      portLoadingProgress: portLoadingProgress.sendPort,
      localHistory: localHistory,
      ytHistory: ytHistory,
    );

    StreamSubscription? portLoadingProgressSub;
    portLoadingProgressSub = portLoadingProgress.listen((message) {
      message as int;
      final shouldClosePort = !message.isNegative;
      message = message.abs();
      totalJsonToParse.value = message;
      _loadingFileProgress.value = (_loadingFileProgress.value.$2, _loadingFileProgress.value.$2);
      if (shouldClosePort) {
        portLoadingProgress.close();
        portLoadingProgressSub?.cancel();
      }
    });
    if (addHistory) {
      HistoryController.inst.setIdleStatus(true);
      YoutubeHistoryController.inst.setIdleStatus(true);
    }

    try {
      final res = await _parseYTHistoryJsonAndAddIsolate.thready(params);
      if (res == null) return null;

      final mapOfAffectedIds = res.affectedIds;

      if (mapOfAffectedIds != null && mapOfAffectedIds.isNotEmpty) {
        _importStep.value = _HistoryImportStep.updatingStats;
        _updatingYoutubeStatsDirectoryTotal.value = mapOfAffectedIds.length;
        await _updateYoutubeStatsDirectory(
          affectedIds: mapOfAffectedIds,
          onProgress: (updatedIdsCount) {
            _updatingYoutubeStatsDirectoryProgress.value += updatedIdsCount;
            printy('updatedIds: $updatedIdsCount');
          },
        );
        YoutubeInfoController.utils.fillBackupInfoMap();
      }

      if (addHistory) {
        HistoryController.inst.historyMap.value = res.localHistory;
        YoutubeHistoryController.inst.historyMap.value = res.ytHistory;
      }
      if (res.addedLocalHistoryCount > 0) {
        HistoryController.inst.totalHistoryItemsCount.value += res.addedLocalHistoryCount;
        HistoryController.inst.totalHistoryItemsCount.refresh();
      }
      if (res.addedYTHistoryCount > 0) {
        YoutubeHistoryController.inst.totalHistoryItemsCount.value += res.addedYTHistoryCount;
        YoutubeHistoryController.inst.totalHistoryItemsCount.refresh();
      }

      return (
        historyDays: res.daysToSaveLocal,
        ytHistoryDays: res.daysToSaveYT,
        addedHistoryCount: res.addedLocalHistoryCount,
        addedYTHistoryCount: res.addedYTHistoryCount,
        missingEntriesSorted: res.missingEntriesSorted,
        hasUnreadableHtml: res.hasUnreadableHtml,
        favourites: res.favourites,
      );
    } finally {
      portProgressParsed.close();
      portProgressMatched.close();
      portLoadingProgress.close();
      if (addHistory) {
        await Future.wait([
          HistoryController.inst.setIdleStatus(false),
          YoutubeHistoryController.inst.setIdleStatus(false),
        ]);
      }
    }
  }

  Future<(int, int)> copyYTHistoryContentToLocalHistory({required bool matchAll}) async {
    final allTracks = Indexer.inst.allTracksMappedByPath.values;
    final allInsideYTHistory = YoutubeHistoryController.inst.historyTracks;
    final tracksIdsMap = <String, List<Track>>{};

    for (final trExt in allTracks) {
      final videoId = trExt.youtubeID;
      if (videoId.isNotEmpty) {
        tracksIdsMap.addForce(videoId, trExt.asTrack());
      }
    }
    int totalCount = 0;
    int removedDuplicates = 0;
    final historyMap = HistoryController.inst.historyMap.value;
    final datesAdded = <int>[];
    for (final vh in allInsideYTHistory) {
      final match = tracksIdsMap[vh.id];
      if (match != null && match.isNotEmpty) {
        final tracks = matchAll ? match : [match.first];
        final tracksWithDates = tracks
            .map(
              (e) => TrackWithDate(
                dateAdded: vh.dateAddedMS,
                track: e,
                source: vh.watch.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
              ),
            )
            .toList();
        final day = vh.dateAddedMS.toDaysSince1970();
        final dayLengthBefore = historyMap[day]?.length ?? 0;
        totalCount += tracksWithDates.length;
        final days = HistoryController.inst.addTracksToHistoryOnly(tracksWithDates, preventDuplicate: true);
        final dayLengthAfter = historyMap[day]?.length ?? 0;
        final actuallyAddedCount = (dayLengthAfter - dayLengthBefore);
        removedDuplicates += tracks.length - actuallyAddedCount;
        datesAdded.addAll(days);
      }
    }
    if (datesAdded.isNotEmpty) {
      removedDuplicates += HistoryController.inst.removeDuplicatedItems(datesAdded);
      HistoryController.inst.sortHistoryTracks(datesAdded);
      await HistoryController.inst.saveHistoryToStorage(datesAdded);
      HistoryController.inst.updateMostPlayedPlaylist();
      return (totalCount, totalCount - removedDuplicates);
    }
    return (totalCount, 0);
  }

  @visibleForTesting
  // ignore: library_private_types_in_public_api
  static Future<_YTTakeoutParserResult?> debugParseYTHistory(_YTTakeoutParserParams params) => _parseYTHistoryJsonAndAddIsolate(params);

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_YTTakeoutParserResult?> _parseYTHistoryJsonAndAddIsolate(_YTTakeoutParserParams params) async {
    final allTracks = params.tracks;
    final files = params.files;
    final likedVideos = params.likedVideos;
    final isMatchingTypeLink = params.isMatchingTypeLink;
    final isMatchingTypeTitleAndArtist = params.isMatchingTypeTitleAndArtist;
    final matchYT = params.matchYT;
    final matchYTMusic = params.matchYTMusic;
    final oldestDay = params.oldestDay;
    final newestDay = params.newestDay;
    final matchAll = params.matchAll;
    final artistsSplitConfig = params.artistsSplitConfig;

    final localHistory = params.localHistory;
    final ytHistory = params.ytHistory;

    int addedLocalHistoryCount = 0;
    int addedYTHistoryCount = 0;

    final portProgressParsed = params.portProgressParsed;
    final portProgressMatched = params.portProgressMatched;
    final portLoadingProgress = params.portLoadingProgress;

    // -- likes hold only video ids, so they always match by link
    final tracksIdsMap = isMatchingTypeLink || likedVideos.isNotEmpty ? _mapTracksByYoutubeID(allTracks) : null;
    final historyTracksIdsMap = isMatchingTypeLink ? tracksIdsMap : null;

    final reverseTitleMatcher = ReverseSearchMatcher<_YTHistoryMatchEntry>();
    if (isMatchingTypeTitleAndArtist) {
      for (var trMap in allTracks) {
        final title = trMap.title;
        final originalArtist = trMap.artist;
        final artistsList = Indexer.splitArtist(
          title: title,
          originalArtist: originalArtist,
          config: artistsSplitConfig,
        );
        final firstArtist = artistsList.firstWhereEff((e) => e != UnknownTags.ARTIST);
        final artistTokens = firstArtist == null ? const <String>{} : SearchMatcher.tokenize(firstArtist);
        final album = trMap.album;
        final albumTokens = album == UnknownTags.ALBUM ? const <String>{} : SearchMatcher.tokenize(album);
        final canMatchByTitleOnly = artistTokens.isEmpty && albumTokens.isEmpty;
        reverseTitleMatcher.addItem((track: trMap, artistTokens: artistTokens, albumTokens: albumTokens, canMatchByTitleOnly: canMatchByTitleOnly), title);
      }
    }

    int jsonResponseTotal = 0;
    for (final file in files) {
      if (_isHtmlFile(file)) {
        jsonResponseTotal += await _YTTakeoutHtmlParser.countEntries(file);
      } else {
        jsonResponseTotal += await JsonToHistoryParser._countJsonObjectsInList(file);
      }
    }
    jsonResponseTotal += likedVideos.length;
    portLoadingProgress.send(jsonResponseTotal); // 1

    final mapOfAffectedIds = <String, YoutubeVideoHistory>{};
    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    int historyMatched = 0;
    int ytHistoryMatched = 0;
    int favouritesMatched = 0;
    final daysToSaveLocal = <int>[];
    final daysToSaveYT = <int>[];
    const chunkSize = 20;

    void sendProgress() {
      portProgressParsed.send(totalParsed);
      totalParsed = 0;
      if (historyMatched > 0) portProgressMatched.send((_ImportTarget.history, historyMatched));
      if (ytHistoryMatched > 0) portProgressMatched.send((_ImportTarget.historyYT, ytHistoryMatched));
      if (favouritesMatched > 0) portProgressMatched.send((_ImportTarget.favourites, favouritesMatched));
      historyMatched = 0;
      ytHistoryMatched = 0;
      favouritesMatched = 0;
    }

    void addEntry(YoutubeVideoHistory yth) {
      final id = yth.id;
      // -- updating affected ids map, used to update youtube stats
      if (mapOfAffectedIds[id] != null) {
        mapOfAffectedIds[id] = YoutubeVideoHistory.merge(current: mapOfAffectedIds[id], newRes: yth);
        mapOfAffectedIds[id]!.watches.addAllNoDuplicates(yth.watches.map((e) => YTWatch(dateMSNull: e.dateMSNull, isYTMusic: e.isYTMusic)));
      } else {
        mapOfAffectedIds[id] = yth;
      }
      // ---------------------------------------------------------
      // -- local history --
      final tracks = _matchYTVHToNamidaHistory(
        vh: yth,
        matchYT: matchYT,
        matchYTMusic: matchYTMusic,
        oldestDay: oldestDay,
        newestDay: newestDay,
        matchAll: matchAll,
        tracksIdsMap: historyTracksIdsMap,
        matchByTitleAndArtistIfNotFoundInMap: isMatchingTypeTitleAndArtist,
        onMissingEntries: (entries) {
          for (final e in entries) {
            missingEntries.addForce(e, e.dateMSSE);
          }
        },
        reverseTitleMatcher: reverseTitleMatcher,
      );
      historyMatched += tracks.length;
      for (var item in tracks) {
        final day = item.dateAdded.toDaysSince1970();
        final tracks = localHistory[day] ??= [];
        final exists = tracks.any((e) => e.track == item.track && e.sourceNull == item.sourceNull && _isSameSecond(e.dateAdded, item.dateAdded));
        if (!exists) {
          daysToSaveLocal.add(day);
          tracks.add(item);
          addedLocalHistoryCount++;
        }
      }

      // -- youtube history --
      for (var w in yth.watches) {
        final canAdd = _canSafelyAddToYTHistory(
          watch: w,
          matchYT: matchYT,
          matchYTMusic: matchYTMusic,
          newestDay: newestDay,
          oldestDay: oldestDay,
        );
        if (canAdd) {
          ytHistoryMatched++;
          final ytid = YoutubeID(
            id: id,
            source: w.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
            watchNull: w,
            playlistID: null,
          );
          final day = ytid.dateAddedMS.toDaysSince1970();
          final videos = ytHistory[day] ??= [];
          final exists = videos.any((e) => e.id == id && e.sourceNull == ytid.sourceNull && _isSameSecond(e.dateAddedMS, ytid.dateAddedMS));
          if (!exists) {
            daysToSaveYT.add(day);
            videos.add(ytid);
            addedYTHistoryCount++;
          }
        }
      }
    }

    ({int count, int readCount}) addItems<E>(Iterable<E> items, YoutubeVideoHistory? Function(E item) toEntry) {
      int count = 0;
      int readCount = 0;
      for (final item in items) {
        count++;
        totalParsed++;
        try {
          final entry = toEntry(item);
          if (entry != null) {
            readCount++;
            addEntry(entry);
          }
        } catch (e) {
          printo(e, isError: true);
        }
        if (totalParsed >= chunkSize) sendProgress();
      }
      return (count: count, readCount: readCount);
    }

    bool hasUnreadableHtml = false;
    for (final file in files) {
      if (_isHtmlFile(file)) {
        final entries = _YTTakeoutHtmlParser.splitEntries(file.readAsBytesSync());
        final added = addItems(entries, _YTTakeoutHtmlParser.parseEntry);
        if (added.count > 0 && added.readCount == 0) hasUnreadableHtml = true;
      } else {
        addItems(jsonDecodeUtf8(file.readAsBytesSync()) as List? ?? const [], _ytTakeoutJsonEntry);
      }
    }

    final favourites = <TrackWithDate>[];
    if (tracksIdsMap != null) {
      for (final video in likedVideos) {
        totalParsed++;
        final match = tracksIdsMap[video.id];
        if (match == null) continue;
        final tracks = matchAll ? match : [match.first];
        favouritesMatched += tracks.length;
        for (final tr in tracks) {
          final twd = TrackWithDate(dateAdded: video.dateMS, track: tr, source: TrackSource.youtube);
          favourites.add(twd);
        }
      }
    }

    sendProgress();

    missingEntries.sortByReverse((e) => e.value.length);

    return (
      affectedIds: mapOfAffectedIds,
      daysToSaveLocal: daysToSaveLocal,
      daysToSaveYT: daysToSaveYT,
      favourites: favourites,
      addedLocalHistoryCount: addedLocalHistoryCount,
      addedYTHistoryCount: addedYTHistoryCount,
      localHistory: localHistory,
      ytHistory: ytHistory,
      missingEntriesSorted: missingEntries,
      hasUnreadableHtml: hasUnreadableHtml,
    );
  }

  static Map<String, List<Track>> _mapTracksByYoutubeID(List<_YTHistoryParserTrackParams> tracks) {
    final tracksIdsMap = <String, List<Track>>{};
    for (var trMap in tracks) {
      String? videoId = NamidaLinkUtils.extractYoutubeId(trMap.comment);
      if (videoId == null) {
        final filename = trMap.path.getFilename;
        videoId = NamidaLinkRegex.youtubeIdInFilenameRegex.firstMatch(filename)?.group(1);
        videoId ??= NamidaLinkUtils.extractYoutubeIdInTrailingBrackets(filename);
      }
      if (videoId != null) {
        tracksIdsMap.addForce(videoId, Track.decide(trMap.path, trMap.isVideo));
      }
    }
    return tracksIdsMap;
  }

  static bool _isHtmlFile(File file) => NamidaFileExtensionsWrapper.html.isPathValid(file.path);

  static const _kTakeoutAdDetails = 'From Google Ads';

  /// removed videos have no link, older imports stored them under this id.
  static const _kRemovedVideoId = 'null';

  static YoutubeVideoHistory? _ytTakeoutJsonEntry(dynamic p) {
    final details = p['details'] as List?;
    final isAd = details != null && details.any((e) => e is Map && e['name'] == _kTakeoutAdDetails);
    if (isAd) return null;
    final dateMS = YoutubeImportController.parseDate(p['time'] ?? '')?.millisecondsSinceEpoch;
    if (dateMS == null) return null;
    final url = p['titleUrl'] as String?;
    final channel = (p['subtitles'] as List?)?.firstOrNull as Map?;
    return _ytTakeoutEntry(
      url: url,
      title: (p['title'] as String).replaceFirst('Watched ', ''),
      channel: channel?['name'] as String? ?? '',
      channelUrl: channel?['url'] as String? ?? '',
      dateMS: dateMS,
      isYTMusic: p['header'] == 'YouTube Music',
    );
  }

  static YoutubeVideoHistory _ytTakeoutEntry({
    required String? url,
    required String title,
    required String channel,
    required String channelUrl,
    required int dateMS,
    required bool isYTMusic,
  }) {
    final String id;
    if (url == null) {
      id = _kRemovedVideoId;
    } else {
      id = url.length >= 11 ? url.substring(url.length - 11) : url;
    }
    return YoutubeVideoHistory(
      id: id,
      title: title,
      channel: channel,
      channelUrl: channelUrl,
      watches: [
        YTWatch(
          dateMSNull: dateMS,
          isYTMusic: isYTMusic,
        ),
      ],
    );
  }

  static bool _canSafelyAddToYTHistory({
    required YTWatch watch,
    int? oldestDay,
    int? newestDay,
    required bool matchYT,
    required bool matchYTMusic,
  }) {
    // ---- sussy checks ----

    // -- if the watch day is outside range specified
    if (oldestDay != null && newestDay != null) {
      final watchAsDSE = watch.dateMS.toDaysSince1970();
      if (watchAsDSE < oldestDay || watchAsDSE > newestDay) return false;
    }

    // -- if the type is youtube music, but the user dont want ytm.
    if (watch.isYTMusic && !matchYTMusic) return false;

    // -- if the type is youtube, but the user dont want yt.
    if (!watch.isYTMusic && !matchYT) return false;

    return true;
  }

  static List<TrackWithDate> _matchYTVHToNamidaHistory({
    required YoutubeVideoHistory vh,
    required bool matchYT,
    required bool matchYTMusic,
    required int? oldestDay,
    required int? newestDay,
    required bool matchAll,
    required Map<String, List<Track>>? tracksIdsMap,
    required bool matchByTitleAndArtistIfNotFoundInMap,
    required void Function(Iterable<_MissingListenEntry> missingEntries) onMissingEntries,
    required ReverseSearchMatcher<_YTHistoryMatchEntry> reverseTitleMatcher,
  }) {
    if (vh.id == _kRemovedVideoId) return const [];

    Iterable<Track> tracks = <Track>[];

    if (tracksIdsMap != null) {
      final match = tracksIdsMap[vh.id];
      if (match != null && match.isNotEmpty) {
        tracks = matchAll ? match : [match.first];
      }
    }

    if (tracks.isEmpty && matchByTitleAndArtistIfNotFoundInMap) {
      final titleTokens = SearchMatcher.tokenizeHaystack(vh.title);
      late final channelTokens = SearchMatcher.tokenizeHaystack(vh.channel);

      /// matching has to meet 2 conditons:
      /// 1. [json title] contains [track.title]
      /// 2. - [json title] contains [track.artistsList.first]
      ///     or
      ///    - [json channel] contains [track.album]
      ///    (useful for nightcore channels, album has to be the channel name)
      ///     or
      ///    - [json channel] contains [track.artistsList.first]
      bool isMatching(_YTHistoryMatchEntry e) =>
          e.canMatchByTitleOnly || //
          SearchMatcher.isContainedIn(e.artistTokens, titleTokens) ||
          SearchMatcher.isContainedIn(e.albumTokens, channelTokens) ||
          SearchMatcher.isContainedIn(e.artistTokens, channelTokens);

      if (matchAll) {
        final matched = reverseTitleMatcher.matchContainedIn(titleTokens).where(isMatching);
        tracks = matched.map((e) => Track.decide(e.track.path, e.track.isVideo)).toFixedList();
      } else {
        final mostSpecific = reverseTitleMatcher.matchMostSpecific(titleTokens, isMatching)?.track;
        if (mostSpecific != null) tracks = [Track.decide(mostSpecific.path, mostSpecific.isVideo)];
      }
    }

    final tracksToAdd = <TrackWithDate>[];
    if (tracks.isNotEmpty) {
      for (var d in vh.watches) {
        final canAdd = _canSafelyAddToYTHistory(
          watch: d,
          matchYT: matchYT,
          matchYTMusic: matchYTMusic,
          newestDay: newestDay,
          oldestDay: oldestDay,
        );
        if (canAdd) {
          tracksToAdd.addAll(
            tracks.map(
              (tr) => TrackWithDate(
                dateAdded: d.dateMS,
                track: tr,
                source: d.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
              ),
            ),
          );
        }
      }
    } else {
      onMissingEntries(
        vh.watches.map(
          (e) => _MissingListenEntry(
            youtubeID: vh.id,
            dateMSSE: e.dateMS,
            source: e.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
            artistOrChannel: vh.channel,
            title: vh.title,
            isFavourite: false,
          ),
        ),
      );
    }
    return tracksToAdd;
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  Future<({List<int> historyDays, int addedHistoryCount, Map<_MissingListenEntry, List<int>> missingEntriesSorted, List<TrackWithDate> favourites})?> _addGeneralSource({
    required List<File> files,
    required List<File> favouriteFiles,
    required bool addHistory,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required Future<_GeneralSourceResult?> Function(_GeneralSourceParserParams params) parser,
  }) async {
    final portProgressParsed = RawReceivePort((message) {
      parsedHistoryJson.value += message as int;
    });
    final portProgressMatched = RawReceivePort(_onMatchedProgress);
    final portLoadingProgress = ReceivePort();

    final localHistory = addHistory ? HistoryController.inst.historyMap.value : SplayTreeMap<int, List<TrackWithDate>>();
    final _GeneralSourceParserParams params = (
      tracks: Indexer.inst.allTracksMappedByPath.values
          .map(
            (e) => (
              title: e.title,
              artist: e.originalArtist,
              taggedArtists: e.multiValues?.artists,
              mbid: e.extraTags?[TagLibField.MUSICBRAINZ_TRACKID],
              path: e.path,
              isVideo: e.isVideo,
            ),
          )
          .toFixedList(),
      oldestDay: oldestDate?.toDaysSince1970(),
      newestDay: newestDate?.toDaysSince1970(),
      files: files,
      favouriteFiles: favouriteFiles,
      addHistory: addHistory,
      matchAll: matchAll,
      artistsSplitConfig: ArtistsSplitConfig.settings(),
      portProgressParsed: portProgressParsed.sendPort,
      portProgressMatched: portProgressMatched.sendPort,
      portLoadingProgress: portLoadingProgress.sendPort,
      localHistory: localHistory,
    );
    StreamSubscription? portLoadingProgressSub;
    portLoadingProgressSub = portLoadingProgress.listen((message) {
      message as int;
      final shouldClosePort = !message.isNegative;
      message = message.abs();
      totalJsonToParse.value = message;
      _loadingFileProgress.value = (_loadingFileProgress.value.$2, _loadingFileProgress.value.$2);
      if (shouldClosePort) {
        portLoadingProgress.close();
        portLoadingProgressSub?.cancel();
      }
    });

    if (addHistory) HistoryController.inst.setIdleStatus(true);

    try {
      final res = await Isolate.run(() => parser(params));
      if (res == null) return null;

      if (addHistory) HistoryController.inst.historyMap.value = res.localHistory;
      if (res.addedHistoryCount > 0) {
        HistoryController.inst.totalHistoryItemsCount.value += res.addedHistoryCount;
        HistoryController.inst.totalHistoryItemsCount.refresh();
      }

      return (
        historyDays: res.daysToSaveLocal,
        addedHistoryCount: res.addedHistoryCount,
        missingEntriesSorted: res.missingEntriesSorted,
        favourites: res.favourites,
      );
    } finally {
      portProgressParsed.close();
      portProgressMatched.close();
      portLoadingProgress.close();
      if (addHistory) await HistoryController.inst.setIdleStatus(false);
    }
  }

  @visibleForTesting
  // ignore: library_private_types_in_public_api
  static Future<_GeneralSourceResult?> debugAddLastFmSource(_GeneralSourceParserParams params) => _addLastFmSourceIsolate(params);

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addLastFmSourceIsolate(_GeneralSourceParserParams params) async {
    // used for cases where date couldnt be parsed, so it uses this one as a reference
    int? lastDate;
    // -- hoisted, `itemToInfoFn` runs once per line & lastfm exports go well into 6 figures.
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    return _addGeneralSourceIsolate(
      params,
      trackSource: TrackSource.lastfm,
      loadingProgressCounterFn: JsonToHistoryParser._countLinesInFile,
      fileToItemsFn: (file) => file.readAsLinesSync(),
      itemToInfoFn: (line) {
        final pieces = _splitCsvLine(line);

        // success means: date == trueDate && lastDate is updated.
        // failure means: date == lastDate - 30 seconds, or skipped if no date was parsed yet
        // this is used for cases where date couldn't be parsed, so it'll add the track with (date == lastDate - 30 seconds)
        int date;
        try {
          date = dateFormat.parseLoose(pieces.last, true).millisecondsSinceEpoch;
        } catch (e) {
          final previousDate = lastDate;
          if (previousDate == null) return null;
          date = previousDate - 30000;
        }
        lastDate = date;

        return _GeneralSourceItemInfo(
          itemArtist: pieces[0],
          itemTitle: pieces[2],
          dateMSSE: date,
        );
      },
    );
  }

  static List<String> _splitCsvLine(String line) {
    if (!line.contains('"')) return line.split(',');

    const quote = 0x22;
    const comma = 0x2C;
    final fields = <String>[];
    final field = StringBuffer();
    bool isQuoted = false;
    for (int i = 0; i < line.length; i++) {
      final codeUnit = line.codeUnitAt(i);
      if (isQuoted) {
        if (codeUnit != quote) {
          field.writeCharCode(codeUnit);
        } else if (i + 1 < line.length && line.codeUnitAt(i + 1) == quote) {
          field.writeCharCode(quote);
          i++;
        } else {
          isQuoted = false;
        }
      } else if (codeUnit == comma) {
        fields.add(field.toString());
        field.clear();
      } else if (codeUnit == quote && field.isEmpty) {
        isQuoted = true;
      } else {
        field.writeCharCode(codeUnit);
      }
    }
    fields.add(field.toString());
    return fields;
  }

  @visibleForTesting
  // ignore: library_private_types_in_public_api
  static Future<_GeneralSourceResult?> debugAddSpotifySource(_GeneralSourceParserParams params) => _addSpotifySourceIsolate(params);

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addSpotifySourceIsolate(_GeneralSourceParserParams params) async {
    final importTimeMS = currentTimeMS;
    return _addGeneralSourceIsolate<dynamic, dynamic>(
      params,
      trackSource: TrackSource.spotify,
      favouritesParser: (
        fileToItems: _spotifyLibraryTracks,
        itemToInfo: (map) {
          final title = map['track'] as String?;
          final artist = map['artist'] as String?;
          if (title == null || artist == null) return null;
          return _GeneralSourceItemInfo(
            itemArtist: artist,
            itemTitle: title,
            dateMSSE: importTimeMS,
          );
        },
      ),
      loadingProgressCounterFn: JsonToHistoryParser._countJsonObjectsInList,
      fileToItemsFn: (file) => jsonDecodeUtf8(file.readAsBytesSync()) as List? ?? [],
      itemToInfoFn: (map) {
        final basicEndTime = map['endTime'] as String?;
        if (basicEndTime != null) return _spotifyBasicItemInfo(map, basicEndTime);

        final mapMsPlayed = map['ms_played'] as int?;
        if (mapMsPlayed != null && mapMsPlayed == 0) {
          // -- wasn't really played, skip... (or should we?)
          return null;
        }
        final mapTitle = map['master_metadata_track_name'] as String?;
        final mapArtist = map['master_metadata_album_artist_name'] as String?;
        if (mapTitle == null || mapArtist == null) return null;
        final mapTimestamp = DateTime.parse(map['ts'] ?? '');
        // final mapAlbum = map['master_metadata_album_album_name'] as String;

        final dateMSSE = mapTimestamp.millisecondsSinceEpoch;

        return _GeneralSourceItemInfo(
          itemArtist: mapArtist,
          itemTitle: mapTitle,
          dateMSSE: dateMSSE,
        );
      },
    );
  }

  /// `YourLibrary.json` of the account data export: `{tracks: [{artist, album, track, uri}], albums: [...], ...}`.
  static List _spotifyLibraryTracks(File file) {
    final library = jsonDecodeUtf8(file.readAsBytesSync()) as Map?;
    return library?['tracks'] as List? ?? const [];
  }

  /// account data export entry: `{endTime: 'yyyy-MM-dd HH:mm' (utc), artistName, trackName, msPlayed}`.
  static _GeneralSourceItemInfo? _spotifyBasicItemInfo(Map map, String endTime) {
    final msPlayed = map['msPlayed'] as int?;
    if (msPlayed == 0) return null;
    final title = map['trackName'] as String?;
    final artist = map['artistName'] as String?;
    if (title == null || artist == null) return null;
    final endTimeUtc = DateTime.parse('${endTime}Z');
    return _GeneralSourceItemInfo(
      itemArtist: artist,
      itemTitle: title,
      dateMSSE: endTimeUtc.millisecondsSinceEpoch,
    );
  }

  @visibleForTesting
  // ignore: library_private_types_in_public_api
  static Future<_GeneralSourceResult?> debugAddListenBrainzSource(_GeneralSourceParserParams params) => _addListenBrainzSourceIsolate(params);

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addListenBrainzSourceIsolate(_GeneralSourceParserParams params) async {
    // -- loves hold only recording ids, the listens of the same export give their titles
    final listenedRecordings = <String, _GeneralSourceItemInfo>{};
    final shouldCollectRecordings = params.favouriteFiles.isNotEmpty;
    return _addGeneralSourceIsolate<Uint8List, Uint8List>(
      params,
      trackSource: TrackSource.listenbrainz,
      favouritesParser: (
        fileToItems: (file) => JsonToHistoryParser._splitLinesBytes(file.readAsBytesSync()),
        itemToInfo: (line) {
          final map = jsonDecodeUtf8(line) as Map;
          final isLoved = map['score'] == 1;
          if (!isLoved) return null;

          final mbid = map['recording_mbid'] as String?;
          final msid = map['recording_msid'] as String?;
          final createdSecondsSinceEpoch = map['created'] as int;
          final createdMS = createdSecondsSinceEpoch * 1000;
          final listened = listenedRecordings[mbid] ?? listenedRecordings[msid];

          if (listened == null) {
            final recordingId = mbid ?? msid ?? '';
            return _GeneralSourceItemInfo(
              itemArtist: '',
              itemTitle: recordingId,
              dateMSSE: createdMS,
              mbid: mbid,
            );
          }

          final recordingMbid = mbid ?? listened.mbid;
          return _GeneralSourceItemInfo(
            itemArtist: listened.itemArtist,
            itemTitle: listened.itemTitle,
            dateMSSE: createdMS,
            mbid: recordingMbid,
          );
        },
      ),
      loadingProgressCounterFn: JsonToHistoryParser._countLinesInFile,
      fileToItemsFn: (file) => JsonToHistoryParser._splitLinesBytes(file.readAsBytesSync()),
      itemToInfoFn: (line) {
        final map = jsonDecodeUtf8(line) as Map;

        // -- seconds, written as a float by newer exports
        final listenedAtSecondsSinceEpoch = map['listened_at'] as num;
        final dateMSSE = (listenedAtSecondsSinceEpoch * 1000).round();

        final metadata = map['track_metadata'] as Map;

        final mapTitle = metadata['track_name'] as String;
        final mapArtist = metadata['artist_name'] as String;
        final additionalInfo = metadata['additional_info'] as Map?;
        final mbidMapping = metadata['mbid_mapping'] as Map?;
        final submittedMbid = additionalInfo?['recording_mbid'] as String?;
        final mappedMbid = mbidMapping?['recording_mbid'] as String?;
        final mbid = submittedMbid ?? mappedMbid;

        final info = _GeneralSourceItemInfo(
          itemArtist: mapArtist,
          itemTitle: mapTitle,
          dateMSSE: dateMSSE,
          mbid: mbid,
        );
        if (shouldCollectRecordings) {
          final msid = map['recording_msid'] as String?;
          if (msid != null) listenedRecordings[msid] = info;
          if (mbid != null) listenedRecordings[mbid] = info;
        }
        return info;
      },
    );
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addGeneralSourceIsolate<E, F>(
    _GeneralSourceParserParams params, {
    required TrackSource trackSource,
    _FavouritesParser<F>? favouritesParser,
    required Future<int> Function(File file) loadingProgressCounterFn,
    required List<E> Function(File file) fileToItemsFn,
    required _GeneralSourceItemInfo? Function(E item) itemToInfoFn,
  }) async {
    final allTracks = params.tracks;
    final oldestDay = params.oldestDay;
    final newestDay = params.newestDay;
    final files = params.files;
    final addHistory = params.addHistory;
    final matchAll = params.matchAll;
    final artistsSplitConfig = params.artistsSplitConfig;

    final localHistory = params.localHistory;

    int addedHistoryCount = 0;

    final portProgressParsed = params.portProgressParsed;
    final portProgressMatched = params.portProgressMatched;
    final portLoadingProgress = params.portLoadingProgress;

    final favouriteItems = <F>[];
    if (favouritesParser != null) {
      for (final file in params.favouriteFiles) {
        favouriteItems.addAll(favouritesParser.fileToItems(file));
      }
    }

    int linesCount = favouriteItems.length;
    for (final file in files) {
      linesCount += await loadingProgressCounterFn(file);
    }

    portLoadingProgress.send(linesCount);

    final tracksLookupTitlesMap = <String, List<_HistoryParserTrackParams>>{};
    final tracksLookupArtistsMap = <String, List<_HistoryParserTrackParams>>{};
    final tracksLookupMbidsMap = <String, List<_HistoryParserTrackParams>>{};

    final reverseTitleMatcher = ReverseSearchMatcher<_GeneralSourceMatchEntry>();

    for (final trMap in allTracks) {
      final title = trMap.title;
      tracksLookupTitlesMap.addForce(title.cleanUpForComparison, trMap);

      final mbid = trMap.mbid;
      if (mbid != null) tracksLookupMbidsMap.addForce(mbid, trMap);

      final originalArtist = trMap.artist;
      final artistsList = Indexer.splitArtist(
        title: title,
        originalArtist: originalArtist,
        config: artistsSplitConfig,
      );
      for (final ar in artistsList) {
        tracksLookupArtistsMap.addForce(ar.cleanUpForComparison, trMap);
      }
      // -- whole tagged values on top of the split ones, old matches stay
      final taggedArtists = trMap.taggedArtists;
      if (taggedArtists != null) {
        for (final ar in taggedArtists) {
          tracksLookupArtistsMap.addForce(ar.cleanUpForComparison, trMap);
        }
      }
      if (artistsList.isNotEmpty) {
        final artistTokens = SearchMatcher.tokenize(artistsList.first);
        final titleWithoutExtras = title.splitFirst('(').splitFirst('[');
        reverseTitleMatcher.addItem((track: trMap, artistTokens: artistTokens), titleWithoutExtras);
      }
    }

    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    final daysToSaveLocal = <int>[];
    final favourites = <TrackWithDate>[];
    const chunkSize = 20;

    List<_HistoryParserTrackParams> matchItem(_GeneralSourceItemInfo info) {
      final mbidMatching = tracksLookupMbidsMap[info.mbid];
      if (mbidMatching != null) return matchAll ? mbidMatching : [mbidMatching.first];

      final tracks = <_HistoryParserTrackParams>[];
      final itemTitleCleaned = info.itemTitle.cleanUpForComparison;
      final itemArtistCleaned = info.itemArtist.cleanUpForComparison;

      final titleMatching = tracksLookupTitlesMap[itemTitleCleaned];
      final artistMatching = tracksLookupArtistsMap[itemArtistCleaned];
      if (titleMatching != null && titleMatching.isNotEmpty && artistMatching != null && artistMatching.isNotEmpty) {
        final intersection = titleMatching.where((track) => artistMatching.contains(track));
        if (intersection.isNotEmpty) {
          if (matchAll) {
            tracks.addAll(intersection);
          } else {
            tracks.add(intersection.first);
          }
        }
      }

      if (tracks.isEmpty) {
        /// matching has to meet 2 conditons:
        /// [item artist] contains [track.artistsList.first]
        /// [item title] contains [track.title], anything after ( or [ is ignored.
        final itemTitleTokens = SearchMatcher.tokenizeHaystack(info.itemTitle);
        late final itemArtistTokens = SearchMatcher.tokenizeHaystack(info.itemArtist);
        bool isMatching(_GeneralSourceMatchEntry e) => SearchMatcher.isContainedIn(e.artistTokens, itemArtistTokens);
        if (matchAll) {
          final matchedTracks = reverseTitleMatcher.matchContainedIn(itemTitleTokens).where(isMatching).map((e) => e.track);
          tracks.addAll(matchedTracks);
        } else {
          final mostSpecific = reverseTitleMatcher.matchMostSpecific(itemTitleTokens, isMatching);
          if (mostSpecific != null) tracks.add(mostSpecific.track);
        }
      }
      return tracks;
    }

    void addMissingEntry(_GeneralSourceItemInfo info, {required bool isFavourite}) {
      final me = _MissingListenEntry(
        youtubeID: null,
        dateMSSE: info.dateMSSE,
        source: trackSource,
        artistOrChannel: info.itemArtist,
        title: info.itemTitle,
        isFavourite: isFavourite,
      );
      missingEntries.addForce(me, me.dateMSSE);
    }

    int historyMatched = 0;
    int favouritesMatched = 0;
    void sendProgress() {
      portProgressParsed.send(totalParsed);
      totalParsed = 0;
      if (historyMatched > 0) portProgressMatched.send((_ImportTarget.history, historyMatched));
      if (favouritesMatched > 0) portProgressMatched.send((_ImportTarget.favourites, favouritesMatched));
      historyMatched = 0;
      favouritesMatched = 0;
    }

    /// updates progress every [chunkSize] lines, calling on every loop affects benchmarks heavily.
    void sendProgressChunks() {
      if (totalParsed >= chunkSize) sendProgress();
    }

    for (final file in files) {
      final items = fileToItemsFn(file);

      for (final item in items) {
        totalParsed++;

        try {
          final info = itemToInfoFn(item);
          if (info == null || !addHistory) continue;

          if (!_isInDaysRange(info.dateMSSE, oldestDay, newestDay)) continue;

          final tracks = matchItem(info);
          historyMatched += tracks.length;
          if (tracks.isNotEmpty) {
            for (final trMap in tracks) {
              final twd = TrackWithDate(
                dateAdded: info.dateMSSE,
                track: Track.decide(trMap.path, trMap.isVideo),
                source: trackSource,
              );
              final day = twd.dateAdded.toDaysSince1970();
              final tracks = localHistory[day] ??= [];
              if (!tracks.contains(twd)) {
                daysToSaveLocal.add(day);
                tracks.add(twd);
                addedHistoryCount++;
              }
            }
          } else {
            addMissingEntry(info, isFavourite: false);
          }

          sendProgressChunks();
        } catch (e) {
          printo(e, isError: true);
          continue;
        }
      }
    }

    if (favouritesParser != null) {
      for (final item in favouriteItems) {
        totalParsed++;

        try {
          final info = favouritesParser.itemToInfo(item);
          if (info == null) continue;

          if (!_isInDaysRange(info.dateMSSE, oldestDay, newestDay)) continue;

          final tracks = matchItem(info);
          favouritesMatched += tracks.length;
          if (tracks.isNotEmpty) {
            for (final trMap in tracks) {
              final twd = TrackWithDate(
                dateAdded: info.dateMSSE,
                track: Track.decide(trMap.path, trMap.isVideo),
                source: trackSource,
              );
              favourites.add(twd);
            }
          } else {
            addMissingEntry(info, isFavourite: true);
          }

          sendProgressChunks();
        } catch (e) {
          printo(e, isError: true);
          continue;
        }
      }
    }

    // normally the loop automatically adds every [chunkSize] tracks, this one is to ensure adding any tracks left.
    sendProgress();

    missingEntries.sortByReverse((e) => e.value.length);

    return _GeneralSourceResult(
      daysToSaveLocal: daysToSaveLocal,
      addedHistoryCount: addedHistoryCount,
      localHistory: localHistory,
      missingEntriesSorted: missingEntries,
      favourites: favourites,
    );
  }

  Future<void> _updateYoutubeStatsDirectory({
    required Map<String, YoutubeVideoHistory> affectedIds,
    required void Function(int updatedIdsCount) onProgress,
  }) async {
    final progressPort = RawReceivePort((message) {
      onProgress(message as int);
    });
    await _updateYoutubeStatsDirectoryIsolate.thready((affectedIds: affectedIds, dirPath: AppDirs.YT_STATS, progressPort: progressPort.sendPort));
    progressPort.close();
  }

  @visibleForTesting
  static void debugUpdateYoutubeStatsDirectory(({Map<String, YoutubeVideoHistory> affectedIds, String dirPath, SendPort progressPort}) params) =>
      _updateYoutubeStatsDirectoryIsolate(params);

  /// merges the stats buckets of [sourceDirPath] (ex: an extracted backup) into [AppDirs.YT_STATS], watches are combined.
  static Future<void> mergeYoutubeStatsDirectory(String sourceDirPath) {
    return _mergeYoutubeStatsDirectoryIsolate.thready((sourceDirPath: sourceDirPath, dirPath: AppDirs.YT_STATS));
  }

  static void _mergeYoutubeStatsDirectoryIsolate(({String sourceDirPath, String dirPath}) params) {
    final affectedIds = <String, YoutubeVideoHistory>{};
    for (final f in Directory(params.sourceDirPath).listSyncSafe()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final list = f.readAsJsonSync() as List?;
        if (list == null) continue;
        for (final videoJson in list) {
          final video = YoutubeVideoHistory.fromJson(videoJson);
          affectedIds[video.id] = video;
        }
      } catch (_) {}
    }
    if (affectedIds.isEmpty) return;
    _updateYoutubeStatsDirectoryIsolate((affectedIds: affectedIds, dirPath: params.dirPath, progressPort: null));
  }

  static void _updateYoutubeStatsDirectoryIsolate(({Map<String, YoutubeVideoHistory> affectedIds, String dirPath, SendPort? progressPort}) params) {
    final affectedIds = params.affectedIds;
    final progressPort = params.progressPort;
    final dirPath = params.dirPath;

    // ===== Getting affected files (which are arranged by id[0])
    final fileIdentifierMap = <String, Map<String, YoutubeVideoHistory>>{}; // {id[0]: {id: YoutubeVideoHistory}}
    for (final entry in affectedIds.entries) {
      final id = entry.key;
      final video = entry.value;
      final filename = id[0];
      if (fileIdentifierMap[filename] == null) {
        fileIdentifierMap[filename] = {id: video};
      } else {
        fileIdentifierMap[filename]!.addAll({id: video});
      }
    }
    // ==================================================

    // ===== looping each file and getting all videos inside
    // then mapping all to a map for instant lookup
    // then merging affected videos inside [fileIdentifierMap]
    for (final entry in fileIdentifierMap.entries) {
      final filename = entry.key; // id[0]
      final videos = entry.value; // {id: YoutubeVideoHistory}

      final file = FileParts.join(dirPath, '$filename.json');
      bool didFailReading = false;
      final res = file.readAsJsonSync(onError: () => didFailReading = true);
      if (didFailReading) {
        // -- rewriting it would keep only the affected videos
        progressPort?.send(videos.length);
        continue;
      }
      final videosInStorage = (res as List?)?.map((e) => YoutubeVideoHistory.fromJson(e)) ?? [];
      final videosMapInStorage = <String, YoutubeVideoHistory>{};
      for (final videoStor in videosInStorage) {
        videosMapInStorage[videoStor.id] = videoStor;
      }

      // ===========
      final updatedIds = <String>[];
      for (final affectedv in videos.entries) {
        final id = affectedv.key;
        final video = affectedv.value;
        if (videosMapInStorage[id] != null) {
          // -- video exists inside the file, so we add only new watches
          videosMapInStorage[id] = YoutubeVideoHistory.merge(current: videosMapInStorage[id], newRes: video);
          videosMapInStorage[id]!.watches.addAllNoDuplicates(video.watches.map((e) => YTWatch(dateMSNull: e.dateMSNull, isYTMusic: e.isYTMusic)));
        } else {
          // -- video does NOT exist, so the whole video is added with all its watches.
          videosMapInStorage[id] = video;
        }
        updatedIds.add(id);
      }
      final bucketVideos = videosMapInStorage.values.toFixedList();
      final tempFile = File('${file.path}.tmp');
      final writtenFile = tempFile.writeAsJsonSync(bucketVideos);
      try {
        writtenFile?.renameSync(file.path);
      } catch (_) {
        // -- windows: rename fails while the bucket is locked
        file.writeAsJsonSync(bucketVideos);
        tempFile.deleteIfExistsSync();
      }
      progressPort?.send(updatedIds.length);
    }
  }

  static List<Uint8List> _splitLinesBytes(Uint8List bytes) {
    final lines = <Uint8List>[];
    final length = bytes.length;
    int start = 0;
    for (int i = 0; i < length; i++) {
      if (bytes[i] == 0x0A) {
        lines.add(Uint8List.sublistView(bytes, start, i));
        start = i + 1;
      }
    }
    if (start < length) lines.add(Uint8List.sublistView(bytes, start, length));
    return lines;
  }

  static Future<int> _countLinesInFile(File file) async {
    var count = 0;
    var prevByte = 0;
    const LF = 10;
    const CR = 13;

    await for (final chunk in file.openRead()) {
      for (final byte in chunk) {
        if (byte != CR) {
          if (byte == LF) {
            if (prevByte != CR) count++;
          }
          prevByte = byte;
          continue;
        }
        count++;
        prevByte = byte;
      }
    }

    if (prevByte != LF && prevByte != CR && (file.fileSizeSync() ?? 0) > 0) {
      count++;
    }
    return count;
  }

  static Future<int> _countJsonObjectsInList(File file) async {
    int count = 0;
    int depth = 0;
    bool inString = false;
    bool escape = false;

    await for (final chunk in file.openRead()) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (b == 0x5C) {
          escape = true;
          continue;
        } // '\'
        if (b == 0x22) {
          inString = !inString;
          continue;
        } // '"'
        if (inString) continue;
        if (b == 0x7B) depth++; // '{'
        if (b == 0x7D && --depth == 0) count++; // '}'
      }
    }
    return count;
  }
}

enum DataImportType {
  history,
  favourites,
  playlists,
  subscriptions,
  ;

  String toText() => switch (this) {
    DataImportType.history => lang.history,
    DataImportType.favourites => lang.favourites,
    DataImportType.playlists => lang.playlists,
    DataImportType.subscriptions => lang.subscriptions,
  };

  IconData toIcon() => switch (this) {
    DataImportType.history => Broken.refresh,
    DataImportType.favourites => Broken.heart,
    DataImportType.playlists => Broken.music_library_2,
    DataImportType.subscriptions => Broken.profile_2user,
  };
}

class _MissingListenEntry {
  final int dateMSSE;
  final TrackSource source;
  final String? youtubeID;
  final String title;
  final String artistOrChannel;
  final bool isFavourite;

  const _MissingListenEntry({
    required this.dateMSSE,
    required this.source,
    required this.title,
    required this.youtubeID,
    required this.artistOrChannel,
    required this.isFavourite,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _MissingListenEntry) return false;
    return other.dateMSSE == dateMSSE &&
        other.source == source &&
        other.youtubeID == youtubeID &&
        other.title == title &&
        other.artistOrChannel == artistOrChannel &&
        other.isFavourite == isFavourite;
  }

  @override
  int get hashCode {
    return Object.hash(dateMSSE, source, youtubeID, title, artistOrChannel, isFavourite);
  }
}

/// html takeouts are second-precise, same watch from json/html takeouts should be considered a duplicate.
bool _isSameSecond(int ms, int otherMS) => ms ~/ 1000 == otherMS ~/ 1000;

extension _YTWatchListExt on List<YTWatch> {
  void addAllNoDuplicates(Iterable<YTWatch> items) {
    for (final item in items) {
      final alrExists = this.any((e) => e.isYTMusic == item.isYTMusic && _isSameSecond(e.dateMS, item.dateMS));
      if (!alrExists) this.add(item);
    }
  }
}

/// Parses `watch-history.html` of google takeout, each entry body looks like:
/// `Watched <a href="VIDEO_URL">TITLE</a><br><a href="CHANNEL_URL">CHANNEL</a><br>Feb 4, 2022, 4:20:56 PM EET`
///
/// by claude
class _YTTakeoutHtmlParser {
  static final _entryStart = ascii.encode('<p class="mdl-typography--title">');
  static final _bodyStart = ascii.encode('mdl-typography--body-1">');
  static final _bodyEnd = ascii.encode('</div>');
  static final _ytMusicHeader = ascii.encode('YouTube Music<');
  static final _adDetails = ascii.encode(JsonToHistoryParser._kTakeoutAdDetails);

  static final _dateSeparators = RegExp(r'[\s,]+');
  static final _gmtOffset = RegExp(r'^(?:GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$');
  static final _entities = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);');
  static final _tags = RegExp(r'<[^>]*>');
  static final _watchedPrefixRegex = RegExp('^Watched[ \u00A0]');

  static const _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, //
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Sept': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  /// takeout prints all dates with the fixed offset of the export zone, regardless of dst at that date.
  static const _zoneOffsetsMinutes = {
    'UTC': 0, 'GMT': 0, 'WET': 0, 'WEST': 60, 'BST': 60, 'CET': 60, 'CEST': 120, 'EET': 120, 'EEST': 180, 'MSK': 180, //
    'PKT': 300, 'IST': 330, 'WIB': 420, 'HKT': 480, 'SGT': 480, 'AWST': 480, 'JST': 540, 'KST': 540,
    'ACST': 570, 'ACDT': 630, 'AEST': 600, 'AEDT': 660, 'NZST': 720, 'NZDT': 780,
    'HST': -600, 'AKST': -540, 'AKDT': -480, 'PST': -480, 'PDT': -420, 'MST': -420, 'MDT': -360,
    'CST': -360, 'CDT': -300, 'EST': -300, 'EDT': -240, 'AST': -240, 'ADT': -180, 'NST': -210, 'NDT': -150,
  };

  static Future<int> countEntries(File file) async {
    final pattern = _entryStart;
    final first = pattern[0];
    int count = 0;
    int matched = 0;
    await for (final chunk in file.openRead()) {
      final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        if (b == pattern[matched]) {
          if (++matched == pattern.length) {
            count++;
            matched = 0;
          }
        } else {
          matched = b == first ? 1 : 0; // safe since pattern[0] never repeats
        }
      }
    }
    return count;
  }

  static Iterable<_YTTakeoutHtmlEntry> splitEntries(Uint8List bytes) sync* {
    int entryStart = _indexOf(bytes, _entryStart, 0);
    while (entryStart != -1) {
      final bodyTagStart = _indexOf(bytes, _bodyStart, entryStart);
      if (bodyTagStart == -1) return;
      final bodyStart = bodyTagStart + _bodyStart.length;
      final bodyEnd = _indexOf(bytes, _bodyEnd, bodyStart);
      if (bodyEnd == -1) return;
      final nextEntryStart = _indexOf(bytes, _entryStart, bodyEnd);
      final detailsEnd = nextEntryStart == -1 ? bytes.length : nextEntryStart;
      final adDetailsIndex = _indexOf(bytes, _adDetails, bodyEnd, detailsEnd);
      yield (
        isYTMusic: _startsWith(bytes, _ytMusicHeader, entryStart + _entryStart.length),
        isAd: adDetailsIndex != -1,
        body: utf8.decode(Uint8List.sublistView(bytes, bodyStart, bodyEnd), allowMalformed: true),
      );
      entryStart = nextEntryStart;
    }
  }

  static YoutubeVideoHistory? parseEntry(_YTTakeoutHtmlEntry entry) {
    if (entry.isAd) return null;
    final lines = entry.body.split('<br>');
    int dateLineIndex = lines.length - 1;
    String dateText = '';
    while (dateLineIndex > 0) {
      final lineText = _stripTags(lines[dateLineIndex]);
      dateText = _unescape(lineText);
      if (dateText.trim().isNotEmpty) break;
      dateLineIndex--;
    }
    if (dateLineIndex == 0) return null;
    final firstLine = lines.first;
    final video = _parseLink(firstLine);
    final dateMS = _parseDateMS(dateText);
    if (dateMS == null) return null;
    final title = video?.text ?? _parseLinklessTitle(firstLine);
    final channel = dateLineIndex > 1 ? _parseLink(lines[1]) : null;
    return JsonToHistoryParser._ytTakeoutEntry(
      url: video?.url,
      title: title,
      channel: channel?.text ?? '',
      channelUrl: channel?.url ?? '',
      dateMS: dateMS,
      isYTMusic: entry.isYTMusic,
    );
  }

  static ({String url, String text})? _parseLink(String line) {
    const tag = '<a href="';
    final tagStart = line.indexOf(tag);
    if (tagStart == -1) return null;
    final urlStart = tagStart + tag.length;
    final urlEnd = line.indexOf('">', urlStart);
    if (urlEnd == -1) return null;
    final textEnd = line.indexOf('</a>', urlEnd);
    if (textEnd == -1) return null;
    return (
      url: _unescape(line.substring(urlStart, urlEnd)),
      text: _unescape(line.substring(urlEnd + 2, textEnd)),
    );
  }

  static String _parseLinklessTitle(String line) {
    final lineText = _stripTags(line);
    final text = _unescape(lineText).trim();
    return text.replaceFirst(_watchedPrefixRegex, '');
  }

  /// supports `MMM d, yyyy, h:mm:ss a z` & `d MMM yyyy, HH:mm:ss z`.
  static int? _parseDateMS(String text) {
    final parts = text.trim().split(_dateSeparators);
    if (parts.length < 5) return null;
    final monthFirst = _months[parts[0]];
    final month = monthFirst ?? _months[parts[1]];
    final time = parts[3].split(':');
    if (month == null || time.length != 3) return null;

    final day = int.parse(monthFirst != null ? parts[1] : parts[0]);
    final year = int.parse(parts[2]);
    final meridiem = parts.length > 5 ? parts[4] : null;
    final hour = int.parse(time[0]);
    final hour24 = meridiem == null ? hour : hour % 12 + (meridiem == 'PM' ? 12 : 0);
    final minute = int.parse(time[1]);
    final second = int.parse(time[2]);

    final offsetMinutes = _parseOffsetMinutes(parts.last);
    if (offsetMinutes == null) return DateTime(year, month, day, hour24, minute, second).millisecondsSinceEpoch;
    return DateTime.utc(year, month, day, hour24, minute, second).millisecondsSinceEpoch - offsetMinutes * Duration.millisecondsPerMinute;
  }

  static int? _parseOffsetMinutes(String zone) {
    final known = _zoneOffsetsMinutes[zone];
    if (known != null) return known;
    final match = _gmtOffset.firstMatch(zone);
    if (match == null) return null;
    final minutes = int.parse(match[2]!) * 60 + int.parse(match[3] ?? '0');
    return match[1] == '-' ? -minutes : minutes;
  }

  static String _stripTags(String text) {
    if (!text.contains('<')) return text;
    return text.replaceAll(_tags, '');
  }

  static String _unescape(String text) {
    if (!text.contains('&')) return text;
    return text.replaceAllMapped(_entities, (m) {
      final entity = m[1]!;
      return switch (entity) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        'nbsp' => '\u00A0',
        _ => String.fromCharCode(entity[1] == 'x' ? int.parse(entity.substring(2), radix: 16) : int.parse(entity.substring(1))),
      };
    });
  }

  static int _indexOf(Uint8List bytes, Uint8List pattern, int start, [int? end]) {
    final first = pattern[0];
    final searchEnd = end ?? bytes.length;
    final last = searchEnd - pattern.length;
    outer:
    for (int i = start; i <= last; i++) {
      if (bytes[i] != first) continue;
      for (int j = 1; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static bool _startsWith(Uint8List bytes, Uint8List pattern, int start) {
    if (start + pattern.length > bytes.length) return false;
    for (int j = 0; j < pattern.length; j++) {
      if (bytes[start + j] != pattern[j]) return false;
    }
    return true;
  }
}

typedef _YTTakeoutHtmlEntry = ({bool isYTMusic, bool isAd, String body});

class _GeneralSourceItemInfo {
  final String itemArtist;
  final String itemTitle;
  final int dateMSSE;
  final String? mbid;

  const _GeneralSourceItemInfo({
    required this.itemArtist,
    required this.itemTitle,
    required this.dateMSSE,
    this.mbid,
  });
}

class _GeneralSourceResult {
  final List<int> daysToSaveLocal;
  final int addedHistoryCount;
  final SplayTreeMap<int, List<TrackWithDate>> localHistory;
  final Map<_MissingListenEntry, List<int>> missingEntriesSorted;
  final List<TrackWithDate> favourites;

  const _GeneralSourceResult({
    required this.daysToSaveLocal,
    required this.addedHistoryCount,
    required this.localHistory,
    required this.missingEntriesSorted,
    required this.favourites,
  });
}

typedef _SourceFiles = ({List<File> history, List<File> favourites, Set<String> playlistsDirectories, List<File> subscriptions});

typedef _TakeoutLikedVideo = ({String id, int dateMS});

typedef _FavouritesParser<F> = ({List<F> Function(File file) fileToItems, _GeneralSourceItemInfo? Function(F item) itemToInfo});

typedef _HistoryParserTrackParams = ({
  String title,
  String artist,
  List<String>? taggedArtists,
  String? mbid,
  String path,
  bool isVideo,
});

typedef _GeneralSourceMatchEntry = ({_HistoryParserTrackParams track, Set<String> artistTokens});

typedef _YTHistoryParserTrackParams = ({
  String title,
  String artist,
  String album,
  String path,
  String comment,
  bool isVideo,
});

typedef _YTHistoryMatchEntry = ({_YTHistoryParserTrackParams track, Set<String> artistTokens, Set<String> albumTokens, bool canMatchByTitleOnly});

typedef _YTTakeoutParserParams = ({
  List<_YTHistoryParserTrackParams> tracks,
  List<File> files,
  List<_TakeoutLikedVideo> likedVideos,
  bool isMatchingTypeLink,
  bool isMatchingTypeTitleAndArtist,
  bool matchYT,
  bool matchYTMusic,
  int? oldestDay,
  int? newestDay,
  bool matchAll,
  ArtistsSplitConfig artistsSplitConfig,
  SendPort portProgressParsed,
  SendPort portProgressMatched,
  SendPort portLoadingProgress,
  SplayTreeMap<int, List<TrackWithDate>> localHistory,
  SplayTreeMap<int, List<YoutubeID>> ytHistory,
});

typedef _YTTakeoutParserResult = ({
  Map<String, YoutubeVideoHistory>? affectedIds,
  List<int> daysToSaveLocal,
  List<int> daysToSaveYT,
  int addedLocalHistoryCount,
  int addedYTHistoryCount,
  SplayTreeMap<int, List<TrackWithDate>> localHistory,
  SplayTreeMap<int, List<YoutubeID>> ytHistory,
  Map<_MissingListenEntry, List<int>> missingEntriesSorted,
  bool hasUnreadableHtml,
  List<TrackWithDate> favourites,
});

typedef _GeneralSourceParserParams = ({
  List<_HistoryParserTrackParams> tracks,
  int? oldestDay,
  int? newestDay,
  List<File> files,
  List<File> favouriteFiles,
  bool addHistory,
  bool matchAll,
  ArtistsSplitConfig artistsSplitConfig,
  SendPort portProgressParsed,
  SendPort portProgressMatched,
  SendPort portLoadingProgress,
  SplayTreeMap<int, List<TrackWithDate>> localHistory,
});

enum _ImportTarget {
  history,
  historyYT,
  favourites,
  favouritesYT,
  playlists,
  subscriptions,
  ;

  String toText() => switch (this) {
    _ImportTarget.history => lang.history,
    _ImportTarget.historyYT => '${lang.history} (${lang.youtube})',
    _ImportTarget.favourites => lang.favourites,
    _ImportTarget.favouritesYT => '${lang.favourites} (${lang.youtube})',
    _ImportTarget.playlists => lang.playlists,
    _ImportTarget.subscriptions => lang.subscriptions,
  };
}

enum _HistoryImportStep {
  loadingFiles,
  backup,
  parsing,
  updatingStats,
  playlists,
  subscriptions,
  saving,
}

class _ImportDoneCheckMark extends StatelessWidget {
  const _ImportDoneCheckMark();

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: JsonToHistoryParser.inst.isParsing,
      builder: (context, isParsing) => NamidaCheckMark(
        size: 20.0,
        active: !isParsing,
        loading: isParsing,
        burst: true,
      ),
    );
  }
}

class _ImportStepTile extends StatelessWidget {
  static const _kCheckMarkSize = 16.0;
  static const _kCheckMarkGap = 12.0;

  final _HistoryImportStep step;
  final String title;
  final Widget? trailing;
  final Widget? details;

  const _ImportStepTile({
    required this.step,
    required this.title,
    this.trailing,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final parser = JsonToHistoryParser.inst;
    return Obx(
      (context) {
        final currentStep = parser._importStep.valueR;
        final isDone = !parser.isParsing.valueR || step.index < currentStep.index;
        final isActive = !isDone && step == currentStep;
        final isReached = isDone || isActive;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: isReached ? 1.0 : 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  NamidaCheckMark(
                    size: _kCheckMarkSize,
                    active: isDone,
                    loading: isActive,
                  ),
                  const SizedBox(
                    width: _kCheckMarkGap,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.displayMedium,
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (isReached && details != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: _kCheckMarkSize + _kCheckMarkGap),
                  child: details,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingFilesProgressText extends StatelessWidget {
  const _LoadingFilesProgressText();

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: JsonToHistoryParser.inst._loadingFileProgress,
      builder: (context, progress) => progress.$2 == 0
          ? const SizedBox()
          : Text(
              '${progress.$1.formatDecimal()} / ${progress.$2.formatDecimal()}',
              style: context.textTheme.displaySmall,
            ),
    );
  }
}

class _HistoryBackupFilenameText extends StatelessWidget {
  const _HistoryBackupFilenameText();

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: JsonToHistoryParser.inst._historyBackupFilename,
      builder: (context, filename) => filename.isEmpty
          ? const SizedBox()
          : Text(
              filename,
              style: context.textTheme.displaySmall,
            ),
    );
  }
}

class _ImportResultsText extends StatelessWidget {
  final List<_ImportTarget> targets;

  const _ImportResultsText({
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final parser = JsonToHistoryParser.inst;
    return Obx(
      (context) {
        final matched = parser._importMatched.valueR;
        final added = parser._importAdded.valueR;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: targets
              .map(
                (e) => Text(
                  JsonToHistoryParser._importResultToText(e, matched[e] ?? 0, added[e]),
                  style: textTheme.displaySmall,
                ),
              )
              .toFixedList(),
        );
      },
    );
  }
}

class _ParsingPercentageText extends StatelessWidget {
  const _ParsingPercentageText();

  @override
  Widget build(BuildContext context) {
    final parser = JsonToHistoryParser.inst;
    return Obx(
      (context) => parser.totalJsonToParse.valueR == 0
          ? const SizedBox()
          : Text(
              '${(parser._percentageR * 100).round()}%',
              style: context.textTheme.displaySmall,
            ),
    );
  }
}

class _ParsingProgressDetails extends StatelessWidget {
  final String? dateRangeText;
  final List<_ImportTarget> targets;

  const _ParsingProgressDetails({
    required this.dateRangeText,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final parser = JsonToHistoryParser.inst;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 8.0,
        ),
        Obx(
          (context) {
            final isCountingEntries = parser.totalJsonToParse.valueR == 0 && parser.isParsing.valueR && parser._importStep.valueR == _HistoryImportStep.parsing;
            return LinearProgressIndicator(
              borderRadius: BorderRadius.circular(99.0),
              value: isCountingEntries ? null : parser._percentageR,
              minHeight: 3.0,
              backgroundColor: theme.colorScheme.onSurface.withOpacityExt(0.1),
            );
          },
        ),
        const SizedBox(
          height: 6.0,
        ),
        Obx(
          (context) => Text(
            '${parser.parsedHistoryJson.valueR.formatDecimal()} / ${parser.totalJsonToParse.valueR.formatDecimal()} ${lang.parsed}',
            style: theme.textTheme.displaySmall,
          ),
        ),
        if (dateRangeText != null)
          Text(
            dateRangeText!,
            style: theme.textTheme.displaySmall,
          ),
        const SizedBox(
          height: 6.0,
        ),
        _ImportResultsText(
          targets: targets,
        ),
      ],
    );
  }
}

class _StatsProgressText extends StatelessWidget {
  const _StatsProgressText();

  @override
  Widget build(BuildContext context) {
    final parser = JsonToHistoryParser.inst;
    return Obx(
      (context) {
        final total = parser._updatingYoutubeStatsDirectoryTotal.valueR;
        return total == 0
            ? const SizedBox()
            : Text(
                '${parser._updatingYoutubeStatsDirectoryProgress.valueR.formatDecimal()} / ${total.formatDecimal()}',
                style: context.textTheme.displaySmall,
              );
      },
    );
  }
}
