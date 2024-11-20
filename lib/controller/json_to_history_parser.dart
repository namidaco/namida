// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
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
  final isLoadingFile = false.obs;
  final _updatingYoutubeStatsDirectoryProgress = 0.obs;
  final _updatingYoutubeStatsDirectoryTotal = 0.obs;
  final Rx<TrackSource> currentParsingSource = TrackSource.local.obs;
  final _currentOldestDate = Rxn<DateTime>();
  final _currentNewestDate = Rxn<DateTime>();

  String get _parsedProgressR => '${parsedHistoryJson.valueR.formatDecimal()} / ${totalJsonToParse.valueR.formatDecimal()}';
  String get _parsedProgressPercentageR => '${(_percentageR * 100).round()}%';
  String get _addedHistoryJsonR => addedHistoryJsonToPlaylist.valueR.formatDecimal();
  double get _percentageR {
    final p = parsedHistoryJson.valueR / totalJsonToParse.valueR;
    return p.isFinite ? p : 0;
  }

  bool _isShowingParsingMenu = false;

  void _hideParsingDialog() => _isShowingParsingMenu = false;

  void showParsingProgressDialog() {
    if (_isShowingParsingMenu) return;
    Widget getTextWidget(String text, {TextStyle? style}) {
      return Text(text, style: style ?? namida.textTheme.displayMedium);
    }

    _isShowingParsingMenu = true;
    final dateText = _currentNewestDate.value != null
        ? "(${_currentOldestDate.value!.millisecondsSinceEpoch.dateFormattedOriginal} → ${_currentNewestDate.value!.millisecondsSinceEpoch.dateFormattedOriginal})"
        : '';

    NamidaNavigator.inst.navigateDialog(
      onDismissing: _hideParsingDialog,
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        titleWidgetInPadding: Obx(
          (context) {
            final title = '${isParsing.valueR ? lang.EXTRACTING_INFO : lang.DONE} ($_parsedProgressPercentageR)';
            return Text(
              "$title ${isParsing.valueR ? '' : ' ✓'}",
              style: namida.textTheme.displayLarge,
            );
          },
        ),
        actions: [
          TextButton(
            child: NamidaButtonText(lang.CONFIRM),
            onPressed: () {
              _hideParsingDialog();
              NamidaNavigator.inst.closeDialog();
            },
          )
        ],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx((context) => getTextWidget('${lang.LOADING_FILE}... ${isLoadingFile.valueR ? '' : lang.DONE}')),
              const SizedBox(height: 10.0),
              Obx((context) => getTextWidget('$_parsedProgressR ${lang.PARSED}')),
              const SizedBox(height: 10.0),
              Obx((context) => getTextWidget('$_addedHistoryJsonR ${lang.ADDED}')),
              const SizedBox(height: 4.0),
              if (dateText != '') ...[
                getTextWidget(dateText, style: namida.textTheme.displaySmall),
                const SizedBox(height: 4.0),
              ],
              const SizedBox(height: 4.0),
              Obx((context) {
                final shouldShow = currentParsingSource.valueR == TrackSource.youtube || currentParsingSource.valueR == TrackSource.youtubeMusic;
                return shouldShow
                    ? getTextWidget('${lang.STATS}: ${_updatingYoutubeStatsDirectoryProgress.valueR}/${_updatingYoutubeStatsDirectoryTotal.valueR}')
                    : const SizedBox();
              }),
            ],
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
          title: lang.CONFIRM,
          bodyText: confirmMessage,
          actions: [
            const CancelButton(),
            const SizedBox(width: 6.0),
            NamidaButton(
              onPressed: () async {
                await onConfirm();
                NamidaNavigator.inst.closeDialog();
              },
              text: lang.CONFIRM,
            )
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
        title: lang.MISSING_ENTRIES,
        trailingWidgets: [
          const SizedBox(width: 4.0),
          Obx(
            (context) => NamidaIconButton(
              horizontalPadding: 4.0,
              icon: Broken.command_square,
              iconSize: 24.0,
              onPressed: () async {
                confirmAddAsDummy(
                  confirmMessage: 'Add ${_latestMissingMap.value.entries.length} as dummy tracks?',
                  onConfirm: () async {
                    final historyDays = <int>[];
                    final missing = _latestMissingMap.value.entries.toList()..sortByReverse((e) => e.value.length);
                    missing.loop((e) {
                      final replacedWithTrack = _latestMissingMapAddedStatus[e.key];
                      if (replacedWithTrack == null) {
                        historyDays.addAll(addTrackToHistoryOnly(e, getDummyTrack(e.key)));
                      }
                    });

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
                  lang.HISTORY_IMPORT_MISSING_ENTRIES_NOTE,
                  style: namida.textTheme.displaySmall,
                ),
              ),
              Expanded(
                child: Obx(
                  (context) {
                    final missing = _latestMissingMap.valueR.entries.toList()..sortByReverse((e) => e.value.length);
                    return NamidaScrollbarWithController(
                      child: (sc) => ListView.separated(
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
    totalJsonToParse.value = 0;
    parsedHistoryJson.value = 0;
    addedHistoryJsonToPlaylist.value = 0;
    _updatingYoutubeStatsDirectoryProgress.value = 0;
    _updatingYoutubeStatsDirectoryTotal.value = 0;
    _currentOldestDate.value = null;
    _currentNewestDate.value = null;
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
  }) async {
    if (files.isEmpty) {
      if (mainDirectory != null) {
        final contents = await mainDirectory.listAllIsolate(recursive: true);
        if (source == TrackSource.youtube || source == TrackSource.youtubeMusic) {
          contents.loop(
            (file) {
              if (file is File && NamidaFileExtensionsWrapper.json.isPathValid(file.path)) {
                final name = file.path.getFilename;
                if (name.contains('watch-history')) files.add(file);
              }
            },
          );
        } else {
          contents.loop(
            (file) {
              if (file is File && NamidaFileExtensionsWrapper.csv.isPathValid(file.path)) {
                // folder shouldnt contain yt playlists/etc csv files tho, otherwise wer cooked
                final name = file.path.getFilename;
                if (name != 'subscriptions.csv') files.add(file);
              }
            },
          );
        }
      }
    }
    if (files.isEmpty) {
      snackyy(message: 'No related files were found in this directory.', isError: true);
      return;
    }

    _resetValues();
    isParsing.value = true;
    isLoadingFile.value = true;
    _currentOldestDate.value = oldestDate;
    _currentNewestDate.value = newestDate;
    showParsingProgressDialog();

    // TODO: warning to backup history

    await Future.delayed(Duration.zero);

    final startTime = DateTime.now();
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      NotificationService.importHistoryNotification(parsedHistoryJson.value, totalJsonToParse.value, startTime);
    });

    final datesAdded = <int>[];
    final datesAddedYoutube = <int>[];
    var allMissingEntries = <_MissingListenEntry, List<int>>{};

    switch (source) {
      case TrackSource.youtube || TrackSource.youtubeMusic:
        currentParsingSource.value = TrackSource.youtube;
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
          allMissingEntries = res.missingEntries;
          datesAdded.addAll(res.historyDays);
          datesAddedYoutube.addAll(res.ytHistoryDays);
        }
        break;

      case TrackSource.lastfm:
        currentParsingSource.value = TrackSource.lastfm;
        final res = await _addLastFmSource(
          files: files,
          matchAll: matchAll,
          oldestDate: oldestDate,
          newestDate: newestDate,
        );
        if (res != null) {
          allMissingEntries = res.missingEntries;
          datesAdded.addAll(res.historyDays);
        }
        break;
      case TrackSource.local:
        break;
    }

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

    _notificationTimer?.cancel();
    NotificationService.doneImportingHistoryNotification(parsedHistoryJson.value, addedHistoryJsonToPlaylist.value);

    _latestMissingMap.value = allMissingEntries;
    _latestMissingMapAddedStatus.clear();
    showMissingEntriesDialog();
  }

  Future<({List<int> historyDays, List<int> ytHistoryDays, Map<_MissingListenEntry, List<int>> missingEntries})?> _parseYTHistoryJsonAndAdd({
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

    final params = {
      'tracks': Indexer.inst.allTracksMappedByPath.values
          .map((e) => {
                'title': e.title,
                'album': e.album,
                'artist': e.originalArtist,
                'path': e.path,
                'filename': e.filename,
                'comment': e.comment,
                'v': e.isVideo,
              })
          .toList(),
      'files': files,
      'isMatchingTypeLink': isMatchingTypeLink,
      'isMatchingTypeTitleAndArtist': isMatchingTypeTitleAndArtist,
      'matchYT': matchYT,
      'matchYTMusic': matchYTMusic,
      'oldestDay': oldestDate?.toDaysSince1970(),
      'newestDay': newestDate?.toDaysSince1970(),
      'matchAll': matchAll,
      'artistsSplitConfig': ArtistsSplitConfig.settings().toMap(),
      'portProgressParsed': portProgressParsed.sendPort,
      'portProgressAdded': portProgressAdded.sendPort,
      'portLoadingProgress': portLoadingProgress.sendPort,
      'localHistory': HistoryController.inst.historyMap.value,
      'ytHistory': YoutubeHistoryController.inst.historyMap.value,
    };

    StreamSubscription? portLoadingProgressSub;
    portLoadingProgressSub = portLoadingProgress.listen((message) {
      totalJsonToParse.value = message as int;
      isLoadingFile.value = false;
      portLoadingProgress.close();
      portLoadingProgressSub?.cancel();
    });
    HistoryController.inst.setIdleStatus(true);
    YoutubeHistoryController.inst.setIdleStatus(true);

    final res = await _parseYTHistoryJsonAndAddIsolate.thready(params);
    portProgressParsed.close();
    portProgressAdded.close();

    if (res != null) {
      final mapOfAffectedIds = res.affectedIds;

      if (mapOfAffectedIds != null) {
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
    }

    await Future.wait([
      HistoryController.inst.setIdleStatus(false),
      YoutubeHistoryController.inst.setIdleStatus(false),
    ]);

    return res == null
        ? null
        : (
            historyDays: res.daysToSaveLocal,
            ytHistoryDays: res.daysToSaveYT,
            missingEntries: res.missingEntries,
          );
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
  static ({
    Map<String, YoutubeVideoHistory>? affectedIds,
    List<int> daysToSaveLocal,
    List<int> daysToSaveYT,
    int addedLocalHistoryCount,
    int addedYTHistoryCount,
    SplayTreeMap<int, List<TrackWithDate>> localHistory,
    SplayTreeMap<int, List<YoutubeID>> ytHistory,
    Map<_MissingListenEntry, List<int>> missingEntries,
  })? _parseYTHistoryJsonAndAddIsolate(Map params) {
    final allTracks = params['tracks'] as List<Map>;
    final files = params['files'] as List<File>;
    final isMatchingTypeLink = params['isMatchingTypeLink'] as bool;
    final isMatchingTypeTitleAndArtist = params['isMatchingTypeTitleAndArtist'] as bool;
    final matchYT = params['matchYT'] as bool;
    final matchYTMusic = params['matchYTMusic'] as bool;
    final oldestDay = params['oldestDay'] as int?;
    final newestDay = params['newestDay'] as int?;
    final matchAll = params['matchAll'] as bool;
    final artistsSplitConfig = ArtistsSplitConfig.fromMap(params['artistsSplitConfig']);

    final localHistory = params['localHistory'] as SplayTreeMap<int, List<TrackWithDate>>;
    final ytHistory = params['ytHistory'] as SplayTreeMap<int, List<YoutubeID>>;

    int addedLocalHistoryCount = 0;
    int addedYTHistoryCount = 0;

    final portProgressParsed = params['portProgressParsed'] as SendPort;
    final portProgressAdded = params['portProgressAdded'] as SendPort;
    final portLoadingProgress = params['portLoadingProgress'] as SendPort;

    Map<String, List<Track>>? tracksIdsMap;
    if (isMatchingTypeLink) {
      tracksIdsMap = <String, List<Track>>{};
      allTracks.loop((trMap) {
        String? videoId = NamidaLinkUtils.extractYoutubeId(trMap['comment'] as String? ?? '');
        videoId ??= NamidaLinkUtils.extractYoutubeId(trMap['filename'] as String? ?? '');
        if (videoId != null && videoId.isNotEmpty) {
          tracksIdsMap!.addForce(videoId, Track.decide(trMap['path'], trMap['v']));
        }
      });
    }

    final jsonResponse = <dynamic>[];
    files.loop(
      (file) {
        try {
          final res = file.readAsJsonSync() as List?;
          if (res != null) jsonResponse.addAll(res);
        } catch (_) {}
      },
    );

    portLoadingProgress.send(jsonResponse.length); // 1
    if (jsonResponse.isEmpty) return null;

    final mapOfAffectedIds = <String, YoutubeVideoHistory>{};
    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    int totalAdded = 0;
    final daysToSaveLocal = <int>[];
    final daysToSaveYT = <int>[];
    final l = jsonResponse.length - 1;
    const chunkSize = 20;
    for (int i = 0; i <= l; i++) {
      totalParsed++;

      try {
        final p = jsonResponse[i];
        final link = utf8.decode((p['titleUrl']).toString().codeUnits);
        final id = link.length >= 11 ? link.substring(link.length - 11) : link;
        final z = List<Map<String, dynamic>>.from((p['subtitles'] ?? []));

        /// matching in real time, each object.
        final yth = YoutubeVideoHistory(
          id: id,
          title: (p['title'] as String).replaceFirst('Watched ', ''),
          channel: z.isNotEmpty ? z.first['name'] : '',
          channelUrl: z.isNotEmpty ? utf8.decode((z.first['url']).toString().codeUnits) : '',
          watches: [
            YTWatch(
              dateMSNull: YoutubeImportController.parseDate(p['time'] ?? '')?.millisecondsSinceEpoch,
              isYTMusic: p['header'] == "YouTube Music",
            )
          ],
        );
        // -- updating affected ids map, used to update youtube stats
        if (mapOfAffectedIds[id] != null) {
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
          onMissingEntries: (e) => e.loop((e) => missingEntries.addForce(e, e.dateMSSE)),
          allTracks: allTracks,
          artistsSplitConfig: artistsSplitConfig,
        );
        totalAdded += tracks.length;
        tracks.loop((item) {
          final day = item.dateAdded.toDaysSince1970();
          final tracks = localHistory[day] ??= [];
          if (!tracks.contains(item)) {
            daysToSaveLocal.add(day);
            tracks.add(item);
            addedLocalHistoryCount++;
          }
        });

        // -- youtube history --
        yth.watches.loop((w) {
          final canAdd = _canSafelyAddToYTHistory(
            watch: w,
            matchYT: matchYT,
            matchYTMusic: matchYTMusic,
            newestDay: newestDay,
            oldestDay: oldestDay,
          );
          if (canAdd) {
            final ytid = YoutubeID(
              id: yth.id,
              watchNull: w,
              playlistID: null,
            );
            final day = ytid.dateAddedMS.toDaysSince1970();
            final videos = ytHistory[day] ??= [];
            if (!videos.contains(ytid)) {
              daysToSaveYT.add(day);
              videos.add(ytid);
              addedYTHistoryCount++;
            }
          }
        });

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
    portProgressParsed.send(totalParsed);
    portProgressAdded.send(totalAdded);

    return (
      affectedIds: mapOfAffectedIds,
      daysToSaveLocal: daysToSaveLocal,
      daysToSaveYT: daysToSaveYT,
      addedLocalHistoryCount: addedLocalHistoryCount,
      addedYTHistoryCount: addedYTHistoryCount,
      localHistory: localHistory,
      ytHistory: ytHistory,
      missingEntries: missingEntries,
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
    required void Function(List<_MissingListenEntry> missingEntries) onMissingEntries,
    required ArtistsSplitConfig artistsSplitConfig,
    required List<Map> allTracks,
  }) {
    Iterable<Track> tracks = <Track>[];

    if (tracksIdsMap != null) {
      final match = tracksIdsMap[vh.id];
      if (match != null && match.isNotEmpty) {
        tracks = matchAll ? match : [match.first];
      }
    }

    if (tracks.isEmpty && matchByTitleAndArtistIfNotFoundInMap) {
      tracks = allTracks.firstWhereOrAllWhere(matchAll, (trMap) {
        final title = trMap['title'] as String;
        final album = trMap['album'] as String;
        final originalArtist = trMap['artist'] as String;
        final artistsList = Indexer.splitArtist(
          title: title,
          originalArtist: originalArtist,
          config: artistsSplitConfig,
        );

        /// matching has to meet 2 conditons:
        /// 1. [json title] contains [track.title]
        /// 2. - [json title] contains [track.artistsList.first]
        ///     or
        ///    - [json channel] contains [track.album]
        ///    (useful for nightcore channels, album has to be the channel name)
        ///     or
        ///    - [json channel] contains [track.artistsList.first]
        return vh.title.cleanUpForComparison.contains(title.cleanUpForComparison) &&
            (vh.title.cleanUpForComparison.contains(artistsList.first.cleanUpForComparison) ||
                vh.channel.cleanUpForComparison.contains(album.cleanUpForComparison) ||
                vh.channel.cleanUpForComparison.contains(artistsList.first.cleanUpForComparison));
      }).map((e) => Track.decide(e['path'] ?? '', e['v']));
    }

    final tracksToAdd = <TrackWithDate>[];
    if (tracks.isNotEmpty) {
      vh.watches.loop((d) {
        final canAdd = _canSafelyAddToYTHistory(
          watch: d,
          matchYT: matchYT,
          matchYTMusic: matchYTMusic,
          newestDay: newestDay,
          oldestDay: oldestDay,
        );
        if (canAdd) {
          tracksToAdd.addAll(
            tracks.map((tr) => TrackWithDate(
                  dateAdded: d.dateMS,
                  track: tr,
                  source: d.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
                )),
          );
        }
      });
    } else {
      onMissingEntries(
        vh.watches
            .map((e) => _MissingListenEntry(
                  youtubeID: vh.id,
                  dateMSSE: e.dateMS,
                  source: e.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
                  artistOrChannel: vh.channel,
                  title: vh.title,
                ))
            .toList(),
      );
    }
    return tracksToAdd;
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  Future<({List<int> historyDays, Map<_MissingListenEntry, List<int>> missingEntries})?> _addLastFmSource({
    required List<File> files,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
  }) async {
    final portProgressParsed = RawReceivePort((message) {
      parsedHistoryJson.value += message as int;
    });
    final portProgressAdded = RawReceivePort((message) {
      addedHistoryJsonToPlaylist.value += message as int;
    });
    final portLoadingProgress = ReceivePort();

    final params = {
      'tracks': Indexer.inst.allTracksMappedByPath.values
          .map((e) => {
                'title': e.title,
                'artist': e.originalArtist,
                'path': e.path,
                'v': e.isVideo,
              })
          .toList(),
      'oldestDay': oldestDate?.toDaysSince1970(),
      'newestDay': newestDate?.toDaysSince1970(),
      'files': files,
      'matchAll': matchAll,
      'artistsSplitConfig': ArtistsSplitConfig.settings().toMap(),
      'portProgressParsed': portProgressParsed.sendPort,
      'portProgressAdded': portProgressAdded.sendPort,
      'portLoadingProgress': portLoadingProgress.sendPort,
      'localHistory': HistoryController.inst.historyMap.value,
    };
    StreamSubscription? portLoadingProgressSub;
    portLoadingProgressSub = portLoadingProgress.listen((message) {
      totalJsonToParse.value = message as int;
      isLoadingFile.value = false;
      portLoadingProgress.close();
      portLoadingProgressSub?.cancel();
    });

    HistoryController.inst.setIdleStatus(true);

    final res = await _addLastFmSourceIsolate.thready(params);

    portProgressParsed.close();
    portProgressAdded.close();

    if (res != null) {
      HistoryController.inst.historyMap.value = res.localHistory;
      if (res.addedHistoryCount > 0) {
        HistoryController.inst.totalHistoryItemsCount.value = res.addedHistoryCount;
        HistoryController.inst.totalHistoryItemsCount.refresh();
      }
    }

    await HistoryController.inst.setIdleStatus(false);

    return res == null
        ? null
        : (
            historyDays: res.daysToSaveLocal,
            missingEntries: res.missingEntries,
          );
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  static ({
    List<int> daysToSaveLocal,
    int addedHistoryCount,
    SplayTreeMap<int, List<TrackWithDate>> localHistory,
    Map<_MissingListenEntry, List<int>> missingEntries,
  })? _addLastFmSourceIsolate(Map params) {
    final allTracks = params['tracks'] as List<Map>;
    final oldestDay = params['oldestDay'] as int?;
    final newestDay = params['newestDay'] as int?;
    final files = params['files'] as List<File>;
    final matchAll = params['matchAll'] as bool;
    final artistsSplitConfig = ArtistsSplitConfig.fromMap(params['artistsSplitConfig']);

    final localHistory = params['localHistory'] as SplayTreeMap<int, List<TrackWithDate>>;

    int addedHistoryCount = 0;

    final portProgressParsed = params['portProgressParsed'] as SendPort;
    final portProgressAdded = params['portProgressAdded'] as SendPort;
    final portLoadingProgress = params['portLoadingProgress'] as SendPort;

    final lines = <dynamic>[];
    files.loop(
      (file) {
        try {
          final res = file.readAsLinesSync();
          lines.addAll(res);
        } catch (_) {}
      },
    );

    portLoadingProgress.send(lines.length);
    if (lines.isEmpty) return null;

    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    int totalAdded = 0;
    final daysToSaveLocal = <int>[];
    const chunkSize = 20;

    // used for cases where date couldnt be parsed, so it uses this one as a reference
    int? lastDate;
    final linesLength = lines.length;
    for (int i = 0; i < linesLength; i++) {
      final line = lines[i];

      totalParsed++;

      /// artist, album, title, (dd MMM yyyy HH:mm);
      try {
        final pieces = line.split(',');

        // success means: date == trueDate && lastDate is updated.
        // failure means: date == lastDate - 30 seconds || date == 0
        // this is used for cases where date couldn't be parsed, so it'll add the track with (date == lastDate - 30 seconds)
        int date = 0;
        try {
          date = DateFormat('dd MMM yyyy HH:mm').parseLoose(pieces.last).millisecondsSinceEpoch;
        } catch (e) {
          if (lastDate != null) {
            date = lastDate - 30000;
          }
        }
        lastDate = date;

        // -- skips if the date is not inside date range specified.
        if (oldestDay != null && newestDay != null) {
          final watchAsDSE = date.toDaysSince1970();
          if (watchAsDSE < oldestDay || watchAsDSE > newestDay) continue;
        }

        /// matching has to meet 2 conditons:
        /// [csv artist] contains [track.artistsList.first]
        /// [csv title] contains [track.title], anything after ( or [ is ignored.
        final tracks = allTracks.firstWhereOrAllWhere(
          matchAll,
          (trMap) {
            final title = trMap['title'] as String;
            final originalArtist = trMap['artist'] as String;
            final artistsList = Indexer.splitArtist(
              title: title,
              originalArtist: originalArtist,
              config: artistsSplitConfig,
            );
            final matchingArtist = artistsList.isNotEmpty && pieces[0].cleanUpForComparison.contains(artistsList.first.cleanUpForComparison);
            final matchingTitle = pieces[2].cleanUpForComparison.contains(title.splitFirst('(').splitFirst('[').cleanUpForComparison);
            return matchingArtist && matchingTitle;
          },
        );
        totalAdded += tracks.length;
        if (tracks.isNotEmpty) {
          for (final trMap in tracks) {
            final twd = TrackWithDate(
              dateAdded: date,
              track: Track.decide(trMap['path'] ?? '', trMap['v']),
              source: TrackSource.lastfm,
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
            dateMSSE: date,
            source: TrackSource.lastfm,
            artistOrChannel: pieces[0],
            title: pieces[2],
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
    // normally the loop automatically adds every [chunkSize] tracks, this one is to ensure adding any tracks left.
    portProgressParsed.send(totalParsed);
    portProgressAdded.send(totalAdded);

    return (
      daysToSaveLocal: daysToSaveLocal,
      addedHistoryCount: addedHistoryCount,
      localHistory: localHistory,
      missingEntries: missingEntries,
    );
  }

  Future<void> _updateYoutubeStatsDirectory({
    required Map<String, YoutubeVideoHistory> affectedIds,
    required void Function(int updatedIdsCount) onProgress,
  }) async {
    final progressPort = RawReceivePort((message) {
      onProgress(message as int);
    });
    await _updateYoutubeStatsDirectoryIsolate.thready({
      "affectedIds": affectedIds,
      "dirPath": AppDirs.YT_STATS,
      "progressPort": progressPort.sendPort,
    });
    progressPort.close();
  }

  static void _updateYoutubeStatsDirectoryIsolate(Map params) {
    final affectedIds = params['affectedIds'] as Map<String, YoutubeVideoHistory>;
    final progressPort = params['progressPort'] as SendPort;
    final dirPath = params['dirPath'] as String;

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

      final file = File('$dirPath$filename.json');
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
          videosMapInStorage[id]!.watches.addAllNoDuplicates(video.watches.map((e) => YTWatch(dateMSNull: e.dateMSNull, isYTMusic: e.isYTMusic)));
        } else {
          // -- video does NOT exist, so the whole video is added with all its watches.
          videosMapInStorage[id] = video;
        }
        updatedIds.add(id);
      }
      file.writeAsJsonSync(videosMapInStorage.values.toList());
      progressPort.send(updatedIds.length);
    }
  }
}

extension _FWORWHERE<E> on List<E> {
  Iterable<E> firstWhereOrAllWhere(bool matchAll, bool Function(E e) test) {
    if (matchAll) {
      return where(test);
    } else {
      final item = firstWhereEff(test);
      if (item != null) {
        return [item];
      } else {
        return [];
      }
    }
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
  bool operator ==(covariant _MissingListenEntry other) {
    if (identical(this, other)) return true;
    return other.dateMSSE == dateMSSE && other.source == source && other.youtubeID == youtubeID && other.title == title && other.artistOrChannel == artistOrChannel;
  }

  @override
  int get hashCode {
    return dateMSSE.hashCode ^ source.hashCode ^ youtubeID.hashCode ^ title.hashCode ^ artistOrChannel.hashCode;
  }
}
