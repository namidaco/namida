import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/playlist.dart';
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
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
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

    final albums = name.getArtistAlbums();

    NamidaNavigator.inst.navigateTo(
      ArtistTracksPage(
        name: name,
        tracks: tracks,
        albums: albums,
      ),
    );
    Dimensions.inst.updateDimensions(LibraryTab.albums, gridOverride: Dimensions.albumInsideArtistGridCount);
  }

  Future<void> onAlbumTap(String album) async {
    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    final tracks = album.getAlbumTracks();

    NamidaNavigator.inst.navigateTo(
      AlbumTracksPage(
        name: album,
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
    Folders.inst.stepIn(folder, trackToScrollTo: trackToScrollTo);
  }

  Future<void> onQueueTap(Queue queue) async {
    NamidaNavigator.inst.navigateTo(
      QueueTracksPage(queue: queue),
    );
  }

  void onRemoveTrackFromPlaylist(String name, int index, TrackWithDate trackWithDate) {
    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;
    Playlist? playlist;
    if (isHistory) {
      final day = trackWithDate.dateAdded.toDaysSinceEpoch();
      HistoryController.inst.removeFromHistory(day, index);
    } else {
      playlist = PlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;
      trackWithDate = playlist.tracks.elementAt(index);
      PlaylistController.inst.removeTrackFromPlaylist(playlist, index);
    }

    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_TRACK,
      mainButton: TextButton(
        onPressed: () {
          if (isHistory) {
            HistoryController.inst.addTracksToHistory([trackWithDate]);
            HistoryController.inst.sortHistoryTracks([trackWithDate.dateAdded.toDaysSinceEpoch()]);
          } else {
            PlaylistController.inst.insertTracksInPlaylist(
              playlist!,
              [trackWithDate],
              index,
            );
          }

          Get.closeAllSnackbars();
        },
        child: Text(Language.inst.UNDO),
      ),
    );
  }
}

Future<void> showCalendarDialog({
  required String title,
  required String buttonText,
  CalendarDatePicker2Type calendarType = CalendarDatePicker2Type.range,
  DateTime? firstDate,
  DateTime? lastDate,
  void Function(List<DateTime> dates)? onChanged,
  required void Function(List<DateTime> dates) onGenerate,
}) async {
  final dates = <DateTime>[];

  final RxInt daysNumber = 0.obs;
  void calculateDaysNumber() {
    if (calendarType == CalendarDatePicker2Type.range) {
      if (dates.length == 2) {
        daysNumber.value = dates[0].difference(dates[1]).inDays.abs();
      } else {
        daysNumber.value = 0;
      }
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
        ElevatedButton(
          onPressed: () => onGenerate(dates),
          child: Text(buttonText),
        ),
      ],
      child: CalendarDatePicker2(
        onValueChanged: (value) {
          final dts = value.whereType<DateTime>().toList();
          dates
            ..clear()
            ..addAll(dts);

          if (onChanged != null) onChanged(dts);

          calculateDaysNumber();
        },
        config: CalendarDatePicker2Config(
          calendarType: calendarType,
          firstDate: firstDate,
          lastDate: lastDate,
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

bool checkIfQueueSameAsCurrent(List<Track> queue) {
  return checkIfListsSimilar(queue, Player.inst.currentQueue) == 1.0;
}

bool checkIfQueueSameAsAllTracks(List<Track> queue) {
  return checkIfListsSimilar(queue, allTracksInLibrary) == 1.0;
}
