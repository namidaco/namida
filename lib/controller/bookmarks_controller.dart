// by claude
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/bookmarks_sheet.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class BookmarksController {
  static final inst = BookmarksController._();

  BookmarksController._();

  void initialize() {
    Player.inst.currentItem.addListener(_refreshCurrent);
    Indexer.inst.trackStatsMap.addListener(_onTrackStatsChanged);
    _refreshCurrent();
  }

  static const _kNearbyRangeMS = 1000;
  static const _kSeekbarReachPx = 12.0;

  RxBaseCore<List<PlayableBookmark>> get currentBookmarks => _currentBookmarks;
  final _currentBookmarks = const <PlayableBookmark>[].obs;

  void _refreshCurrent() async {
    final item = Player.inst.currentItem.value;
    final bookmarks = item == null ? null : await getBookmarks(item);
    if (!identical(item, Player.inst.currentItem.value)) return;
    _setCurrent(bookmarks ?? const []);
  }

  void _setCurrent(List<PlayableBookmark> bookmarks) {
    _currentBookmarks.value = bookmarks;
    final item = Player.inst.currentItem.value;
    if (item == null) return;
    final startMS = PlayableBookmark.findRolePositionMS(bookmarks, PlayableBookmarkRole.start);
    final endMS = PlayableBookmark.findRolePositionMS(bookmarks, PlayableBookmarkRole.end);
    Player.inst.setItemPlaybackRange(item, startMS: startMS, endMS: endMS);
  }

  void _onTrackStatsChanged() {
    if (Player.inst.currentItem.value is Selectable) _refreshCurrent();
  }

  FutureOr<List<PlayableBookmark>?> getBookmarks(Playable item) {
    return item.executeAsync(
      selectable: (finalItem) => finalItem.track.statsRaw?.bookmarks,
      youtubeID: (finalItem) async {
        final stats = await YoutubeController.inst.statsManager.getStats(finalItem);
        return stats?.bookmarks;
      },
    );
  }

  Future<void> addAtCurrentPosition() => _addToCurrentItem(Player.inst.nowPlayingPosition.value);

  /// releasing on a tick opens the bookmarks, near the playhead bookmarks the exact playing position.
  void onSeekbarLongPress(int pressedMS, int durationMS, double widthPx) {
    final item = Player.inst.currentItem.value;
    if (item == null || durationMS <= 0 || widthPx <= 0) return;
    final pressedBookmarkMS = _findBookmarkNearMS(pressedMS, durationMS, widthPx);
    if (pressedBookmarkMS != null) {
      showBookmarksSheet(item);
      return;
    }
    final playingMS = Player.inst.nowPlayingPosition.value;
    final isOnPlayhead = (pressedMS - playingMS).abs() <= _seekbarReachMS(durationMS, widthPx);
    final positionMS = isOnPlayhead ? playingMS : pressedMS;
    _addToCurrentItem(positionMS);
  }

  Future<void> _addToCurrentItem(int positionMS) async {
    if (positionMS < _kNearbyRangeMS) return;
    final item = Player.inst.currentItem.value;
    if (item == null) return;
    final positionLabel = positionMS.milliSecondsLabel;
    final bookmark = PlayableBookmark(positionMS: positionMS, title: null, role: null);
    final newBookmarks = await _edit(item, (bookmarks) {
      final alreadyExists = bookmarks.any((e) => (e.positionMS - positionMS).abs() < _kNearbyRangeMS);
      if (alreadyExists) return null;
      return [...bookmarks, bookmark]..sortBy((e) => e.positionMS);
    });
    if (newBookmarks == null) {
      snackyy(icon: Broken.book_saved, message: '${lang.bookmarks}: ${lang.alreadyExists} ($positionLabel)');
      return;
    }
    VibratorController.medium();
    snackyy(
      icon: Broken.book_saved,
      message: '${lang.bookmarks}: ${lang.added} ($positionLabel)',
      button: SnackbarButton(
        text: lang.undo,
        function: () => remove(item, bookmark),
      ),
    );
  }

  Future<List<PlayableBookmark>?> remove(Playable item, PlayableBookmark bookmark) {
    return _edit(item, (bookmarks) => bookmarks.where((e) => e.positionMS != bookmark.positionMS).toFixedList());
  }

  Future<List<PlayableBookmark>?> rename(Playable item, PlayableBookmark bookmark, String title) {
    final newTitle = title.trim().nullifyEmpty();
    return _edit(item, (bookmarks) {
      return bookmarks.map((e) {
        if (e.positionMS != bookmark.positionMS) return e;
        return PlayableBookmark(positionMS: e.positionMS, title: newTitle, role: e.role);
      }).toFixedList();
    });
  }

  Future<List<PlayableBookmark>?> toggleRole(Playable item, PlayableBookmark bookmark, PlayableBookmarkRole role) {
    return _edit(item, (bookmarks) => toggledRole(bookmarks, bookmark.positionMS, role));
  }

  /// one start and one end per item, with the start before the end. null when no bookmark sits at [positionMS].
  @visibleForTesting
  static List<PlayableBookmark>? toggledRole(List<PlayableBookmark> bookmarks, int positionMS, PlayableBookmarkRole role) {
    final target = bookmarks.firstWhereEff((e) => e.positionMS == positionMS);
    if (target == null) return null;
    final newRole = target.role == role ? null : role;
    return bookmarks.map((e) {
      if (e.positionMS == positionMS) return PlayableBookmark(positionMS: e.positionMS, title: e.title, role: newRole);
      if (newRole != null && _losesRoleTo(e, positionMS, newRole)) return PlayableBookmark(positionMS: e.positionMS, title: e.title, role: null);
      return e;
    }).toFixedList();
  }

  static bool _losesRoleTo(PlayableBookmark other, int positionMS, PlayableBookmarkRole role) {
    final otherRole = other.role;
    if (otherRole == null) return false;
    if (otherRole == role) return true;
    return switch (role) {
      PlayableBookmarkRole.start => other.positionMS <= positionMS,
      PlayableBookmarkRole.end => other.positionMS >= positionMS,
    };
  }

  var _editLock = Future<void>.value();

  /// serialized since each edit rewrites the whole list, null when [edit] changes nothing.
  Future<List<PlayableBookmark>?> _edit(Playable item, List<PlayableBookmark>? Function(List<PlayableBookmark> bookmarks) edit) {
    final result = _editLock.then((_) async {
      final bookmarks = await getBookmarks(item) ?? const <PlayableBookmark>[];
      final newBookmarks = edit(bookmarks);
      if (newBookmarks != null) await _save(item, newBookmarks);
      return newBookmarks;
    });
    _editLock = result.ignoreError();
    return result;
  }

  Future<void> _save(Playable item, List<PlayableBookmark> bookmarks) async {
    await item.executeAsync(
      selectable: (finalItem) => Indexer.inst.updateTrackStats(finalItem.track, bookmarks: bookmarks),
      youtubeID: (finalItem) => YoutubeController.inst.statsManager.updateStats(finalItem, bookmarks: bookmarks),
    );
    if (Player.inst.isCurrentItem(item)) _setCurrent(bookmarks);
  }

  void play(Playable item, PlayableBookmark bookmark) {
    Player.inst.seekOrPlayAt(item, Duration(milliseconds: bookmark.positionMS));
  }

  static int _seekbarReachMS(int durationMS, double widthPx) => (_kSeekbarReachPx / widthPx * durationMS).round();

  int? _findBookmarkNearMS(int positionMS, int durationMS, double widthPx) {
    final bookmarks = _currentBookmarks.value;
    if (bookmarks.isEmpty || durationMS <= 0 || widthPx <= 0) return null;
    int nearestDistanceMS = _seekbarReachMS(durationMS, widthPx);
    int? nearestMS;
    for (final bookmark in bookmarks) {
      final distanceMS = (bookmark.positionMS - positionMS).abs();
      if (distanceMS > nearestDistanceMS) continue;
      nearestDistanceMS = distanceMS;
      nearestMS = bookmark.positionMS;
    }
    return nearestMS;
  }

  int? snapTapToBookmarkMS(int positionMS, int durationMS, double widthPx) {
    final nearestMS = _findBookmarkNearMS(positionMS, durationMS, widthPx);
    if (nearestMS != null) VibratorController.veryhigh();
    return nearestMS;
  }
}
