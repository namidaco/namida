// ignore_for_file: avoid_rx_value_getter_outside_obx, constant_identifier_names
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/search_matcher.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class JsonToHistoryParser {
  static JsonToHistoryParser get inst => _instance;
  static final JsonToHistoryParser _instance = JsonToHistoryParser._internal();
  JsonToHistoryParser._internal();

  final parsedHistoryJson = 0.obs;
  final totalJsonToParse = 0.obs;
  final addedHistoryJsonToPlaylist = 0.obs;
  final isParsing = false.obs;
  final _loadingFileProgress = (0, 0).obs;
  final _updatingYoutubeStatsDirectoryProgress = 0.obs;
  final _updatingYoutubeStatsDirectoryTotal = 0.obs;
  final Rx<TrackSource> currentParsingSource = TrackSource.local.obs;
  final _currentOldestDate = Rxn<DateTime>();
  final _currentNewestDate = Rxn<DateTime>();
  final _importStep = _HistoryImportStep.loadingFiles.obs;
  final _historyBackupFilename = ''.obs;
  bool _includesHistoryBackupStep = false;

  double get _percentageR {
    final p = parsedHistoryJson.valueR / totalJsonToParse.valueR;
    return p.isFinite ? p : 0;
  }

  String get _currentImportTitle => switch (currentParsingSource.value) {
    TrackSource.youtube || TrackSource.youtubeMusic => lang.importYoutubeHistory,
    TrackSource.lastfm => lang.importLastFmHistory,
    TrackSource.spotify => lang.importSpotifyHistory,
    TrackSource.listenbrainz => lang.importListenBrainzHistory,
    TrackSource.local => lang.extractingInfo,
  };

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

    NamidaNavigator.inst.navigateDialog(
      onDismissing: _hideParsingDialog,
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: _currentImportTitle,
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
                          title: '${lang.createBackup} (${lang.history})',
                          details: const _HistoryBackupFilenameText(),
                        ),
                      _ImportStepTile(
                        step: _HistoryImportStep.parsing,
                        title: lang.extractingInfo,
                        trailing: const _ParsingPercentageText(),
                        details: _ParsingProgressDetails(
                          dateRangeText: dateRangeText,
                        ),
                      ),
                      if (currentParsingSource.value == TrackSource.youtube)
                        _ImportStepTile(
                          step: _HistoryImportStep.updatingStats,
                          title: lang.stats,
                          trailing: const _StatsProgressText(),
                        ),
                      _ImportStepTile(
                        step: _HistoryImportStep.saving,
                        title: lang.saving,
                      ),
                    ]
                    .addSeparators(
                      separator: const SizedBox(
                        height: 14.0,
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

    Future<void> addTrackToHistory(MapEntry<_MissingListenEntry, List<int>> entry, Track choosen) async {
      final twds = entry.value.map(
        (e) => TrackWithDate(
          dateAdded: e,
          track: choosen,
          source: entry.key.source,
        ),
      );
      await HistoryController.inst.addTracksToHistory(twds.toList());
      _latestMissingMapAddedStatus[entry.key] = choosen;
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
          await addTrackToHistory(entry, choosenTrack);
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
                confirmAddAsDummy(
                  confirmMessage: 'Add ${_latestMissingMap.value.length} as dummy tracks?',
                  onConfirm: () async {
                    final historyDays = <int>[];
                    for (var e in _latestMissingMap.value.entries) {
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
                                          child: Text(
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
                                        Obx(
                                          (context) => NamidaIconButton(
                                            horizontalPadding: 2.0,
                                            icon: Broken.command,
                                            iconSize: 20.0,
                                            onPressed: () => confirmAddAsDummy(
                                              confirmMessage: 'Add "${entry.key.artistOrChannel} - ${entry.key.title}" as dummy track?',
                                              onConfirm: () async => await addTrackToHistory(entry, getDummyTrack(entry.key)),
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
    addedHistoryJsonToPlaylist.value = 0;
    _updatingYoutubeStatsDirectoryProgress.value = 0;
    _updatingYoutubeStatsDirectoryTotal.value = 0;
    _currentOldestDate.value = null;
    _currentNewestDate.value = null;
    _importStep.value = _HistoryImportStep.loadingFiles;
    _historyBackupFilename.value = '';
  }

  Timer? _notificationTimer;

  Future<void> addFilesSourceToNamidaHistory({
    required List<File> files,
    Directory? mainDirectory,
    required TrackSource source,
    bool matchAll = false,
    bool ytIsMatchingTypeLink = true,
    bool isMatchingTypeTitleAndArtist = false,
    bool ytMatchYT = true,
    bool ytMatchYTMusic = true,
    DateTime? oldestDate,
    DateTime? newestDate,
    required bool backupHistoryFirst,
  }) async {
    final isYT = source == TrackSource.youtube || source == TrackSource.youtubeMusic;

    _resetValues();
    isParsing.value = true;
    _currentOldestDate.value = oldestDate;
    _currentNewestDate.value = newestDate;
    currentParsingSource.value = isYT ? TrackSource.youtube : source;
    _includesHistoryBackupStep = backupHistoryFirst;
    showParsingProgressDialog();

    Directory? tempZipMainDestination;

    try {
      final contents = mainDirectory != null && files.isEmpty ? await mainDirectory.listAllIsolate(recursive: true, followLinks: false) : files;
      files = await _filterFilesFromPossibleZips(
        contents,
        source,
        () async => tempZipMainDestination ??= await Directory.systemTemp.createTemp('namida_parser_'),
        (progress, total) => _loadingFileProgress.value = (progress, total),
      );

      if (files.isEmpty) {
        snackyy(message: 'No related files were found in this directory.', isError: true);
        _closeParsingDialog();
        _resetValues();
        return;
      }

      if (backupHistoryFirst) {
        _importStep.value = _HistoryImportStep.backup;
        final backupItems = [
          ...AppPathsBackupEnumCategories.history,
          if (isYT) ...[
            ...AppPathsBackupEnumCategories.history_yt,
            AppPathsBackupEnum.YT_STATS,
          ],
        ];
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
        NotificationManager.instance.importHistoryNotification(parsedHistoryJson.value, totalJsonToParse.value, startTime);
      });

      final datesAdded = <int>[];
      final datesAddedYoutube = <int>[];
      var allMissingEntriesSorted = <_MissingListenEntry, List<int>>{};

      switch (source) {
        case TrackSource.youtube || TrackSource.youtubeMusic:
          final res = await _parseYTHistoryJsonAndAdd(
            files: files,
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
          }
          break;

        case TrackSource.lastfm:
          final res = await _addLastFmSource(
            files: files,
            matchAll: matchAll,
            oldestDate: oldestDate,
            newestDate: newestDate,
          );
          if (res != null) {
            allMissingEntriesSorted = res.missingEntriesSorted;
            datesAdded.addAll(res.historyDays);
          }
          break;

        case TrackSource.spotify:
          final res = await _addSpotifySource(
            files: files,
            matchAll: matchAll,
            oldestDate: oldestDate,
            newestDate: newestDate,
          );
          if (res != null) {
            allMissingEntriesSorted = res.missingEntriesSorted;
            datesAdded.addAll(res.historyDays);
          }
          break;
        case TrackSource.listenbrainz:
          final res = await _addListenBrainzSource(
            files: files,
            matchAll: matchAll,
            oldestDate: oldestDate,
            newestDate: newestDate,
          );
          if (res != null) {
            allMissingEntriesSorted = res.missingEntriesSorted;
            datesAdded.addAll(res.historyDays);
          }
          break;
        case TrackSource.local:
          break;
      }

      _importStep.value = _HistoryImportStep.saving;

      // -- local history --
      HistoryController.inst.removeDuplicatedItems(datesAdded);
      HistoryController.inst.sortHistoryTracks(datesAdded);
      await HistoryController.inst.saveHistoryToStorage(datesAdded);
      HistoryController.inst.updateMostPlayedPlaylist();

      // -- youtube history --
      if (datesAddedYoutube.isNotEmpty) {
        YoutubeHistoryController.inst.removeDuplicatedItems(datesAddedYoutube);
        YoutubeHistoryController.inst.sortHistoryTracks(datesAddedYoutube);
        await YoutubeHistoryController.inst.saveHistoryToStorage(datesAddedYoutube);
        YoutubeHistoryController.inst.updateMostPlayedPlaylist();
      }

      isParsing.value = false;
      HomePageRefresher.requestRefresh();

      _notificationTimer?.cancel();
      NotificationManager.instance.doneImportingHistoryNotification(parsedHistoryJson.value, addedHistoryJsonToPlaylist.value);

      _latestMissingMap.value = allMissingEntriesSorted;
      _latestMissingMapAddedStatus.clear();
      showMissingEntriesDialog();
    } catch (e, st) {
      printo(e, isError: true);
      _notificationTimer?.cancel();
      NotificationManager.instance.failedImportingHistoryNotification(e.toString());
      _closeParsingDialog();
      _resetValues();
      snackyy(title: lang.error, message: e.toString(), isError: true);
      logger.error('Error importing history (${source.name})', e: e, st: st);
    } finally {
      tempZipMainDestination?.delete(recursive: true);
    }
  }

  Future<List<File>> _filterFilesFromPossibleZips(
    List<FileSystemEntity> contents,
    TrackSource source,
    Future<Directory> Function() tempZipMainDestination,
    void Function(int progress, int total) onProgress,
  ) async {
    final files = <File>[];

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
    if (total == 0) return [];

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
                  final nameLC = name.toLowerCase();
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
                  if (name != 'feedback.jsonl') {
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

    return files;
  }

  Future<({List<int> historyDays, List<int> ytHistoryDays, Map<_MissingListenEntry, List<int>> missingEntriesSorted})?> _parseYTHistoryJsonAndAdd({
    required List<File> files,
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
    final portProgressAdded = RawReceivePort((message) {
      addedHistoryJsonToPlaylist.value += message as int;
    });
    final portLoadingProgress = ReceivePort();

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
      isMatchingTypeLink: isMatchingTypeLink,
      isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist,
      matchYT: matchYT,
      matchYTMusic: matchYTMusic,
      oldestDay: oldestDate?.toDaysSince1970(),
      newestDay: newestDate?.toDaysSince1970(),
      matchAll: matchAll,
      artistsSplitConfig: ArtistsSplitConfig.settings(),
      portProgressParsed: portProgressParsed.sendPort,
      portProgressAdded: portProgressAdded.sendPort,
      portLoadingProgress: portLoadingProgress.sendPort,
      localHistory: HistoryController.inst.historyMap.value,
      ytHistory: YoutubeHistoryController.inst.historyMap.value,
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
    HistoryController.inst.setIdleStatus(true);
    YoutubeHistoryController.inst.setIdleStatus(true);

    try {
      final res = await _parseYTHistoryJsonAndAddIsolate.thready(params);
      if (res == null) return null;

      final mapOfAffectedIds = res.affectedIds;

      if (mapOfAffectedIds != null) {
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

      HistoryController.inst.historyMap.value = res.localHistory;
      YoutubeHistoryController.inst.historyMap.value = res.ytHistory;
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
        missingEntriesSorted: res.missingEntriesSorted,
      );
    } finally {
      portProgressParsed.close();
      portProgressAdded.close();
      portLoadingProgress.close();
      await Future.wait([
        HistoryController.inst.setIdleStatus(false),
        YoutubeHistoryController.inst.setIdleStatus(false),
      ]);
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

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<
    ({
      Map<String, YoutubeVideoHistory>? affectedIds,
      List<int> daysToSaveLocal,
      List<int> daysToSaveYT,
      int addedLocalHistoryCount,
      int addedYTHistoryCount,
      SplayTreeMap<int, List<TrackWithDate>> localHistory,
      SplayTreeMap<int, List<YoutubeID>> ytHistory,
      Map<_MissingListenEntry, List<int>> missingEntriesSorted,
    })?
  >
  _parseYTHistoryJsonAndAddIsolate(_YTTakeoutParserParams params) async {
    final allTracks = params.tracks;
    final files = params.files;
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
    final portProgressAdded = params.portProgressAdded;
    final portLoadingProgress = params.portLoadingProgress;

    Map<String, List<Track>>? tracksIdsMap;
    if (isMatchingTypeLink) {
      tracksIdsMap = <String, List<Track>>{};
      for (var trMap in allTracks) {
        String? videoId = NamidaLinkUtils.extractYoutubeId(trMap.comment);
        videoId ??= NamidaLinkUtils.extractYoutubeId(trMap.path.getFilename);
        if (videoId != null && videoId.isNotEmpty) {
          tracksIdsMap.addForce(videoId, Track.decide(trMap.path, trMap.isVideo));
        }
      }
    }

    final reverseTitleMatcher = ReverseSearchMatcher<_YTHistoryParserTrackParams>();
    final reverseArtistMatcher = ReverseSearchMatcher<_YTHistoryParserTrackParams>();
    final reverseAlbumMatcher = ReverseSearchMatcher<_YTHistoryParserTrackParams>();
    if (isMatchingTypeTitleAndArtist) {
      for (var trMap in allTracks) {
        final title = trMap.title;
        final album = trMap.album;
        final originalArtist = trMap.artist;
        final artistsList = Indexer.splitArtist(
          title: title,
          originalArtist: originalArtist,
          config: artistsSplitConfig,
        );
        reverseTitleMatcher.addItemWithTokens(trMap, title);
        reverseAlbumMatcher.addItemWithTokens(trMap, album);
        if (artistsList.isNotEmpty) {
          reverseArtistMatcher.addItemWithTokens(trMap, artistsList.first);
        }
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
    portLoadingProgress.send(jsonResponseTotal); // 1

    final mapOfAffectedIds = <String, YoutubeVideoHistory>{};
    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    int totalAdded = 0;
    final daysToSaveLocal = <int>[];
    final daysToSaveYT = <int>[];
    const chunkSize = 20;

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
        tracksIdsMap: tracksIdsMap,
        matchByTitleAndArtistIfNotFoundInMap: isMatchingTypeTitleAndArtist,
        onMissingEntries: (entries) {
          for (final e in entries) {
            missingEntries.addForce(e, e.dateMSSE);
          }
        },
        allTracks: allTracks,
        artistsSplitConfig: artistsSplitConfig,
        reverseTitleMatcher: reverseTitleMatcher,
        reverseArtistMatcher: reverseArtistMatcher,
        reverseAlbumMatcher: reverseAlbumMatcher,
      );
      totalAdded += tracks.length;
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

    void addItems<E>(Iterable<E> items, YoutubeVideoHistory? Function(E item) toEntry) {
      for (final item in items) {
        totalParsed++;
        try {
          final entry = toEntry(item);
          if (entry != null) addEntry(entry);
        } catch (e) {
          printo(e, isError: true);
        }
        if (totalParsed >= chunkSize) {
          portProgressParsed.send(totalParsed);
          totalParsed = 0;
        }
        if (totalAdded >= chunkSize) {
          portProgressAdded.send(totalAdded);
          totalAdded = 0;
        }
      }
    }

    for (final file in files) {
      if (_isHtmlFile(file)) {
        addItems(_YTTakeoutHtmlParser.splitEntries(file.readAsBytesSync()), _YTTakeoutHtmlParser.parseEntry);
      } else {
        addItems(jsonDecodeUtf8(file.readAsBytesSync()) as List? ?? const [], _ytTakeoutJsonEntry);
      }
    }

    portProgressParsed.send(totalParsed);
    portProgressAdded.send(totalAdded);

    missingEntries.sortByReverse((e) => e.value.length);

    return (
      affectedIds: mapOfAffectedIds,
      daysToSaveLocal: daysToSaveLocal,
      daysToSaveYT: daysToSaveYT,
      addedLocalHistoryCount: addedLocalHistoryCount,
      addedYTHistoryCount: addedYTHistoryCount,
      localHistory: localHistory,
      ytHistory: ytHistory,
      missingEntriesSorted: missingEntries,
    );
  }

  static bool _isHtmlFile(File file) => NamidaFileExtensionsWrapper.html.isPathValid(file.path);

  static YoutubeVideoHistory? _ytTakeoutJsonEntry(dynamic p) {
    final url = p['titleUrl'] as String?;
    if (url == null) return null;
    final channel = (p['subtitles'] as List?)?.firstOrNull as Map?;
    return _ytTakeoutEntry(
      url: url,
      title: (p['title'] as String).replaceFirst('Watched ', ''),
      channel: channel?['name'] as String? ?? '',
      channelUrl: channel?['url'] as String? ?? '',
      dateMS: YoutubeImportController.parseDate(p['time'] ?? '')?.millisecondsSinceEpoch,
      isYTMusic: p['header'] == 'YouTube Music',
    );
  }

  static YoutubeVideoHistory _ytTakeoutEntry({
    required String url,
    required String title,
    required String channel,
    required String channelUrl,
    required int? dateMS,
    required bool isYTMusic,
  }) {
    return YoutubeVideoHistory(
      id: url.length >= 11 ? url.substring(url.length - 11) : url,
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
    required ArtistsSplitConfig artistsSplitConfig,
    required List<_YTHistoryParserTrackParams> allTracks,
    required ReverseSearchMatcher<_YTHistoryParserTrackParams> reverseTitleMatcher,
    required ReverseSearchMatcher<_YTHistoryParserTrackParams> reverseArtistMatcher,
    required ReverseSearchMatcher<_YTHistoryParserTrackParams> reverseAlbumMatcher,
  }) {
    Iterable<Track> tracks = <Track>[];

    if (tracksIdsMap != null) {
      final match = tracksIdsMap[vh.id];
      if (match != null && match.isNotEmpty) {
        tracks = matchAll ? match : [match.first];
      }
    }

    if (tracks.isEmpty && matchByTitleAndArtistIfNotFoundInMap) {
      final titleCleaned = vh.title.cleanUpForComparison;
      final channelCleaned = vh.channel.cleanUpForComparison;

      final titleMatches = reverseTitleMatcher.matchContainedIn(titleCleaned);
      if (titleMatches.isNotEmpty) {
        /// matching has to meet 2 conditons:
        /// 1. [json title] contains [track.title]
        /// 2. - [json title] contains [track.artistsList.first]
        ///     or
        ///    - [json channel] contains [track.album]
        ///    (useful for nightcore channels, album has to be the channel name)
        ///     or
        ///    - [json channel] contains [track.artistsList.first]
        final artistInTitle = reverseArtistMatcher.matchContainedIn(titleCleaned);
        final albumInChannel = reverseAlbumMatcher.matchContainedIn(channelCleaned);
        final artistInChannel = reverseArtistMatcher.matchContainedIn(channelCleaned);

        final secondCondition = artistInTitle.union(albumInChannel).union(artistInChannel);
        final matched = secondCondition.isEmpty ? titleMatches : titleMatches.intersection(secondCondition);

        final result = matchAll ? matched : (matched.isEmpty ? <_YTHistoryParserTrackParams>{} : {matched.first});
        tracks = result.map((e) => Track.decide(e.path, e.isVideo));
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
          ),
        ),
      );
    }
    return tracksToAdd;
  }

  Future<({List<int> historyDays, Map<_MissingListenEntry, List<int>> missingEntriesSorted})?> _addLastFmSource({
    required List<File> files,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
  }) async {
    return await _addGeneralSource(
      files: files,
      matchAll: matchAll,
      oldestDate: oldestDate,
      newestDate: newestDate,
      callback: (params) => Isolate.run(() => _addLastFmSourceIsolate(params)),
    );
  }

  Future<({List<int> historyDays, Map<_MissingListenEntry, List<int>> missingEntriesSorted})?> _addSpotifySource({
    required List<File> files,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
  }) async {
    return await _addGeneralSource(
      files: files,
      matchAll: matchAll,
      oldestDate: oldestDate,
      newestDate: newestDate,
      callback: (params) => Isolate.run(() => _addSpotifySourceIsolate(params)),
    );
  }

  Future<({List<int> historyDays, Map<_MissingListenEntry, List<int>> missingEntriesSorted})?> _addListenBrainzSource({
    required List<File> files,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
  }) async {
    return await _addGeneralSource(
      files: files,
      matchAll: matchAll,
      oldestDate: oldestDate,
      newestDate: newestDate,
      callback: (params) => Isolate.run(() => _addListenBrainzSourceIsolate(params)),
    );
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  Future<({List<int> historyDays, Map<_MissingListenEntry, List<int>> missingEntriesSorted})?> _addGeneralSource({
    required List<File> files,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required Future<_GeneralSourceResult?> Function(_GeneralSourceParserParams params) callback,
  }) async {
    final portProgressParsed = RawReceivePort((message) {
      parsedHistoryJson.value += message as int;
    });
    final portProgressAdded = RawReceivePort((message) {
      addedHistoryJsonToPlaylist.value += message as int;
    });
    final portLoadingProgress = ReceivePort();

    final _GeneralSourceParserParams params = (
      tracks: Indexer.inst.allTracksMappedByPath.values
          .map(
            (e) => (
              title: e.title,
              artist: e.originalArtist,
              path: e.path,
              isVideo: e.isVideo,
            ),
          )
          .toFixedList(),
      oldestDay: oldestDate?.toDaysSince1970(),
      newestDay: newestDate?.toDaysSince1970(),
      files: files,
      matchAll: matchAll,
      artistsSplitConfig: ArtistsSplitConfig.settings(),
      portProgressParsed: portProgressParsed.sendPort,
      portProgressAdded: portProgressAdded.sendPort,
      portLoadingProgress: portLoadingProgress.sendPort,
      localHistory: HistoryController.inst.historyMap.value,
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

    HistoryController.inst.setIdleStatus(true);

    try {
      final res = await callback(params);
      if (res == null) return null;

      HistoryController.inst.historyMap.value = res.localHistory;
      if (res.addedHistoryCount > 0) {
        HistoryController.inst.totalHistoryItemsCount.value += res.addedHistoryCount;
        HistoryController.inst.totalHistoryItemsCount.refresh();
      }

      return (
        historyDays: res.daysToSaveLocal,
        missingEntriesSorted: res.missingEntriesSorted,
      );
    } finally {
      portProgressParsed.close();
      portProgressAdded.close();
      portLoadingProgress.close();
      await HistoryController.inst.setIdleStatus(false);
    }
  }

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
        final pieces = line.split(',');

        // success means: date == trueDate && lastDate is updated.
        // failure means: date == lastDate - 30 seconds || date == 0
        // this is used for cases where date couldn't be parsed, so it'll add the track with (date == lastDate - 30 seconds)
        int date = 0;
        try {
          date = dateFormat.parseLoose(pieces.last, true).millisecondsSinceEpoch;
        } catch (e) {
          if (lastDate != null) {
            date = lastDate! - 30000;
          }
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

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addSpotifySourceIsolate(_GeneralSourceParserParams params) async {
    return _addGeneralSourceIsolate(
      params,
      trackSource: TrackSource.spotify,
      loadingProgressCounterFn: JsonToHistoryParser._countJsonObjectsInList,
      fileToItemsFn: (file) => jsonDecodeUtf8(file.readAsBytesSync()) as List? ?? [],
      itemToInfoFn: (map) {
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

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addListenBrainzSourceIsolate(_GeneralSourceParserParams params) async {
    return _addGeneralSourceIsolate(
      params,
      trackSource: TrackSource.listenbrainz,
      loadingProgressCounterFn: JsonToHistoryParser._countLinesInFile,
      fileToItemsFn: (file) => JsonToHistoryParser._splitLinesBytes(file.readAsBytesSync()),
      itemToInfoFn: (line) {
        final map = jsonDecodeUtf8(line) as Map;

        final listenedAtSecondsSinceEpoch = map['listened_at'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(listenedAtSecondsSinceEpoch * 1000);
        final dateMSSE = date.millisecondsSinceEpoch;

        final metadata = map['track_metadata'] as Map;

        final mapTitle = metadata['track_name'] as String;
        final mapArtist = metadata['artist_name'] as String;
        // final trackMBID = metadata["additional_info"]?["track_mbid"] as String?;

        return _GeneralSourceItemInfo(
          itemArtist: mapArtist,
          itemTitle: mapTitle,
          dateMSSE: dateMSSE,
        );
      },
    );
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static Future<_GeneralSourceResult?> _addGeneralSourceIsolate<E>(
    _GeneralSourceParserParams params, {
    required TrackSource trackSource,
    required Future<int> Function(File file) loadingProgressCounterFn,
    required List<E> Function(File file) fileToItemsFn,
    required _GeneralSourceItemInfo? Function(E item) itemToInfoFn,
  }) async {
    final allTracks = params.tracks;
    final oldestDay = params.oldestDay;
    final newestDay = params.newestDay;
    final files = params.files;
    final matchAll = params.matchAll;
    final artistsSplitConfig = params.artistsSplitConfig;

    final localHistory = params.localHistory;

    int addedHistoryCount = 0;

    final portProgressParsed = params.portProgressParsed;
    final portProgressAdded = params.portProgressAdded;
    final portLoadingProgress = params.portLoadingProgress;

    int linesCount = 0;
    for (final file in files) {
      linesCount += await loadingProgressCounterFn(file);
    }

    portLoadingProgress.send(linesCount);

    final tracksLookupTitlesMap = <String, List<_HistoryParserTrackParams>>{};
    final tracksLookupArtistsMap = <String, List<_HistoryParserTrackParams>>{};

    final reverseTitleMatcher = ReverseSearchMatcher<_HistoryParserTrackParams>();
    final reverseArtistMatcher = ReverseSearchMatcher<_HistoryParserTrackParams>();

    for (final trMap in allTracks) {
      final title = trMap.title;
      tracksLookupTitlesMap.addForce(title.cleanUpForComparison, trMap);
      reverseTitleMatcher.addItemWithTokens(trMap, title.splitFirst('(').splitFirst('['));

      final originalArtist = trMap.artist;
      final artistsList = Indexer.splitArtist(
        title: title,
        originalArtist: originalArtist,
        config: artistsSplitConfig,
      );
      for (final ar in artistsList) {
        tracksLookupArtistsMap.addForce(ar.cleanUpForComparison, trMap);
      }
      if (artistsList.isNotEmpty) {
        reverseArtistMatcher.addItemWithTokens(trMap, artistsList.first);
      }
    }

    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    int totalAdded = 0;
    final daysToSaveLocal = <int>[];
    const chunkSize = 20;

    for (final file in files) {
      final items = fileToItemsFn(file);

      for (final item in items) {
        totalParsed++;

        try {
          final info = itemToInfoFn(item);
          if (info == null) continue;

          // -- skips if the date is not inside date range specified.
          if (oldestDay != null && newestDay != null) {
            final watchAsDSE = info.dateMSSE.toDaysSince1970();
            if (watchAsDSE < oldestDay || watchAsDSE > newestDay) continue;
          }

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
            final titleMatches = reverseTitleMatcher.matchContainedIn(itemTitleCleaned);
            final artistMatches = reverseArtistMatcher.matchContainedIn(itemArtistCleaned);
            final matched = titleMatches.intersection(artistMatches);
            if (matchAll) {
              tracks.addAll(matched);
            } else if (matched.isNotEmpty) {
              tracks.add(matched.first);
            }
          }

          totalAdded += tracks.length;
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
            final me = _MissingListenEntry(
              youtubeID: null,
              dateMSSE: info.dateMSSE,
              source: trackSource,
              artistOrChannel: info.itemArtist,
              title: info.itemTitle,
            );
            missingEntries.addForce(me, me.dateMSSE);
          }

          /// updates progress every [chunkSize] lines, calling on every loop affects benchmarks heavily.
          if (totalParsed >= chunkSize) {
            portProgressParsed.send(totalParsed);
            totalParsed = 0;
          }
          if (totalAdded >= chunkSize) {
            portProgressAdded.send(totalAdded);
            totalAdded = 0;
          }
        } catch (e) {
          printo(e, isError: true);
          continue;
        }
      }
    }

    // normally the loop automatically adds every [chunkSize] tracks, this one is to ensure adding any tracks left.
    portProgressParsed.send(totalParsed);
    portProgressAdded.send(totalAdded);

    missingEntries.sortByReverse((e) => e.value.length);

    return _GeneralSourceResult(
      daysToSaveLocal: daysToSaveLocal,
      addedHistoryCount: addedHistoryCount,
      localHistory: localHistory,
      missingEntriesSorted: missingEntries,
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

  static void _updateYoutubeStatsDirectoryIsolate(({Map<String, YoutubeVideoHistory> affectedIds, String dirPath, SendPort progressPort}) params) {
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
      final res = file.readAsJsonSync();
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
      file.writeAsJsonSync(videosMapInStorage.values.toFixedList());
      progressPort.send(updatedIds.length);
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

class _MissingListenEntry {
  final int dateMSSE;
  final TrackSource source;
  final String? youtubeID;
  final String title;
  final String artistOrChannel;

  const _MissingListenEntry({
    required this.dateMSSE,
    required this.source,
    required this.title,
    required this.youtubeID,
    required this.artistOrChannel,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _MissingListenEntry) return false;
    return other.dateMSSE == dateMSSE && other.source == source && other.youtubeID == youtubeID && other.title == title && other.artistOrChannel == artistOrChannel;
  }

  @override
  int get hashCode {
    return Object.hash(dateMSSE, source, youtubeID, title, artistOrChannel);
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

  static final _dateSeparators = RegExp(r'[\s,]+');
  static final _gmtOffset = RegExp(r'^(?:GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$');
  static final _entities = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);');

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
    int start = 0;
    while (true) {
      final entryStart = _indexOf(bytes, _entryStart, start);
      if (entryStart == -1) return;
      final bodyTagStart = _indexOf(bytes, _bodyStart, entryStart);
      if (bodyTagStart == -1) return;
      final bodyStart = bodyTagStart + _bodyStart.length;
      final bodyEnd = _indexOf(bytes, _bodyEnd, bodyStart);
      if (bodyEnd == -1) return;
      yield (
        isYTMusic: _startsWith(bytes, _ytMusicHeader, entryStart + _entryStart.length),
        body: utf8.decode(Uint8List.sublistView(bytes, bodyStart, bodyEnd), allowMalformed: true),
      );
      start = bodyEnd;
    }
  }

  static YoutubeVideoHistory? parseEntry(_YTTakeoutHtmlEntry entry) {
    final lines = entry.body.split('<br>');
    if (lines.length < 2) return null;
    final video = _parseLink(lines.first);
    if (video == null) return null;
    final dateMS = _parseDateMS(lines.last);
    if (dateMS == null) return null;
    final channel = lines.length > 2 ? _parseLink(lines[1]) : null;
    return JsonToHistoryParser._ytTakeoutEntry(
      url: video.url,
      title: video.text,
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
        'nbsp' => ' ',
        _ => String.fromCharCode(entity[1] == 'x' ? int.parse(entity.substring(2), radix: 16) : int.parse(entity.substring(1))),
      };
    });
  }

  static int _indexOf(Uint8List bytes, Uint8List pattern, int start) {
    final first = pattern[0];
    final last = bytes.length - pattern.length;
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

typedef _YTTakeoutHtmlEntry = ({bool isYTMusic, String body});

class _GeneralSourceItemInfo {
  final String itemArtist;
  final String itemTitle;
  final int dateMSSE;

  const _GeneralSourceItemInfo({
    required this.itemArtist,
    required this.itemTitle,
    required this.dateMSSE,
  });
}

class _GeneralSourceResult {
  final List<int> daysToSaveLocal;
  final int addedHistoryCount;
  final SplayTreeMap<int, List<TrackWithDate>> localHistory;
  final Map<_MissingListenEntry, List<int>> missingEntriesSorted;

  const _GeneralSourceResult({
    required this.daysToSaveLocal,
    required this.addedHistoryCount,
    required this.localHistory,
    required this.missingEntriesSorted,
  });
}

typedef _HistoryParserTrackParams = ({
  String title,
  String artist,
  String path,
  bool isVideo,
});

typedef _YTHistoryParserTrackParams = ({
  String title,
  String artist,
  String album,
  String path,
  String comment,
  bool isVideo,
});

typedef _YTTakeoutParserParams = ({
  List<_YTHistoryParserTrackParams> tracks,
  List<File> files,
  bool isMatchingTypeLink,
  bool isMatchingTypeTitleAndArtist,
  bool matchYT,
  bool matchYTMusic,
  int? oldestDay,
  int? newestDay,
  bool matchAll,
  ArtistsSplitConfig artistsSplitConfig,
  SendPort portProgressParsed,
  SendPort portProgressAdded,
  SendPort portLoadingProgress,
  SplayTreeMap<int, List<TrackWithDate>> localHistory,
  SplayTreeMap<int, List<YoutubeID>> ytHistory,
});

typedef _GeneralSourceParserParams = ({
  List<_HistoryParserTrackParams> tracks,
  int? oldestDay,
  int? newestDay,
  List<File> files,
  bool matchAll,
  ArtistsSplitConfig artistsSplitConfig,
  SendPort portProgressParsed,
  SendPort portProgressAdded,
  SendPort portLoadingProgress,
  SplayTreeMap<int, List<TrackWithDate>> localHistory,
});

enum _HistoryImportStep {
  loadingFiles,
  backup,
  parsing,
  updatingStats,
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
      ),
    );
  }
}

class _ImportStepTile extends StatelessWidget {
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: SizedBox.square(
                  dimension: 16.0,
                  child: isActive
                      ? const CircularProgressIndicator(
                          strokeWidth: 2.0,
                        )
                      : Icon(
                          isDone ? Broken.tick_circle : Broken.record,
                          size: 16.0,
                          color: isDone ? theme.colorScheme.secondary : null,
                        ),
                ),
              ),
              const SizedBox(
                width: 12.0,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.displayMedium,
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    if (isReached) ?details,
                  ],
                ),
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

  const _ParsingProgressDetails({
    required this.dateRangeText,
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
            '${parser.parsedHistoryJson.valueR.formatDecimal()} / ${parser.totalJsonToParse.valueR.formatDecimal()} ${lang.parsed} • ${parser.addedHistoryJsonToPlaylist.valueR.formatDecimal()} ${lang.added}',
            style: theme.textTheme.displaySmall,
          ),
        ),
        if (dateRangeText != null)
          Text(
            dateRangeText!,
            style: theme.textTheme.displaySmall,
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
