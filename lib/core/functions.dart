import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaOnTaps {
  static NamidaOnTaps get inst => _instance;
  static final NamidaOnTaps _instance = NamidaOnTaps._internal();
  NamidaOnTaps._internal();

  Future<void> onArtistTap(String name, [List<Track>? tracksPre]) async {
    final tracks = tracksPre ?? name.getArtistTracks();

    final albumIds = name.getArtistAlbums();

    NamidaNavigator.inst.navigateTo(
      ArtistTracksPage(
        name: name,
        tracks: tracks,
        albumIdentifiers: albumIds,
      ),
    );
  }

  Future<void> onAlbumTap(String albumIdentifier) async {
    final tracks = albumIdentifier.getAlbumTracks();

    NamidaNavigator.inst.navigateTo(
      AlbumTracksPage(
        albumIdentifier: albumIdentifier,
        tracks: tracks,
      ),
    );
  }

  Future<void> onGenreTap(String name) async {
    NamidaNavigator.inst.navigateTo(
      GenreTracksPage(
        name: name,
        tracks: name.getGenresTracks(),
      ),
    );
  }

  Future<void> onNormalPlaylistTap(
    String playlistName, {
    bool disableAnimation = false,
  }) async {
    NamidaNavigator.inst.navigateTo(
      NormalPlaylistTracksPage(
        playlistName: playlistName,
        disableAnimation: disableAnimation,
      ),
    );
  }

  Future<void> onHistoryPlaylistTap({
    double initialScrollOffset = 0,
    int? indexToHighlight,
    int? dayOfHighLight,
  }) async {
    HistoryController.inst.indexToHighlight.value = indexToHighlight;
    HistoryController.inst.dayOfHighLight.value = dayOfHighLight;

    void jump() => HistoryController.inst.scrollController.jumpTo(initialScrollOffset);

    if (NamidaNavigator.inst.currentRoute?.route == RouteType.SUBPAGE_historyTracks) {
      NamidaNavigator.inst.closeAllDialogs();
      MiniPlayerController.inst.snapToMini();
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        jump();
      });
      await NamidaNavigator.inst.navigateTo(
        const HistoryTracksPage(),
      );
    }
  }

  Future<void> onMostPlayedPlaylistTap() async {
    NamidaNavigator.inst.navigateTo(const MostPlayedTracksPage());
  }

  Future<void> onFolderTap(Folder folder, {Track? trackToScrollTo}) async {
    ScrollSearchController.inst.animatePageController(LibraryTab.folders);
    Folders.inst.stepIn(folder, trackToScrollTo: trackToScrollTo);
  }

  Future<void> onQueueTap(Queue queue) async {
    NamidaNavigator.inst.navigateTo(
      QueueTracksPage(queue: queue),
    );
  }

  Future<void> onRemoveTracksFromPlaylist(String name, List<TrackWithDate> tracksWithDates) async {
    void showSnacky({required void Function() whatDoYouWant}) {
      snackyy(
        title: lang.UNDO_CHANGES,
        message: lang.UNDO_CHANGES_DELETED_TRACK,
        displaySeconds: 3,
        button: TextButton(
          onPressed: () {
            Get.closeCurrentSnackbar();
            whatDoYouWant();
          },
          child: Text(lang.UNDO),
        ),
      );
    }

    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;

    if (isHistory) {
      final tempList = List<TrackWithDate>.from(tracksWithDates);
      await HistoryController.inst.removeTracksFromHistory(tracksWithDates);
      showSnacky(
        whatDoYouWant: () async {
          await HistoryController.inst.addTracksToHistory(tempList);
          HistoryController.inst.sortHistoryTracks(tempList.mapped((e) => e.dateAdded.toDaysSince1970()));
        },
      );
    } else {
      final playlist = PlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;

      final Map<TrackWithDate, int> twdAndIndexes = {};
      tracksWithDates.loop((twd, index) {
        twdAndIndexes[twd] = playlist.tracks.indexOf(twd);
      });

      await PlaylistController.inst.removeTracksFromPlaylist(playlist, twdAndIndexes.values.toList());
      showSnacky(
        whatDoYouWant: () async {
          PlaylistController.inst.insertTracksInPlaylistWithEachIndex(
            playlist,
            twdAndIndexes,
          );
        },
      );
    }
  }
}

Future<void> showCalendarDialog({
  required String title,
  required String buttonText,
  CalendarDatePicker2Type calendarType = CalendarDatePicker2Type.range,
  DateTime? firstDate,
  DateTime? lastDate,
  required bool useHistoryDates,
  void Function(List<DateTime> dates)? onChanged,
  required void Function(List<DateTime> dates) onGenerate,
}) async {
  final dates = <DateTime>[];

  final RxInt daysNumber = 0.obs;
  final RxBool canGenerate = false.obs;

  void calculateDaysNumber() {
    if (canGenerate.value) {
      if (dates.length == 2) {
        daysNumber.value = dates[0].difference(dates[1]).inDays.abs() + 1;
      }
    } else {
      daysNumber.value = 0;
    }
  }

  void reEvaluateCanGenerate() {
    switch (calendarType) {
      case CalendarDatePicker2Type.range:
        canGenerate.value = dates.length == 2;
      case CalendarDatePicker2Type.single:
        canGenerate.value = dates.length == 1;
      case CalendarDatePicker2Type.multi:
        canGenerate.value = true;
      default:
        null;
    }
  }

  await NamidaNavigator.inst.navigateDialog(
    scale: 0.90,
    dialog: CustomBlurryDialog(
      titleWidgetInPadding: Obx(
        () => Text(
          '$title ${daysNumber.value == 0 ? '' : "(${daysNumber.value.displayDayKeyword})"}',
          style: Get.textTheme.displayLarge,
        ),
      ),
      normalTitleStyle: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28.0),
      actions: [
        const CancelButton(),
        Obx(
          () => NamidaButton(
            enabled: canGenerate.value,
            onPressed: () => onGenerate(dates),
            text: buttonText,
          ),
        ),
      ],
      child: CalendarDatePicker2(
        onValueChanged: (value) {
          final dts = value.whereType<DateTime>().toList();
          dates
            ..clear()
            ..addAll(dts);

          if (onChanged != null) onChanged(dts);

          reEvaluateCanGenerate();
          calculateDaysNumber();
        },
        config: CalendarDatePicker2Config(
          calendarType: calendarType,
          firstDate: useHistoryDates ? HistoryController.inst.oldestTrack?.dateAdded.milliSecondsSinceEpoch : firstDate,
          lastDate: useHistoryDates ? HistoryController.inst.newestTrack?.dateAdded.milliSecondsSinceEpoch : lastDate,
        ),
        value: const [],
      ),
    ),
  );
}

// Returns a [0-1] scale representing how much similar both are.
double checkIfListsSimilar<E>(List<E> q1, List<E> q2, {bool fullyFunctional = false}) {
  if (fullyFunctional) {
    if (q1.isEmpty && q2.isEmpty) {
      return 1.0;
    }
    final finallength = q1.length > q2.length ? q2.length : q1.length;
    int trueconditions = 0;
    for (int i = 0; i < finallength; i++) {
      if (q1[i] == q2[i]) trueconditions++;
    }
    return trueconditions / finallength;
  } else {
    return q1.isEqualTo(q2) ? 1.0 : 0.0;
  }
}

bool checkIfQueueSameAsCurrent(List<Selectable> queue) {
  return checkIfListsSimilar(queue, Player.inst.currentQueue) == 1.0;
}

bool checkIfQueueSameAsAllTracks(List<Selectable> queue) {
  return checkIfListsSimilar(queue, allTracksInLibrary) == 1.0;
}
