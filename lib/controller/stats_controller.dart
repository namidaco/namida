import 'package:history_manager/history_manager.dart';

import 'package:namida/class/history_stats.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/listen_time_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

// by claude
class StatsController {
  static StatsController get inst => _instance;
  static final StatsController _instance = StatsController._internal();
  StatsController._internal();

  static const localListenTimeKeys = [LibraryCategory.localTracks, LibraryCategory.localVideos];
  static const youtubeListenTimeKeys = [LibraryCategory.youtube];

  static const _localResolver = _TrackStatsResolver();
  static const _youtubeResolver = _YoutubeStatsResolver();

  final _localCache = _SnapshotCache<Track>();
  final _youtubeCache = _SnapshotCache<String>();
  final _localPrevCache = _SnapshotCache<Track>();
  final _youtubePrevCache = _SnapshotCache<String>();

  void clearCache() {
    _localCache.clear();
    _youtubeCache.clear();
    _localPrevCache.clear();
    _youtubePrevCache.clear();
  }

  Future<HistoryStatsSnapshot<Track>> local(DateRange range, {int? monthlyTopYear}) {
    return _compute(
      history: HistoryController.inst,
      resolver: _localResolver,
      cache: _localCache,
      keys: localListenTimeKeys,
      range: range,
      monthlyTopYear: monthlyTopYear,
    );
  }

  Future<HistoryStatsSnapshot<Track>> localPrevious(DateRange range) {
    return _compute(
      history: HistoryController.inst,
      resolver: _localResolver,
      cache: _localPrevCache,
      keys: localListenTimeKeys,
      range: range,
      monthlyTopYear: null,
    );
  }

  Future<HistoryStatsSnapshot<String>> youtubePrevious(DateRange range) {
    return _compute(
      history: YoutubeHistoryController.inst,
      resolver: _youtubeResolver,
      cache: _youtubePrevCache,
      keys: youtubeListenTimeKeys,
      range: range,
      monthlyTopYear: null,
    );
  }

  Future<HistoryStatsSnapshot<String>> youtube(DateRange range, {int? monthlyTopYear}) {
    return _compute(
      history: YoutubeHistoryController.inst,
      resolver: _youtubeResolver,
      cache: _youtubeCache,
      keys: youtubeListenTimeKeys,
      range: range,
      monthlyTopYear: monthlyTopYear,
    );
  }

  Future<HistoryStatsSnapshot<E>> _compute<T extends ItemWithDate, E>({
    required HistoryManager<T, E> history,
    required HistoryStatsResolver<E> resolver,
    required _SnapshotCache<E> cache,
    required List<String> keys,
    required DateRange range,
    required int? monthlyTopYear,
  }) async {
    final firstDay = range.oldest.toDaysSince1970();
    final lastDay = range.newest.toDaysSince1970();
    final version = history.totalHistoryItemsCount.value;
    final cached = cache.get(firstDay, lastDay, monthlyTopYear, version);
    if (cached != null) return cached;

    await history.waitForHistoryAndMostPlayedLoad;
    final daily = await ListenTimeController.inst.loadAll();

    final listenTimeMap = Player.inst.totalListenedTimeInSec;
    int totalListenSeconds = 0;
    for (final k in keys) {
      totalListenSeconds += listenTimeMap?[k] ?? 0;
    }

    final snapshot = HistoryStatsSnapshot.compute(
      history: history,
      resolver: resolver,
      firstDay: firstDay,
      lastDay: lastDay,
      dailyListenTime: daily,
      listenTimeKeys: keys,
      totalListenSeconds: totalListenSeconds,
      monthlyTopYear: monthlyTopYear,
    );
    cache.set(firstDay, lastDay, monthlyTopYear, version, snapshot);
    return snapshot;
  }

  static DateRange yearRange(int year) => DateRange(
    oldest: DateTime(year),
    newest: DateTime(year, 12, 31, 23, 59, 59),
  );

  /// december & january.
  static int? yearInReviewToShow() {
    final now = DateTime.now();
    if (now.month == 12) return now.year;
    if (now.month == 1) return now.year - 1;
    return null;
  }
}

class _SnapshotCache<E> {
  int _firstDay = -1;
  int _lastDay = -1;
  int? _monthlyTopYear;
  int _version = -1;
  HistoryStatsSnapshot<E>? _snapshot;

  HistoryStatsSnapshot<E>? get(int firstDay, int lastDay, int? monthlyTopYear, int version) {
    if (_snapshot == null) return null;
    if (_firstDay != firstDay || _lastDay != lastDay || _monthlyTopYear != monthlyTopYear || _version != version) return null;
    return _snapshot;
  }

  void clear() => _snapshot = null;

  void set(int firstDay, int lastDay, int? monthlyTopYear, int version, HistoryStatsSnapshot<E> snapshot) {
    _firstDay = firstDay;
    _lastDay = lastDay;
    _monthlyTopYear = monthlyTopYear;
    _version = version;
    _snapshot = snapshot;
  }
}

class _TrackStatsResolver extends HistoryStatsResolver<Track> {
  const _TrackStatsResolver();

  @override
  int durationSeconds(Track item) => (item.toTrackExtOrNull()?.durationMS ?? 0) ~/ 1000;

  @override
  List<String> artists(Track item) => item.toTrackExtOrNull()?.artistsList ?? const [];

  @override
  List<String> genres(Track item) => item.toTrackExtOrNull()?.genresList ?? const [];

  @override
  String? album(Track item) => item.toTrackExtOrNull()?.originalAlbum;

  @override
  int releaseYear(Track item) {
    var year = item.toTrackExtOrNull()?.year ?? 0;
    if (year > 9999) year = int.tryParse(year.toString().substring(0, 4)) ?? 0;
    if (year <= 0 || year > _maxPlausibleYear) return 0;
    // -- anything older than 1900 (or malformed) is grouped under the 1900s.
    return year < 1900 ? 1900 : year;
  }

  static final _maxPlausibleYear = DateTime.now().year + 1;

  @override
  int bitrate(Track item) => item.toTrackExtOrNull()?.bitrate ?? 0;

  @override
  bool? isLossless(Track item) => item.toTrackExtOrNull()?.isLossless;

  @override
  List<Object> albumKeys(Track item) => item.toTrackExtOrNull()?.albumsIdentifiersModified ?? const [];

  @override
  int albumTracksCount(Object albumKey) => Indexer.inst.mainMapAlbums.value[albumKey as AlbumIdentifierWrapper]?.length ?? 0;

  @override
  String albumName(Object albumKey) => (albumKey as AlbumIdentifierWrapper).displayAlbumName;
}

class _YoutubeStatsResolver extends HistoryStatsResolver<String> {
  const _YoutubeStatsResolver();

  @override
  bool isValid(String item) => !item.isDummyVideoId;

  @override
  int durationSeconds(String item) => YoutubeInfoController.utils.getVideoDurationSecondsSyncTemp(item) ?? 0;

  @override
  List<String> artists(String item) {
    final name = YoutubeInfoController.utils.getVideoChannelNameSync(item, checkFromStorage: false);
    return name == null ? const [] : [name];
  }

  @override
  List<String> genres(String item) => const [];

  @override
  String? album(String item) => null;
}
