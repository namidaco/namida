// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:playlist_manager/module/general_playlist.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/youtube/class/youtube_id.dart';

void main() {
  group('sorts saved by a newer version', () {
    test('unknown names are skipped, the known ones keep their order', () {
      expect(SortType.sortListFromJsonList(['title', 'futureSort', 'year']), [SortType.title, SortType.year]);
      expect(YTSortType.sortListFromJsonList(['futureSort', 'channelTitle', 'date']), [YTSortType.channelTitle, YTSortType.date]);
    });

    test('entries that are not names are skipped', () {
      expect(SortType.sortListFromJsonList(['album', 3, null]), [SortType.album]);
      expect(SortType.sortListFromJsonList('title'), isEmpty);
    });

    test('local and youtube playlists keep their known sorts', () {
      final playlist = GeneralPlaylist<TrackWithDate, SortType>.fromJson(
        {
          'name': 'mix',
          'sortsType': ['futureSort', 'mostPlayed'],
        },
        TrackWithDate.fromJson,
        SortType.sortListFromJsonList,
      );
      expect(playlist.sortsType, [SortType.mostPlayed]);

      final ytPlaylist = GeneralPlaylist<YoutubeID, YTSortType>.fromJson(
        {
          'name': 'yt mix',
          'sortsType': ['dateAdded', 'futureSort'],
        },
        YoutubeID.fromJson,
        YTSortType.sortListFromJsonList,
      );
      expect(ytPlaylist.sortsType, [YTSortType.dateAdded]);
    });
  });
}
