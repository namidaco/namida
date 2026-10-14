// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:playlist_manager/module/general_playlist.dart';

import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/youtube/class/youtube_id.dart';

void main() {
  group('sorts saved by a newer version', () {
    test('unknown names are skipped, the known ones keep their order', () {
      expect(SortType.sortListFromJsonList(['title', 'futureSort', 'year']), const [SortEntry(SortType.title), SortEntry(SortType.year)]);
      expect(YTSortType.sortListFromJsonList(['futureSort', 'channelTitle', 'date']), const [SortEntry(YTSortType.channelTitle), SortEntry(YTSortType.date)]);
    });

    test('entries that are not names are skipped', () {
      expect(SortType.sortListFromJsonList(['album', 3, null]), const [SortEntry(SortType.album)]);
      expect(SortType.sortListFromJsonList('title'), isEmpty);
    });

    test('local and youtube playlists keep their known sorts', () {
      final playlist = GeneralPlaylist<TrackWithDate, SortEntry<SortType>>.fromJson(
        {
          'name': 'mix',
          'sortsType': ['futureSort', 'mostPlayed'],
        },
        TrackWithDate.fromJson,
        SortType.sortListFromJsonList,
      );
      expect(playlist.sortsType, const [SortEntry(SortType.mostPlayed)]);

      final ytPlaylist = GeneralPlaylist<YoutubeID, SortEntry<YTSortType>>.fromJson(
        {
          'name': 'yt mix',
          'sortsType': ['dateAdded', 'futureSort'],
        },
        YoutubeID.fromJson,
        YTSortType.sortListFromJsonList,
      );
      expect(ytPlaylist.sortsType, const [SortEntry(YTSortType.dateAdded)]);
    });
  });

  group('reversed sorts', () {
    test('a reversed sort keeps its direction through a playlist save', () {
      final playlist = GeneralPlaylist<TrackWithDate, SortEntry<SortType>>.fromJson(
        {
          'name': 'mix',
          'sortsType': ['title'],
          'sortsType_v2': ['-rating', 'title'],
        },
        TrackWithDate.fromJson,
        SortType.sortListFromJsonList,
      );
      expect(playlist.sortsType, const [SortEntry(SortType.rating, reverse: true), SortEntry(SortType.title)]);

      final json = playlist.toJson((e) => e.toJson(), SortType.sortsToJson);
      expect(json['sortsType_v2'], ['-rating', 'title']);
      expect(json.containsKey('sortsType'), false);
    });

    test('repeated sorts are dropped', () {
      expect(SortType.sortListFromJsonList(['-year', 'year', 'title']), const [SortEntry(SortType.year, reverse: true), SortEntry(SortType.title)]);
    });
  });
}
