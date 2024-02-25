import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

class JsonToHistoryParser {
  static JsonToHistoryParser get inst => _instance;
  static final JsonToHistoryParser _instance = JsonToHistoryParser._internal();
  JsonToHistoryParser._internal();

  final RxInt parsedHistoryJson = 0.obs;
  final RxInt totalJsonToParse = 0.obs;
  final RxInt addedHistoryJsonToPlaylist = 0.obs;
  final RxBool isParsing = false.obs;
  final RxBool isLoadingFile = false.obs;
  final RxInt _updatingYoutubeStatsDirectoryProgress = 0.obs;
  final RxInt _updatingYoutubeStatsDirectoryTotal = 0.obs;
  final Rx<TrackSource> currentParsingSource = TrackSource.local.obs;
  final _currentOldestDate = Rxn<DateTime>();
  final _currentNewestDate = Rxn<DateTime>();

  String get parsedProgress => '${parsedHistoryJson.value.formatDecimal()} / ${totalJsonToParse.value.formatDecimal()}';
  String get parsedProgressPercentage => '${(_percentage * 100).round()}%';
  String get addedHistoryJson => addedHistoryJsonToPlaylist.value.formatDecimal();
  double get _percentage {
    final p = parsedHistoryJson.value / totalJsonToParse.value;
    return p.isFinite ? p : 0;
  }

  bool _isShowingParsingMenu = false;

  void _hideParsingDialog() => _isShowingParsingMenu = false;

  void showParsingProgressDialog() {
    if (_isShowingParsingMenu) return;
    Widget getTextWidget(String text, {TextStyle? style}) {
      return Text(text, style: style ?? Get.textTheme.displayMedium);
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
          () {
            final title = '${isParsing.value ? lang.EXTRACTING_INFO : lang.DONE} ($parsedProgressPercentage)';
            return Text(
              "$title ${isParsing.value ? '' : ' ✓'}",
              style: Get.textTheme.displayLarge,
            );
          },
        ),
        actions: [
          TextButton(
            child: Text(lang.CONFIRM),
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
              Obx(() => getTextWidget('${lang.LOADING_FILE}... ${isLoadingFile.value ? '' : lang.DONE}')),
              const SizedBox(height: 10.0),
              Obx(() => getTextWidget('$parsedProgress ${lang.PARSED}')),
              const SizedBox(height: 10.0),
              Obx(() => getTextWidget('$addedHistoryJson ${lang.ADDED}')),
              const SizedBox(height: 4.0),
              if (dateText != '') ...[
                getTextWidget(dateText, style: Get.textTheme.displaySmall),
                const SizedBox(height: 4.0),
              ],
              const SizedBox(height: 4.0),
              Obx(() {
                final shouldShow = currentParsingSource.value == TrackSource.youtube || currentParsingSource.value == TrackSource.youtubeMusic;
                return shouldShow ? getTextWidget('${lang.STATS}: ${_updatingYoutubeStatsDirectoryProgress.value}/${_updatingYoutubeStatsDirectoryTotal.value}') : const SizedBox();
              }),
            ],
          ),
        ),
      ),
    );
  }

  bool get shouldShowMissingEntriesDialog => _latestMissingMap.isNotEmpty && _latestMissingMap.length != _latestMissingMapAddedStatus.length;
  final _latestMissingMap = <_MissingListenEntry, List<int>>{}.obs;
  final _latestMissingMapAddedStatus = <_MissingListenEntry, Track>{}.obs;

  void showMissingEntriesDialog() {
    if (_latestMissingMap.isEmpty) return;

    void onTrackChoose(MapEntry<_MissingListenEntry, List<int>> entry) {
      showLibraryTracksChooseDialog(
        trackName: "${entry.key.artistOrChannel} - ${entry.key.title}",
        onChoose: (choosenTrack) async {
          final twds = entry.value.map(
            (e) => TrackWithDate(
              dateAdded: e,
              track: choosenTrack,
              source: entry.key.source,
            ),
          );
          await HistoryController.inst.addTracksToHistory(twds.toList());
          NamidaNavigator.inst.closeDialog();
          _latestMissingMapAddedStatus[entry.key] = choosenTrack;
        },
      );
    }

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.MISSING_ENTRIES,
        child: SizedBox(
          width: Get.width,
          height: Get.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  lang.HISTORY_IMPORT_MISSING_ENTRIES_NOTE,
                  style: Get.textTheme.displaySmall,
                ),
              ),
              Expanded(
                child: Obx(
                  () {
                    final missing = _latestMissingMap.entries.toList()..sortByReverse((e) => e.value.length);
                    return NamidaScrollbar(
                      child: ListView.separated(
                        separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                        itemCount: missing.length,
                        itemBuilder: (context, index) {
                          final entry = missing[index];
                          return Obx(
                            () {
                              final replacedWithTrack = _latestMissingMapAddedStatus[entry.key];
                              return IgnorePointer(
                                ignoring: replacedWithTrack != null,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: replacedWithTrack != null ? 0.6 : 1.0,
                                  child: NamidaInkWell(
                                    onTap: () => onTrackChoose(entry),
                                    bgColor: Get.theme.cardTheme.color,
                                    borderRadius: 12.0,
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        NamidaInkWell(
                                          bgColor: Get.theme.cardTheme.color,
                                          borderRadius: 42.0,
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                          child: Text(
                                            entry.value.length.formatDecimal(),
                                            style: Get.textTheme.displaySmall,
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
                                                style: Get.textTheme.displayMedium,
                                              ),
                                              Text(
                                                "${entry.key.artistOrChannel} - ${entry.key.source.convertToString}",
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.ellipsis,
                                                style: Get.textTheme.displaySmall,
                                              ),
                                              if (replacedWithTrack != null)
                                                Text(
                                                  "→ ${replacedWithTrack.originalArtist} - ${replacedWithTrack.title}",
                                                  maxLines: 2,
                                                  softWrap: false,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Get.textTheme.displaySmall?.copyWith(fontSize: 11.5.multipliedFontScale),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        NamidaIconButton(
                                          icon: Broken.repeat_circle,
                                          iconSize: 24.0,
                                          onPressed: () => onTrackChoose(entry),
                                        ),
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

  Future<void> addFileSourceToNamidaHistory({
    required File file,
    required TrackSource source,
    bool matchAll = false,
    bool ytIsMatchingTypeLink = true,
    bool isMatchingTypeTitleAndArtist = false,
    bool ytMatchYT = true,
    bool ytMatchYTMusic = true,
    DateTime? oldestDate,
    DateTime? newestDate,
  }) async {
    _resetValues();
    isParsing.value = true;
    isLoadingFile.value = true;
    _currentOldestDate.value = oldestDate;
    _currentNewestDate.value = newestDate;
    showParsingProgressDialog();

    // TODO: warning to backup history

    final isytsource = source == TrackSource.youtube || source == TrackSource.youtubeMusic;

    await Future.delayed(Duration.zero);

    final startTime = DateTime.now();
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      NotificationService.inst.importHistoryNotification(parsedHistoryJson.value, totalJsonToParse.value, startTime);
    });

    final datesAdded = <int>[];
    final datesAddedYoutube = <int>[];
    var allMissingEntries = <_MissingListenEntry, List<int>>{};
    if (isytsource) {
      currentParsingSource.value = TrackSource.youtube;
      final res = await _parseYTHistoryJsonAndAdd(
        file: file,
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
      // await _addYoutubeSourceFromDirectory(isMatchingTypeLink, matchYT, matchYTMusic);
    }
    if (source == TrackSource.lastfm) {
      currentParsingSource.value = TrackSource.lastfm;
      final res = await _addLastFmSource(
        file: file,
        matchAll: matchAll,
        oldestDate: oldestDate,
        newestDate: newestDate,
      );
      if (res != null) {
        allMissingEntries = res.missingEntries;
        datesAdded.addAll(res.historyDays);
      }
    }

    // -- local history --
    HistoryController.inst.removeDuplicatedItems(datesAdded);
    HistoryController.inst.sortHistoryTracks(datesAdded);
    await HistoryController.inst.saveHistoryToStorage(datesAdded);
    HistoryController.inst.updateMostPlayedPlaylist();

    // -- youtube history --
    YoutubeHistoryController.inst.removeDuplicatedItems(datesAddedYoutube);
    YoutubeHistoryController.inst.sortHistoryTracks(datesAddedYoutube);
    await YoutubeHistoryController.inst.saveHistoryToStorage(datesAddedYoutube);
    YoutubeHistoryController.inst.updateMostPlayedPlaylist();

    isParsing.value = false;

    _notificationTimer?.cancel();
    NotificationService.inst.doneImportingHistoryNotification(parsedHistoryJson.value, addedHistoryJsonToPlaylist.value);

    _latestMissingMap.value = allMissingEntries;
    _latestMissingMapAddedStatus.clear();
    showMissingEntriesDialog();
  }

  Future<({List<int> historyDays, List<int> ytHistoryDays, Map<_MissingListenEntry, List<int>> missingEntries})?> _parseYTHistoryJsonAndAdd({
    required File file,
    required bool isMatchingTypeLink,
    required bool isMatchingTypeTitleAndArtist,
    required bool matchYT,
    required bool matchYTMusic,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required bool matchAll,
  }) async {
    final portProgressParsed = ReceivePort();
    final portProgressAdded = ReceivePort();
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
              })
          .toList(),
      'file': file,
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
    final StreamSubscription portProgressParsedSub;
    portProgressParsedSub = portProgressParsed.listen((message) {
      parsedHistoryJson.value += message as int;
    });
    final StreamSubscription portProgressAddedSub;
    portProgressAddedSub = portProgressAdded.listen((message) {
      addedHistoryJsonToPlaylist.value += message as int;
    });
    HistoryController.inst.setIdleStatus(true);
    YoutubeHistoryController.inst.setIdleStatus(true);

    final res = await _parseYTHistoryJsonAndAddIsolate.thready(params);
    portProgressParsed.close();
    portProgressAdded.close();
    portProgressParsedSub.cancel();
    portProgressAddedSub.cancel();

    if (res != null) {
      final mapOfAffectedIds = res.affectedIds;

      if (mapOfAffectedIds != null) {
        _updatingYoutubeStatsDirectoryTotal.value = mapOfAffectedIds.length;
        await _updateYoutubeStatsDirectory(
          affectedIds: mapOfAffectedIds,
          onProgress: (updatedIds) {
            _updatingYoutubeStatsDirectoryProgress.value += updatedIds.length;
            printy('updatedIds: ${updatedIds.length}');
          },
        );
        YoutubeController.inst.fillBackupInfoMap();
      }

      HistoryController.inst.historyMap.value = res.localHistory;
      YoutubeHistoryController.inst.historyMap.value = res.ytHistory;
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

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  ///
  /// The first one is for normal history, the second is for youtube history.
  static ({
    Map<String, YoutubeVideoHistory>? affectedIds,
    List<int> daysToSaveLocal,
    List<int> daysToSaveYT,
    SplayTreeMap<int, List<TrackWithDate>> localHistory,
    SplayTreeMap<int, List<YoutubeID>> ytHistory,
    Map<_MissingListenEntry, List<int>> missingEntries,
  })? _parseYTHistoryJsonAndAddIsolate(Map params) {
    final allTracks = params['tracks'] as List<Map>;
    final file = params['file'] as File;
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

    final portProgressParsed = params['portProgressParsed'] as SendPort;
    final portProgressAdded = params['portProgressAdded'] as SendPort;
    final portLoadingProgress = params['portLoadingProgress'] as SendPort;

    Map<String, List<Track>>? tracksIdsMap;
    if (isMatchingTypeLink) {
      tracksIdsMap = <String, List<Track>>{};
      allTracks.loop((trMap, index) {
        final comment = trMap['comment'] as String;
        final filename = trMap['filename'] as String;
        String? link = comment.isEmpty ? null : NamidaLinkRegex.youtubeLinkRegex.firstMatch(comment)?[0];
        link ??= filename.isEmpty ? null : NamidaLinkRegex.youtubeLinkRegex.firstMatch(filename)?[0];
        if (link != null) {
          final videoId = link.getYoutubeID;
          if (videoId != '') tracksIdsMap!.addForce(videoId, Track(trMap['path']));
        }
      });
    }

    final jsonResponse = file.readAsJsonSync() as List?;

    portLoadingProgress.send(jsonResponse?.length ?? 0); // 1
    if (jsonResponse == null) return null;

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
              dateNull: DateTime.parse(p['time'] ?? 0),
              isYTMusic: p['header'] == "YouTube Music",
            )
          ],
        );
        // -- updating affected ids map, used to update youtube stats
        if (mapOfAffectedIds[id] != null) {
          mapOfAffectedIds[id]!.watches.addAllNoDuplicates(yth.watches.map((e) => YTWatch(dateNull: e.date, isYTMusic: e.isYTMusic)));
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
          onMissingEntries: (e) => e.loop((e, index) => missingEntries.addForce(e, e.dateMSSE)),
          allTracks: allTracks,
          artistsSplitConfig: artistsSplitConfig,
        );
        totalAdded += tracks.length;
        tracks.loop((item, _) {
          final day = item.dateTimeAdded.toDaysSince1970();
          daysToSaveLocal.add(day);
          localHistory.insertForce(0, day, item);
        });

        // -- youtube history --
        yth.watches.loop((w, index) {
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
            final day = ytid.dateTimeAdded.toDaysSince1970();
            daysToSaveYT.add(day);
            ytHistory.insertForce(0, day, ytid);
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
      final watchAsDSE = watch.date.toDaysSince1970();
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
      final match = tracksIdsMap[vh.id] ?? [];
      if (match.isNotEmpty) {
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
      }).map((e) => Track(e['path'] ?? ''));
    }

    final tracksToAdd = <TrackWithDate>[];
    if (tracks.isNotEmpty) {
      vh.watches.loop((d, index) {
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
                  dateAdded: d.date.millisecondsSinceEpoch,
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
                  dateMSSE: e.date.millisecondsSinceEpoch,
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
    required File file,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
  }) async {
    final portProgressParsed = ReceivePort();
    final portProgressAdded = ReceivePort();
    final portLoadingProgress = ReceivePort();

    final params = {
      'tracks': Indexer.inst.allTracksMappedByPath.values
          .map((e) => {
                'title': e.title,
                'artist': e.originalArtist,
                'path': e.path,
              })
          .toList(),
      'oldestDay': oldestDate?.toDaysSince1970(),
      'newestDay': newestDate?.toDaysSince1970(),
      'file': file,
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
    final StreamSubscription portProgressParsedSub;
    portProgressParsedSub = portProgressParsed.listen((message) {
      parsedHistoryJson.value += message as int;
    });
    final StreamSubscription portProgressAddedSub;
    portProgressAddedSub = portProgressAdded.listen((message) {
      addedHistoryJsonToPlaylist.value += message as int;
    });

    HistoryController.inst.setIdleStatus(true);

    final res = await _addLastFmSourceIsolate.thready(params);

    portProgressParsed.close();
    portProgressAdded.close();
    portProgressParsedSub.cancel();
    portProgressAddedSub.cancel();

    if (res != null) {
      HistoryController.inst.historyMap.value = res.localHistory;
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
    SplayTreeMap<int, List<TrackWithDate>> localHistory,
    Map<_MissingListenEntry, List<int>> missingEntries,
  })? _addLastFmSourceIsolate(Map params) {
    final allTracks = params['tracks'] as List<Map>;
    final oldestDay = params['oldestDay'] as int?;
    final newestDay = params['newestDay'] as int?;
    final file = params['file'] as File;
    final matchAll = params['matchAll'] as bool;
    final artistsSplitConfig = ArtistsSplitConfig.fromMap(params['artistsSplitConfig']);

    final localHistory = params['localHistory'] as SplayTreeMap<int, List<TrackWithDate>>;

    final portProgressParsed = params['portProgressParsed'] as SendPort;
    final portProgressAdded = params['portProgressAdded'] as SendPort;
    final portLoadingProgress = params['portLoadingProgress'] as SendPort;

    final List<String> lines;
    try {
      lines = file.readAsLinesSync();
      portLoadingProgress.send(lines.length);
    } catch (e) {
      portLoadingProgress.send(0);
      return null;
    }

    final missingEntries = <_MissingListenEntry, List<int>>{};
    int totalParsed = 0;
    int totalAdded = 0;
    final daysToSaveLocal = <int>[];
    const chunkSize = 20;

    // used for cases where date couldnt be parsed, so it uses this one as a reference
    int? lastDate;
    for (final line in lines) {
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
            final matchingTitle = pieces[2].cleanUpForComparison.contains(title.split('(').first.split('[').first.cleanUpForComparison);
            return matchingArtist && matchingTitle;
          },
        );
        totalAdded += tracks.length;
        if (tracks.isNotEmpty) {
          for (final trMap in tracks) {
            final tr = TrackWithDate(
              dateAdded: date,
              track: Track(trMap['path'] ?? ''),
              source: TrackSource.lastfm,
            );
            final day = tr.dateTimeAdded.toDaysSince1970();
            daysToSaveLocal.add(day);
            localHistory.insertForce(0, day, tr);
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
      localHistory: localHistory,
      missingEntries: missingEntries,
    );
  }

  Future<void> _updateYoutubeStatsDirectory({
    required Map<String, YoutubeVideoHistory> affectedIds,
    required void Function(List<String> updatedIds) onProgress,
  }) async {
    final progressPort = ReceivePort();

    final StreamSubscription streamSub;
    streamSub = progressPort.listen((message) {
      onProgress(message as List<String>);
    });
    await _updateYoutubeStatsDirectoryIsolate.thready({
      "affectedIds": affectedIds,
      "dirPath": AppDirs.YT_STATS,
      "progressPort": progressPort.sendPort,
    });
    progressPort.close();
    streamSub.cancel();
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
          videosMapInStorage[id]!.watches.addAllNoDuplicates(video.watches.map((e) => YTWatch(dateNull: e.date, isYTMusic: e.isYTMusic)));
        } else {
          // -- video does NOT exist, so the whole video is added with all its watches.
          videosMapInStorage[id] = video;
        }
        updatedIds.add(id);
      }
      file.writeAsJsonSync(videosMapInStorage.values.toList());
      progressPort.send(updatedIds);
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
  bool operator ==(other) {
    if (other is _MissingListenEntry) {
      return youtubeID == other.youtubeID && source == other.source && title == other.title && artistOrChannel == other.artistOrChannel;
    }
    return false;
  }

  @override
  int get hashCode => "$youtubeID$source$title$artistOrChannel".hashCode;
}
