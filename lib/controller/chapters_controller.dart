// by claude
import 'package:youtipie/class/streams/stream_segments.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/media_chapter.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class ChaptersController {
  static final inst = ChaptersController._();

  ChaptersController._();

  void initialize() {
    Player.inst.currentItem.addListener(_refreshCurrent);
    YoutubeInfoController.current.currentVideoPage.addListener(_onVideoPageChanged);
    _refreshCurrent();
  }

  static const _kSeekbarReachPx = 12.0;
  static const _kRestartChapterThresholdMS = 1000;

  RxBaseCore<List<MediaChapter>> get currentChapters => _currentChapters;
  final _currentChapters = const <MediaChapter>[].obs;

  bool get hasCurrentChapters => _currentChapters.value.isNotEmpty;

  List<MediaChapter> _resolveCurrentChapters() {
    final item = Player.inst.currentItem.value;
    if (item == null) return const [];
    return chaptersOf(item) ?? const [];
  }

  void _refreshCurrent() {
    final chapters = _resolveCurrentChapters();
    final hadChapters = _currentChapters.value.isNotEmpty;
    _currentChapters.value = chapters;
    if (hadChapters != chapters.isNotEmpty) Player.inst.refreshChapterNotificationButtons();
  }

  void _onVideoPageChanged() {
    if (Player.inst.currentItem.value is YoutubeID) _refreshCurrent();
  }

  /// youtube chapters are known only for the current video, once its page is fetched.
  List<MediaChapter>? chaptersOf(Playable item) {
    return item.execute<List<MediaChapter>?>(
      selectable: (finalItem) => finalItem.track.toTrackExtOrNull()?.chapters,
      youtubeID: (finalItem) {
        final page = YoutubeInfoController.current.currentVideoPage.value;
        if (page == null || page.videoId != finalItem.id) return null;
        return fromStreamSegments(page.streamSegments);
      },
    );
  }

  /// null when less than 2 segments have a start.
  static List<MediaChapter>? fromStreamSegments(List<StreamSegment>? segments) {
    if (segments == null || segments.length < 2) return null;
    final chapters = <MediaChapter>[];
    for (final segment in segments) {
      final startSeconds = segment.startSeconds;
      if (startSeconds != null) chapters.add(MediaChapter(startMS: startSeconds * 1000, title: segment.title));
    }
    return chapters.length < 2 ? null : chapters;
  }

  /// a chapter counts from 1ms before its start, same as [ChaptersTracker].
  static int _indexAt(List<MediaChapter> chapters, int positionMS) {
    for (int i = chapters.length - 1; i >= 0; i--) {
      if (positionMS + 1 >= chapters[i].startMS) return i;
    }
    return -1;
  }

  /// where skipping lands inside the current item, null when it should leave the item instead.
  /// going back restarts the current chapter unless it just started.
  int? adjacentChapterStartMS({required bool forward}) {
    final chapters = _currentChapters.value;
    if (chapters.isEmpty) return null;
    final positionMS = Player.inst.nowPlayingPosition.value;
    final index = _indexAt(chapters, positionMS);
    if (forward) {
      final nextIndex = index + 1;
      return nextIndex < chapters.length ? chapters[nextIndex].startMS : null;
    }
    if (index < 0) return null;
    final startMS = chapters[index].startMS;
    if (positionMS - startMS > _kRestartChapterThresholdMS) return startMS;
    if (index == 0) return null;
    return chapters[index - 1].startMS;
  }

  Future<void> seekToAdjacent({required bool forward}) async {
    final startMS = adjacentChapterStartMS(forward: forward);
    if (startMS != null) await Player.inst.seek(Duration(milliseconds: startMS));
  }

  void play(Playable item, MediaChapter chapter) {
    Player.inst.seekOrPlayAt(item, Duration(milliseconds: chapter.startMS));
  }

  /// skips the first chapter, the seek start magnet already covers it.
  int? snapTapToChapterMS(int positionMS, int durationMS, double widthPx) {
    final chapters = _currentChapters.value;
    if (chapters.isEmpty || durationMS <= 0 || widthPx <= 0) return null;
    int nearestDistanceMS = (_kSeekbarReachPx / widthPx * durationMS).round();
    int? nearestMS;
    for (final chapter in chapters) {
      final startMS = chapter.startMS;
      if (startMS <= 0) continue;
      final distanceMS = (startMS - positionMS).abs();
      if (distanceMS > nearestDistanceMS) continue;
      nearestDistanceMS = distanceMS;
      nearestMS = startMS;
    }
    if (nearestMS != null) VibratorController.veryhigh();
    return nearestMS;
  }
}

/// follows the playing position across chapter starts, checking only the current range per position update.
class ChaptersTracker {
  static const _kUnboundedMS = 1 << 40;

  final currentIndex = (-1).obs;
  List<int> _startsMS;
  int _rangeStartMS = 0;
  int _rangeEndMS = 0;

  /// a negative start is an unknown one.
  ChaptersTracker(List<int> startsMS) : _startsMS = startsMS {
    _resolve(Player.inst.nowPlayingPosition.value);
    Player.inst.nowPlayingPosition.addListener(_onPositionChange);
  }

  ChaptersTracker.fromChapters(List<MediaChapter> chapters) : this(chapters.map((e) => e.startMS).toFixedList());

  int get length => _startsMS.length;

  void updateStartsMS(List<int> startsMS) {
    _startsMS = startsMS;
    _resolve(Player.inst.nowPlayingPosition.value);
  }

  void dispose() {
    Player.inst.nowPlayingPosition.removeListener(_onPositionChange);
    currentIndex.close();
  }

  int? startMSOf(int index) {
    final startMS = _startsMS[index];
    return startMS < 0 ? null : startMS;
  }

  int? endMSOf(int index, int? durationMS) {
    final startsMS = _startsMS;
    for (int i = index + 1; i < startsMS.length; i++) {
      final startMS = startsMS[i];
      if (startMS >= 0) return startMS;
    }
    return durationMS;
  }

  (int, int)? rangeMSOf(int index, int? durationMS) {
    final startMS = startMSOf(index);
    final endMS = endMSOf(index, durationMS);
    if (startMS == null || endMS == null || endMS <= startMS) return null;
    return (startMS, endMS);
  }

  static String lengthLabel((int, int) rangeMS) => ((rangeMS.$2 - rangeMS.$1) ~/ 1000).secondsLabel;

  void seekTo(int index) {
    final startMS = startMSOf(index);
    if (startMS != null) Player.inst.seek(Duration(milliseconds: startMS + 1));
  }

  void _onPositionChange() {
    final positionMS = Player.inst.nowPlayingPosition.value;
    if (positionMS >= _rangeStartMS && positionMS < _rangeEndMS) return;
    _resolve(positionMS);
  }

  /// same bounds as `findByMillisecond`, a chapter counts from 1ms before its start.
  void _resolve(int positionMS) {
    final startsMS = _startsMS;
    int index = -1;
    for (int i = startsMS.length - 1; i >= 0; i--) {
      final startMS = startsMS[i];
      if (startMS >= 0 && positionMS + 1 >= startMS) {
        index = i;
        break;
      }
    }
    _rangeStartMS = index < 0 ? -_kUnboundedMS : startsMS[index] - 1;
    _rangeEndMS = (endMSOf(index, null) ?? _kUnboundedMS) - 1;
    currentIndex.value = index;
  }
}

enum ChapterStatus {
  played,
  current,
  upcoming;

  static ChapterStatus of(int index, int currentIndex) {
    if (index < currentIndex) return played;
    if (index == currentIndex) return current;
    return upcoming;
  }
}
