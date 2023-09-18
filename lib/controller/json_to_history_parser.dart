import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

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

  bool get shouldShowMissingEntriesDialog => _latestMissingMap.length != _latestMissingMapAddedStatus.length;
  final _latestMissingMap = <_MissingListenEntry, List<int>>{}.obs;
  final _latestMissingMapAddedStatus = <_MissingListenEntry, Track>{}.obs;

  void showMissingEntriesDialog() {
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
                    return CupertinoScrollbar(
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

    // -- Removing previous source tracks.
    if (isytsource) {
      HistoryController.inst.removeSourcesTracksFromHistory(
        [TrackSource.youtube, TrackSource.youtubeMusic],
        oldestDate: oldestDate,
        newestDate: newestDate,
        andSave: false,
      );
    } else {
      HistoryController.inst.removeSourcesTracksFromHistory(
        [source],
        oldestDate: oldestDate,
        newestDate: newestDate,
        andSave: false,
      );
    }

    await Future.delayed(Duration.zero);
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      NotificationService.inst.importHistoryNotification(parsedHistoryJson.value, totalJsonToParse.value);
    });

    final datesAdded = <int>[];
    final allMissingEntries = <_MissingListenEntry, List<int>>{};
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
        onMissingEntry: (missingEntry) {
          missingEntry.loop((e, index) => allMissingEntries.addForce(e, e.dateMSSE));
        },
      );
      datesAdded.addAll(res);
      // await _addYoutubeSourceFromDirectory(isMatchingTypeLink, matchYT, matchYTMusic);
    }
    if (source == TrackSource.lastfm) {
      currentParsingSource.value = TrackSource.lastfm;
      final res = await _addLastFmSource(
        file: file,
        matchAll: matchAll,
        oldestDate: oldestDate,
        newestDate: newestDate,
        onMissingEntry: (missingEntry) => allMissingEntries.addForce(missingEntry, missingEntry.dateMSSE),
      );
      datesAdded.addAll(res);
    }
    isParsing.value = false;
    HistoryController.inst.sortHistoryTracks(datesAdded);
    await HistoryController.inst.saveHistoryToStorage(datesAdded);
    HistoryController.inst.updateMostPlayedPlaylist();
    _notificationTimer?.cancel();
    NotificationService.inst.doneImportingHistoryNotification(parsedHistoryJson.value, addedHistoryJsonToPlaylist.value);

    _latestMissingMap
      ..clear()
      ..addAll(allMissingEntries);
    _latestMissingMapAddedStatus.clear();
    showMissingEntriesDialog();
  }

  /// Returns a map of {`trackYTID`: `List<Track>`}
  Map<String, List<Track>> _getTrackIDsMap() {
    final map = <String, List<Track>>{};
    allTracksInLibrary.loop((t, index) {
      map.addForce(t.youtubeID, t);
    });
    return map;
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  Future<List<int>> _parseYTHistoryJsonAndAdd({
    required File file,
    required bool isMatchingTypeLink,
    required bool isMatchingTypeTitleAndArtist,
    required bool matchYT,
    required bool matchYTMusic,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required bool matchAll,
    required void Function(List<_MissingListenEntry> missingEntry) onMissingEntry,
  }) async {
    isParsing.value = true;
    await Future.delayed(const Duration(milliseconds: 300));

    Map<String, List<Track>>? tracksIdsMap;
    if (isMatchingTypeLink) tracksIdsMap = _getTrackIDsMap();

    final datesToSave = <int>[];
    final jsonResponse = await file.readAsJson() as List?;

    totalJsonToParse.value = jsonResponse?.length ?? 0;
    isLoadingFile.value = false;
    if (jsonResponse != null) {
      final mapOfAffectedIds = <String, YoutubeVideoHistory>{};
      for (int i = 0; i <= jsonResponse.length - 1; i++) {
        try {
          final p = jsonResponse[i];
          final link = utf8.decode((p['titleUrl']).toString().codeUnits);
          final id = link.length >= 11 ? link.substring(link.length - 11) : link;
          final z = List<Map<String, dynamic>>.from((p['subtitles'] ?? []));

          /// matching in real time, each object.
          await Future.delayed(Duration.zero);
          final yth = YoutubeVideoHistory(
            id: id,
            title: (p['title'] as String).replaceFirst('Watched ', ''),
            channel: z.isNotEmpty ? z.first['name'] : '',
            channelUrl: z.isNotEmpty ? utf8.decode((z.first['url']).toString().codeUnits) : '',
            watches: [
              YTWatch(
                date: DateTime.parse(p['time'] ?? 0).millisecondsSinceEpoch,
                isYTMusic: p['header'] == "YouTube Music",
              )
            ],
          );
          // -- updating affected ids map, used to update youtube stats
          if (mapOfAffectedIds[id] != null) {
            mapOfAffectedIds[id]!.watches.addAllNoDuplicates(yth.watches.map((e) => YTWatch(date: e.date, isYTMusic: e.isYTMusic)));
          } else {
            mapOfAffectedIds[id] = yth;
          }
          // ---------------------------------------------------------
          final addedDates = _matchYTVHToNamidaHistory(
            vh: yth,
            matchYT: matchYT,
            matchYTMusic: matchYTMusic,
            oldestDate: oldestDate,
            newestDate: newestDate,
            matchAll: matchAll,
            tracksIdsMap: tracksIdsMap,
            matchByTitleAndArtistIfNotFoundInMap: isMatchingTypeTitleAndArtist,
            onMissingEntry: onMissingEntry,
          );
          datesToSave.addAll(addedDates);

          parsedHistoryJson.value++;
        } catch (e) {
          printy(e, isError: true);
          continue;
        }
      }
      _updatingYoutubeStatsDirectoryTotal.value = mapOfAffectedIds.length;
      await _updateYoutubeStatsDirectory(
        affectedIds: mapOfAffectedIds,
        onProgress: (updatedIds) {
          _updatingYoutubeStatsDirectoryProgress.value += updatedIds.length;
          printy('updatedIds: ${updatedIds.length}');
        },
      );
    }

    isParsing.value = false;
    return datesToSave;
  }

  /// Returns [daysToSave].
  List<int> _matchYTVHToNamidaHistory({
    required YoutubeVideoHistory vh,
    required bool matchYT,
    required bool matchYTMusic,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required bool matchAll,
    required Map<String, List<Track>>? tracksIdsMap,
    required bool matchByTitleAndArtistIfNotFoundInMap,
    required void Function(List<_MissingListenEntry> missingEntry) onMissingEntry,
  }) {
    final oldestDay = oldestDate?.millisecondsSinceEpoch.toDaysSinceEpoch();
    final newestDay = newestDate?.millisecondsSinceEpoch.toDaysSinceEpoch();

    Iterable<Track> tracks = <Track>[];

    if (tracksIdsMap != null) {
      final match = tracksIdsMap[vh.id] ?? [];
      if (match.isNotEmpty) {
        tracks = matchAll ? match : [match.first];
      }
    }

    if (tracks.isEmpty && matchByTitleAndArtistIfNotFoundInMap) {
      tracks = allTracksInLibrary.firstWhereOrWhere(matchAll, (trPre) {
        final element = trPre.toTrackExt();

        /// matching has to meet 2 conditons:
        /// 1. [json title] contains [track.title]
        /// 2. - [json title] contains [track.artistsList.first]
        ///     or
        ///    - [json channel] contains [track.album]
        ///    (useful for nightcore channels, album has to be the channel name)
        ///     or
        ///    - [json channel] contains [track.artistsList.first]
        return vh.title.cleanUpForComparison.contains(element.title.cleanUpForComparison) &&
            (vh.title.cleanUpForComparison.contains(element.artistsList.first.cleanUpForComparison) ||
                vh.channel.cleanUpForComparison.contains(element.album.cleanUpForComparison) ||
                vh.channel.cleanUpForComparison.contains(element.artistsList.first.cleanUpForComparison));
      });
    }

    final tracksToAdd = <TrackWithDate>[];
    if (tracks.isNotEmpty) {
      for (int i = 0; i < vh.watches.length; i++) {
        final d = vh.watches[i];

        // ---- sussy checks ----

        // -- if the watch day is outside range specified
        if (oldestDay != null && newestDay != null) {
          final watchAsDSE = d.date.toDaysSinceEpoch();
          if (watchAsDSE < oldestDay || watchAsDSE > newestDay) continue;
        }

        // -- if the type is youtube music, but the user dont want ytm.
        if (d.isYTMusic && !matchYTMusic) continue;

        // -- if the type is youtube, but the user dont want yt.
        if (!d.isYTMusic && !matchYT) continue;

        tracksToAdd.addAll(
          tracks.map((tr) => TrackWithDate(
                dateAdded: d.date,
                track: tr,
                source: d.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
              )),
        );

        addedHistoryJsonToPlaylist.value += tracks.length;
      }
    } else {
      onMissingEntry(
        vh.watches
            .map((e) => _MissingListenEntry(
                  dateMSSE: e.date,
                  source: e.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube,
                  artistOrChannel: vh.channel,
                  title: vh.title,
                ))
            .toList(),
      );
    }
    final daysToSave = HistoryController.inst.addTracksToHistoryOnly(tracksToAdd);
    return daysToSave;
  }

  /// Returns [daysToSave] to be used by [sortHistoryTracks] && [saveHistoryToStorage].
  Future<List<int>> _addLastFmSource({
    required File file,
    required bool matchAll,
    required DateTime? oldestDate,
    required DateTime? newestDate,
    required void Function(_MissingListenEntry missingEntry) onMissingEntry,
  }) async {
    final oldestDay = oldestDate?.millisecondsSinceEpoch.toDaysSinceEpoch();
    final newestDay = newestDate?.millisecondsSinceEpoch.toDaysSinceEpoch();

    totalJsonToParse.value = file.readAsLinesSync().length;
    isLoadingFile.value = false;

    final stream = file.openRead();
    final lines = stream.transform(utf8.decoder).transform(const LineSplitter());

    final totalDaysToSave = <int>[];
    final tracksToAdd = <TrackWithDate>[];

    // used for cases where date couldnt be parsed, so it uses this one as a reference
    int? lastDate;
    await for (final line in lines) {
      parsedHistoryJson.value++;

      /// updates history every 10 tracks
      if (tracksToAdd.length == 10) {
        totalDaysToSave.addAll(HistoryController.inst.addTracksToHistoryOnly(tracksToAdd));
        tracksToAdd.clear();
      }

      // pls forgive me
      await Future.delayed(Duration.zero);

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
          final watchAsDSE = date.toDaysSinceEpoch();
          if (watchAsDSE < oldestDay || watchAsDSE > newestDay) continue;
        }

        /// matching has to meet 2 conditons:
        /// [csv artist] contains [track.artistsList.first]
        /// [csv title] contains [track.title], anything after ( or [ is ignored.
        final tracks = allTracksInLibrary.firstWhereOrWhere(
          matchAll,
          (trPre) {
            final track = trPre.toTrackExt();
            final matchingArtist = track.artistsList.isNotEmpty && pieces[0].cleanUpForComparison.contains(track.artistsList.first.cleanUpForComparison);
            final matchingTitle = pieces[2].cleanUpForComparison.contains(track.title.split('(').first.split('[').first.cleanUpForComparison);
            return matchingArtist && matchingTitle;
          },
        );
        if (tracks.isNotEmpty) {
          tracksToAdd.addAll(
            tracks.map((tr) => TrackWithDate(
                  dateAdded: date,
                  track: tr,
                  source: TrackSource.lastfm,
                )),
          );
          addedHistoryJsonToPlaylist.value += tracks.length;
        } else {
          onMissingEntry(
            _MissingListenEntry(
              dateMSSE: date,
              source: TrackSource.lastfm,
              artistOrChannel: pieces[0],
              title: pieces[2],
            ),
          );
        }
      } catch (e) {
        printy(e, isError: true);
        continue;
      }
    }
    // normally the loop automatically adds every 10 tracks, this one is to ensure adding any tracks left.
    totalDaysToSave.addAll(HistoryController.inst.addTracksToHistoryOnly(tracksToAdd));

    return totalDaysToSave;
  }

  Future<void> _updateYoutubeStatsDirectory({required Map<String, YoutubeVideoHistory> affectedIds, required void Function(List<String> updatedIds) onProgress}) async {
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

      final file = File('${AppDirs.YOUTUBE_STATS}$filename.json');
      final res = await file.readAsJson();
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
          videosMapInStorage[id]!.watches.addAllNoDuplicates(video.watches.map((e) => YTWatch(date: e.date, isYTMusic: e.isYTMusic)));
        } else {
          // -- video does NOT exist, so the whole video is added with all its watches.
          videosMapInStorage[id] = video;
        }
        updatedIds.add(id);
      }
      await file.writeAsJson(videosMapInStorage.values.toList());
      onProgress(updatedIds);
    }
  }
}

extension _FWORWHERE<E> on List<E> {
  Iterable<E> firstWhereOrWhere(bool matchAll, bool Function(E e) test) {
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
  final String title;
  final String artistOrChannel;

  const _MissingListenEntry({
    required this.dateMSSE,
    required this.source,
    required this.title,
    required this.artistOrChannel,
  });

  @override
  bool operator ==(other) {
    if (other is _MissingListenEntry) {
      return source == other.source && title == other.title && artistOrChannel == other.artistOrChannel;
    }
    return false;
  }

  @override
  int get hashCode => "$source$title$artistOrChannel".hashCode;
}
