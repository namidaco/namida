// by claude
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:history_manager/history_manager.dart';

abstract class HistoryStatsResolver<E> {
  const HistoryStatsResolver();

  bool isValid(E item) => true;

  /// 0 when unknown.
  int durationSeconds(E item);
  List<String> artists(E item);
  List<String> genres(E item);
  String? album(E item);

  /// 0 when unknown.
  int releaseYear(E item) => 0;

  /// kbps, 0 when unknown.
  int bitrate(E item) => 0;
  bool? isLossless(E item) => null;

  /// keys usable to look up [albumTracksCount], empty when unsupported.
  List<Object> albumKeys(E item) => const [];
  int albumTracksCount(Object albumKey) => 0;
  String albumName(Object albumKey) => '';
}

class StatsRediscovery<E> {
  final E item;
  final int count;
  final int gapDays;

  const StatsRediscovery(this.item, this.count, this.gapDays);
}

class StatsTrackStreak<E> {
  final E item;
  final int days;
  final int endDay;

  const StatsTrackStreak(this.item, this.days, this.endDay);
}

class StatsCompletedAlbum {
  final Object key;
  final String name;
  final int tracks;
  final int listens;

  const StatsCompletedAlbum(this.key, this.name, this.tracks, this.listens);
}

class StatsRankEntry<K> {
  final K key;
  final int count;

  const StatsRankEntry(this.key, this.count);
}

class StatsFirstListen<E> {
  final E item;
  final int firstListenMS;
  final int count;

  const StatsFirstListen(this.item, this.firstListenMS, this.count);
}

class StatsObsession<E> {
  final E item;
  final int day;
  final int count;

  const StatsObsession(this.item, this.day, this.count);
}

class StatsSession {
  final int startMS;
  final int endMS;
  final int listens;

  const StatsSession(this.startMS, this.endMS, this.listens);

  int get durationMS => endMS - startMS;
}

class StatsStreak {
  final int days;
  final int endDay;

  const StatsStreak(this.days, this.endDay);

  int get startDay => endDay - days + 1;
}

class HistoryStatsSnapshot<E> {
  final int firstDay;
  final int lastDay;

  /// index 0 == [firstDay].
  final Int32List listensPerDay;
  final int totalListens;
  final int daysWithListens;
  final int uniqueItems;
  final int uniqueArtists;
  final int uniqueGenres;
  final int uniqueAlbums;
  final Int32List hours;

  /// sunday first.
  final Int32List weekdays;

  /// 7 * 24, index = weekday(sunday first) * 24 + hour.
  final Int32List weekHours;

  /// listens per calendar month, aggregated across years.
  final Int32List months;
  final List<StatsRankEntry<E>> topItems;
  final List<StatsRankEntry<String>> topArtists;
  final List<StatsRankEntry<String>> topGenres;
  final List<StatsRankEntry<String>> topAlbums;
  final int otherArtistsListens;
  final int otherGenresListens;
  final int listenSeconds;
  final bool listenSecondsExact;
  final int newItems;
  final int newArtists;

  /// most listened items first heard in this range.
  final List<StatsFirstListen<E>> newItemsTop;
  final List<StatsRankEntry<String>> newArtistsTop;
  final StatsFirstListen<E>? oldestFavorite;

  /// distinct items, most plays in a single day first.
  final List<StatsObsession<E>> obsessions;
  final StatsSession? longestSession;
  final StatsStreak? longestStreak;
  final int currentStreak;
  final List<StatsRankEntry<E>?>? monthlyTop;
  final Map<TrackSource, int> sources;
  final int peakDay;
  final int peakDayListens;

  /// listens whose previous listen was the same item.
  final int repeatListens;
  final int oneTimeItems;
  final int heavyRotationItems;

  /// decade → listens, ascending.
  final List<StatsRankEntry<int>> decades;
  final List<StatsRediscovery<E>> rediscoveries;
  final StatsTrackStreak<E>? longestItemStreak;

  /// <128, 128-255, 256-319, 320+ kbps, weighted by listens.
  final Int32List bitrateBuckets;
  final int losslessListens;
  final int lossyListens;
  final List<StatsCompletedAlbum> completedAlbums;

  /// average minute of day of the first/last listen, -1 when unknown.
  final int avgFirstMinute;
  final int avgLastMinute;

  const HistoryStatsSnapshot({
    required this.firstDay,
    required this.lastDay,
    required this.listensPerDay,
    required this.totalListens,
    required this.daysWithListens,
    required this.uniqueItems,
    required this.uniqueArtists,
    required this.uniqueGenres,
    required this.uniqueAlbums,
    required this.hours,
    required this.weekdays,
    required this.weekHours,
    required this.months,
    required this.topItems,
    required this.topArtists,
    required this.topGenres,
    required this.topAlbums,
    required this.otherArtistsListens,
    required this.otherGenresListens,
    required this.listenSeconds,
    required this.listenSecondsExact,
    required this.newItems,
    required this.newArtists,
    required this.newItemsTop,
    required this.newArtistsTop,
    required this.oldestFavorite,
    required this.obsessions,
    required this.longestSession,
    required this.longestStreak,
    required this.currentStreak,
    required this.monthlyTop,
    required this.sources,
    required this.peakDay,
    required this.peakDayListens,
    required this.repeatListens,
    required this.oneTimeItems,
    required this.heavyRotationItems,
    required this.decades,
    required this.rediscoveries,
    required this.longestItemStreak,
    required this.bitrateBuckets,
    required this.losslessListens,
    required this.lossyListens,
    required this.completedAlbums,
    required this.avgFirstMinute,
    required this.avgLastMinute,
  });

  bool get isEmpty => totalListens == 0;
  StatsObsession<E>? get obsession => obsessions.firstOrNull;
  int get totalDays => lastDay - firstDay + 1;

  int listensAtDay(int day) {
    final i = day - firstDay;
    if (i < 0 || i >= listensPerDay.length) return 0;
    return listensPerDay[i];
  }

  static const sessionGapMS = 15 * 60 * 1000;
  static const rediscoveryGapDays = 180;
  static const heavyRotationCount = 10;

  static HistoryStatsSnapshot<E> compute<T extends ItemWithDate, E>({
    required HistoryManager<T, E> history,
    required HistoryStatsResolver<E> resolver,
    required int firstDay,
    required int lastDay,
    required Map<int, Map<String, int>> dailyListenTime,
    required List<String> listenTimeKeys,
    required int totalListenSeconds,
    int topCount = 20,
    int? monthlyTopYear,
  }) {
    final map = history.historyMap.value;
    final oldestDay = map.keys.lastOrNull;
    if (oldestDay != null && oldestDay > firstDay) firstDay = oldestDay;
    if (lastDay < firstDay) lastDay = firstDay;

    final totalDays = lastDay - firstDay + 1;
    final listensPerDay = Int32List(totalDays);
    final hours = Int32List(24);
    final weekdays = Int32List(7);
    final weekHours = Int32List(168);
    final months = Int32List(12);
    final tzOffsetMS = DateTime.now().timeZoneOffset.inMilliseconds;
    E? prevSub;
    int repeatListens = 0;
    int firstMinutesSum = 0;
    int lastMinutesSum = 0;

    final counts = <E, int>{};
    final dayCounts = <E, int>{};
    final sources = <TrackSource, int>{};
    final monthCounts = monthlyTopYear == null ? null : List.generate(12, (_) => <E, int>{}, growable: false);

    int totalListens = 0;
    int daysWithListens = 0;
    int peakDay = firstDay;
    int peakDayListens = 0;

    final obsessionByItem = <E, StatsObsession<E>>{};

    int prevDay = 0;
    int prevMS = 0;
    int sessionEndMS = 0;
    int sessionListens = 0;
    StatsSession? longestSession;

    void finalizeSession(int startMS) {
      if (sessionListens < 2) return;
      final dur = sessionEndMS - startMS;
      if (longestSession == null || dur > longestSession!.durationMS) {
        longestSession = StatsSession(startMS, sessionEndMS, sessionListens);
      }
    }

    for (final entry in map.entries) {
      final day = entry.key;
      if (day > lastDay) continue;
      if (day < firstDay) break;
      final items = entry.value;
      if (items.isEmpty) continue;

      final monthIndex = HistoryManager.daysSince1970ToDate(day).month - 1;
      final monthMap = monthCounts == null ? null : monthCounts[monthIndex];
      int dayListens = 0;
      int dayMinMS = 0;
      int dayMaxMS = 0;
      if (dayCounts.isNotEmpty) {
        _collectObsessions(obsessionByItem, dayCounts, prevDay);
        dayCounts.clear();
      }
      prevDay = day;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final sub = history.mainItemToSubItem(item);
        if (!resolver.isValid(sub)) continue;
        dayListens++;
        final ms = item.dateAddedMS;

        final localMS = ms + tzOffsetMS;
        final hour = (localMS ~/ 3600000) % 24;
        final weekday = ((localMS ~/ 86400000) + 4) % 7;
        hours[hour]++;
        weekdays[weekday]++;
        weekHours[weekday * 24 + hour]++;
        if (dayMinMS == 0 || ms < dayMinMS) dayMinMS = ms;
        if (ms > dayMaxMS) dayMaxMS = ms;
        if (prevSub == sub) repeatListens++;
        prevSub = sub;

        counts[sub] = (counts[sub] ?? 0) + 1;
        dayCounts[sub] = (dayCounts[sub] ?? 0) + 1;
        if (monthMap != null) monthMap[sub] = (monthMap[sub] ?? 0) + 1;

        final source = item.source;
        sources[source] = (sources[source] ?? 0) + 1;

        if (prevMS == 0 || (prevMS - ms).abs() > sessionGapMS) {
          finalizeSession(prevMS);
          sessionEndMS = ms;
          sessionListens = 1;
        } else {
          sessionListens++;
        }
        prevMS = ms;
      }
      if (dayListens == 0) continue;
      listensPerDay[day - firstDay] = dayListens;
      totalListens += dayListens;
      daysWithListens++;
      months[monthIndex] += dayListens;
      if (dayListens > peakDayListens) {
        peakDayListens = dayListens;
        peakDay = day;
      }
      firstMinutesSum += ((dayMinMS + tzOffsetMS) % 86400000) ~/ 60000;
      lastMinutesSum += ((dayMaxMS + tzOffsetMS) % 86400000) ~/ 60000;
    }
    finalizeSession(prevMS);
    if (dayCounts.isNotEmpty) _collectObsessions(obsessionByItem, dayCounts, prevDay);
    final obsessions = obsessionByItem.values.where((e) => e.count >= 2).toList();
    obsessions.sort((a, b) => b.count.compareTo(a.count));
    if (obsessions.length > 3) obsessions.length = 3;

    // ---- per unique item aggregation ----
    final artistsCount = <String, int>{};
    final genresCount = <String, int>{};
    final albumsCount = <String, int>{};
    final rangeStartMS = HistoryManager.daysSince1970ToMilliseconds(firstDay);
    final allTimeListens = history.topTracksMapListens.value;

    int estimatedSeconds = 0;
    int knownDurationListens = 0;
    int newItems = 0;
    int oneTimeItems = 0;
    int heavyRotationItems = 0;
    final decadesCount = <int, int>{};
    final rediscoveries = <StatsRediscovery<E>>[];
    StatsTrackStreak<E>? longestItemStreak;
    final bitrateBuckets = Int32List(4);
    int losslessListens = 0;
    int lossyListens = 0;
    final albumHeard = <Object, (Set<E>, int)>{};
    final rangeEndMS = HistoryManager.daysSince1970ToMilliseconds(lastDay + 1);
    final newItemsAll = <StatsFirstListen<E>>[];
    E? oldestFavItem;
    int oldestFavMS = 0;
    int oldestFavCount = 0;
    final artistsInRange = <String>{};

    for (final e in counts.entries) {
      final item = e.key;
      final count = e.value;

      final dur = resolver.durationSeconds(item);
      if (dur > 0) {
        estimatedSeconds += dur * count;
        knownDurationListens += count;
      }
      if (count == 1) oneTimeItems++;
      if (count >= heavyRotationCount) heavyRotationItems++;

      final year = resolver.releaseYear(item);
      if (year > 0) {
        final decade = (year ~/ 10) * 10;
        decadesCount[decade] = (decadesCount[decade] ?? 0) + count;
      }
      final lossless = resolver.isLossless(item);
      if (lossless != null) {
        if (lossless) {
          losslessListens += count;
        } else {
          lossyListens += count;
        }
      }
      final kbps = resolver.bitrate(item);
      if (kbps > 0) {
        bitrateBuckets[kbps < 128
                ? 0
                : kbps < 256
                ? 1
                : kbps < 320
                ? 2
                : 3] +=
            count;
      }
      for (final key in resolver.albumKeys(item)) {
        final existing = albumHeard[key];
        if (existing == null) {
          albumHeard[key] = ({item}, count);
        } else {
          existing.$1.add(item);
          albumHeard[key] = (existing.$1, existing.$2 + count);
        }
      }

      final allListens = allTimeListens[item];
      if (allListens != null && allListens.isNotEmpty) {
        final startIndex = _lowerBound(allListens, rangeStartMS);
        if (startIndex > 0 && startIndex < allListens.length) {
          final gapDays = (allListens[startIndex] - allListens[startIndex - 1]) ~/ 86400000;
          if (gapDays >= rediscoveryGapDays) rediscoveries.add(StatsRediscovery(item, count, gapDays));
        }
        int run = 0;
        int prevDay = -1;
        for (int i = startIndex; i < allListens.length; i++) {
          final ms = allListens[i];
          if (ms >= rangeEndMS) break;
          final d = (ms + tzOffsetMS) ~/ 86400000;
          if (d == prevDay) continue;
          run = d == prevDay + 1 ? run + 1 : 1;
          prevDay = d;
          if (run >= 2 && (longestItemStreak == null || run > longestItemStreak.days)) {
            longestItemStreak = StatsTrackStreak(item, run, d);
          }
        }
      }
      for (final a in resolver.artists(item)) {
        artistsCount[a] = (artistsCount[a] ?? 0) + count;
        artistsInRange.add(a);
      }
      for (final g in resolver.genres(item)) {
        genresCount[g] = (genresCount[g] ?? 0) + count;
      }
      final album = resolver.album(item);
      if (album != null && album.isNotEmpty) {
        albumsCount[album] = (albumsCount[album] ?? 0) + count;
      }

      final firstMS = allTimeListens[item]?.firstOrNull;
      if (firstMS != null) {
        if (firstMS >= rangeStartMS) {
          newItems++;
          newItemsAll.add(StatsFirstListen(item, firstMS, count));
        } else if (count >= 2 && (oldestFavItem == null || firstMS < oldestFavMS)) {
          oldestFavItem = item;
          oldestFavMS = firstMS;
          oldestFavCount = count;
        }
      }
    }

    // ---- new artists need all-time first listen per artist ----
    int newArtists = 0;
    var newArtistsTop = const <StatsRankEntry<String>>[];
    if (artistsInRange.isNotEmpty) {
      final artistFirstMS = <String, int>{};
      for (final e in allTimeListens.entriesSortedByValue) {
        final firstMS = e.value.firstOrNull;
        if (firstMS == null || firstMS >= rangeStartMS) continue;
        for (final a in resolver.artists(e.key)) {
          if (artistsInRange.contains(a)) artistFirstMS[a] = firstMS;
        }
        if (artistFirstMS.length == artistsInRange.length) break;
      }
      newArtists = artistsInRange.length - artistFirstMS.length;
      if (newArtists > 0) {
        final list = <StatsRankEntry<String>>[];
        for (final a in artistsInRange) {
          if (!artistFirstMS.containsKey(a)) list.add(StatsRankEntry(a, artistsCount[a] ?? 0));
        }
        list.sort((a, b) => b.count.compareTo(a.count));
        if (list.length > 10) list.length = 10;
        newArtistsTop = list;
      }
    }
    newItemsAll.sort((a, b) => b.count.compareTo(a.count));
    if (newItemsAll.length > 5) newItemsAll.length = 5;

    // ---- listen time: exact from daily db when covered, else calibrated estimate ----
    int listenSeconds = 0;
    bool listenSecondsExact = false;
    int? dbFirstDay;
    for (final d in dailyListenTime.keys) {
      if (dbFirstDay == null || d < dbFirstDay) dbFirstDay = d;
    }
    if (dbFirstDay != null && firstDay >= dbFirstDay) {
      listenSecondsExact = true;
      for (int d = firstDay; d <= lastDay; d++) {
        final row = dailyListenTime[d];
        if (row == null) continue;
        for (final k in listenTimeKeys) {
          listenSeconds += row[k] ?? 0;
        }
      }
    } else if (totalListens > 0) {
      int allTimeEstimate = 0;
      int allTimeKnown = 0;
      int allTimeTotal = 0;
      for (final e in allTimeListens.entriesSortedByValueCount) {
        final dur = resolver.durationSeconds(e.key);
        allTimeTotal += e.value;
        if (dur > 0) {
          allTimeEstimate += dur * e.value;
          allTimeKnown += e.value;
        }
      }
      if (allTimeKnown > 0 && knownDurationListens > 0) {
        final rangeEstimate = estimatedSeconds * totalListens / knownDurationListens;
        final fullEstimate = allTimeEstimate * allTimeTotal / allTimeKnown;
        listenSeconds = totalListenSeconds > 0 && fullEstimate > 0 ? (rangeEstimate * totalListenSeconds / fullEstimate).round() : rangeEstimate.round();
      } else if (allTimeTotal > 0) {
        listenSeconds = (totalListenSeconds * totalListens / allTimeTotal).round();
      }
    }

    // ---- streaks ----
    StatsStreak? longestStreak;
    int run = 0;
    for (int i = 0; i < totalDays; i++) {
      if (listensPerDay[i] > 0) {
        run++;
        if (longestStreak == null || run > longestStreak.days) longestStreak = StatsStreak(run, firstDay + i);
      } else {
        run = 0;
      }
    }
    int currentStreak = 0;
    {
      int i = totalDays - 1;
      if (i >= 0 && listensPerDay[i] == 0) i--;
      while (i >= 0 && listensPerDay[i] > 0) {
        currentStreak++;
        i--;
      }
    }

    List<StatsRankEntry<K>> top<K>(Map<K, int> m) {
      final list = m.entries.map((e) => StatsRankEntry(e.key, e.value)).toList();
      list.sort((a, b) => b.count.compareTo(a.count));
      if (list.length > topCount) list.length = topCount;
      return list;
    }

    int sumTop(List<StatsRankEntry> l) {
      int s = 0;
      for (final e in l) {
        s += e.count;
      }
      return s;
    }

    final topArtists = top(artistsCount);
    final topGenres = top(genresCount);

    rediscoveries.sort((a, b) => b.count.compareTo(a.count));
    if (rediscoveries.length > 5) rediscoveries.length = 5;

    final decades = decadesCount.entries.map((e) => StatsRankEntry(e.key, e.value)).toList();
    decades.sort((a, b) => a.key.compareTo(b.key));

    final completedAlbums = <StatsCompletedAlbum>[];
    for (final e in albumHeard.entries) {
      final total = resolver.albumTracksCount(e.key);
      if (total >= 2 && e.value.$1.length >= total) {
        completedAlbums.add(StatsCompletedAlbum(e.key, resolver.albumName(e.key), total, e.value.$2));
      }
    }
    completedAlbums.sort((a, b) => b.listens.compareTo(a.listens));

    List<StatsRankEntry<E>?>? monthlyTop;
    if (monthCounts != null) {
      monthlyTop = List.generate(
        12,
        (i) {
          final m = monthCounts[i];
          if (m.isEmpty) return null;
          E? best;
          int bestCount = 0;
          for (final e in m.entries) {
            if (e.value > bestCount) {
              bestCount = e.value;
              best = e.key;
            }
          }
          return best == null ? null : StatsRankEntry(best, bestCount);
        },
        growable: false,
      );
    }

    return HistoryStatsSnapshot(
      firstDay: firstDay,
      lastDay: lastDay,
      listensPerDay: listensPerDay,
      totalListens: totalListens,
      daysWithListens: daysWithListens,
      uniqueItems: counts.length,
      uniqueArtists: artistsCount.length,
      uniqueGenres: genresCount.length,
      uniqueAlbums: albumsCount.length,
      hours: hours,
      weekdays: weekdays,
      weekHours: weekHours,
      months: months,
      topItems: top(counts),
      topArtists: topArtists,
      topGenres: topGenres,
      topAlbums: top(albumsCount),
      otherArtistsListens: math.max(0, sumTop(topArtists) == 0 ? 0 : _sumValues(artistsCount) - sumTop(topArtists)),
      otherGenresListens: math.max(0, sumTop(topGenres) == 0 ? 0 : _sumValues(genresCount) - sumTop(topGenres)),
      listenSeconds: listenSeconds,
      listenSecondsExact: listenSecondsExact,
      newItems: newItems,
      newArtists: newArtists,
      newItemsTop: newItemsAll,
      newArtistsTop: newArtistsTop,
      oldestFavorite: oldestFavItem == null ? null : StatsFirstListen(oldestFavItem, oldestFavMS, oldestFavCount),
      obsessions: obsessions,
      longestSession: longestSession,
      longestStreak: longestStreak,
      currentStreak: currentStreak,
      monthlyTop: monthlyTop,
      sources: sources,
      peakDay: peakDay,
      peakDayListens: peakDayListens,
      repeatListens: repeatListens,
      oneTimeItems: oneTimeItems,
      heavyRotationItems: heavyRotationItems,
      decades: decades,
      rediscoveries: rediscoveries,
      longestItemStreak: longestItemStreak,
      bitrateBuckets: bitrateBuckets,
      losslessListens: losslessListens,
      lossyListens: lossyListens,
      completedAlbums: completedAlbums,
      avgFirstMinute: daysWithListens == 0 ? -1 : firstMinutesSum ~/ daysWithListens,
      avgLastMinute: daysWithListens == 0 ? -1 : lastMinutesSum ~/ daysWithListens,
    );
  }

  /// first index whose value >= [value] in an ascending list.
  static int _lowerBound(List<int> list, int value) {
    int lo = 0;
    int hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static void _collectObsessions<E>(Map<E, StatsObsession<E>> byItem, Map<E, int> dayCounts, int day) {
    for (final e in dayCounts.entries) {
      final existing = byItem[e.key];
      if (existing == null || e.value > existing.count) byItem[e.key] = StatsObsession(e.key, day, e.value);
    }
  }

  static int _sumValues(Map<String, int> m) {
    int s = 0;
    for (final v in m.values) {
      s += v;
    }
    return s;
  }
}
