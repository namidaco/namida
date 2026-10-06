// by claude
import 'dart:async';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/bookmarks_sheet.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class BookmarksController {
  static final inst = BookmarksController._();

  BookmarksController._() {
    _refreshCurrent();
    Player.inst.currentItem.addListener(_refreshCurrent);
    Indexer.inst.trackStatsMap.addListener(_onTrackStatsChanged);
  }

  static const _kNearbyRangeMS = 1000;
  static const _kSeekbarReachPx = 12.0;

  RxBaseCore<List<PlayableBookmark>> get currentBookmarks => _currentBookmarks;
  final _currentBookmarks = const <PlayableBookmark>[].obs;

  void _refreshCurrent() async {
    final item = Player.inst.currentItem.value;
    final bookmarks = item == null ? null : await getBookmarks(item);
    if (!identical(item, Player.inst.currentItem.value)) return;
    _currentBookmarks.value = bookmarks ?? const [];
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

  bool isCurrent(Playable item) {
    final current = Player.inst.currentItem.value;
    if (current == null) return false;
    final isSame = item.execute(
      selectable: (finalItem) => current is Selectable && current.track == finalItem.track,
      youtubeID: (finalItem) => current is YoutubeID && current.id == finalItem.id,
    );
    return isSame == true;
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
    final bookmark = PlayableBookmark(positionMS: positionMS, title: null);
    final newBookmarks = await _edit(item, (bookmarks) {
      final alreadyExists = bookmarks.any((e) => (e.positionMS - positionMS).abs() < _kNearbyRangeMS);
      if (alreadyExists) return null;
      return [...bookmarks, bookmark]..sortBy((e) => e.positionMS);
    });
    if (newBookmarks == null) {
      snackyy(icon: Broken.bookmark, message: '${lang.bookmarks}: ${lang.alreadyExists} ($positionLabel)');
      return;
    }
    VibratorController.medium();
    snackyy(
      icon: Broken.bookmark,
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
    final renamedBookmark = PlayableBookmark(positionMS: bookmark.positionMS, title: newTitle);
    return _edit(item, (bookmarks) => bookmarks.map((e) => e.positionMS == bookmark.positionMS ? renamedBookmark : e).toFixedList());
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
    if (isCurrent(item)) _currentBookmarks.value = bookmarks;
  }

  void play(Playable item, PlayableBookmark bookmark) {
    final position = Duration(milliseconds: bookmark.positionMS);
    if (isCurrent(item)) {
      Player.inst.seek(position);
      return;
    }
    final source = item.execute<QueueSourceBase>(
      selectable: (_) => QueueSource.others(null),
      youtubeID: (_) => QueueSourceYoutubeID.ytPlayerQueue,
    );
    if (source == null) return;
    Player.inst.playOrPause(0, [item], source, gentlePlay: true, startPosition: position);
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
