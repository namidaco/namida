// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/pinned_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/enums.dart';

void main() {
  LocalPlaylist playlistFromJson(Map<String, dynamic> json) => LocalPlaylist.fromJson(json, TrackWithDate.fromJson, SortType.sortListFromJsonList);
  Map<String, dynamic> playlistToJson(LocalPlaylist pl) => pl.toJson((e) => e.toJson(), SortType.sortsToJson);

  LocalPlaylist newPlaylist(String name, {int? pinnedDate}) => LocalPlaylist(
    name: name,
    tracks: [],
    creationDate: 1,
    modifiedDate: 1,
    comment: '',
    moods: [],
    isFav: false,
    pinnedDate: pinnedDate,
    sortsType: null,
    sortReverse: false,
  );

  SmartPlaylist newSmartPlaylist(String name, {int? pinnedDate}) => SmartPlaylist(
    name: name,
    creationDate: DateTime(2026),
    joiner: SmartJoiner.and,
    sorting: const SortChain([]),
    moods: [],
    ruleGroups: [],
    limit: null,
    pinnedDate: pinnedDate,
  );

  group('playlist pin date', () {
    test('pins saved before pin dates read as pinned with date 0', () {
      final pl = playlistFromJson({'name': 'a', 'isPinned': true});
      expect(pl.isPinned, true);
      expect(pl.pinnedDate, 0);
      final json = playlistToJson(pl);
      expect(json.containsKey('isPinned'), false);
      expect(json['pinnedDate'], 0);
      expect(playlistFromJson(json).isPinned, true);
    });

    test('unpinned json stays without pin keys', () {
      final pl = playlistFromJson({'name': 'a'});
      expect(pl.isPinned, false);
      final json = playlistToJson(pl);
      expect(json.containsKey('isPinned'), false);
      expect(json.containsKey('pinnedDate'), false);
    });

    test('pinning saves the date', () {
      final pinned = newPlaylist('a').copyWith(isPinned: true);
      final pinnedDate = pinned.pinnedDate!;
      expect(pinnedDate, greaterThan(0));
      final json = playlistToJson(pinned);
      expect(json.containsKey('isPinned'), false);
      expect(json['pinnedDate'], pinnedDate);
      expect(playlistFromJson(json).pinnedDate, pinnedDate);
    });

    test('pinning again keeps the older date, unpinning removes it', () {
      final pinned = newPlaylist('a', pinnedDate: 5);
      expect(pinned.copyWith(isPinned: true).pinnedDate, 5);
      expect(pinned.copyWith(comment: 'x').pinnedDate, 5);
      expect(pinned.copyWith(isPinned: false).pinnedDate, null);
      expect(pinned.copyWith(isPinned: false).isPinned, false);
    });
  });

  group('smart playlist pin date', () {
    test('saved and read back', () {
      final map = newSmartPlaylist('s', pinnedDate: 7).toMap();
      expect(map['pinnedDate'], 7);
      expect(SmartPlaylist.fromMap(map).pinnedDate, 7);
      expect(newSmartPlaylist('s').toMap().containsKey('pinnedDate'), false);
      expect(SmartPlaylist.fromMap(newSmartPlaylist('s').toMap()).isPinned, false);
    });

    test('pinning keeps an older date, unpinning removes it', () {
      final unpinned = newSmartPlaylist('s');
      expect(unpinned.copyWith(isPinned: true).pinnedDate, greaterThan(0));
      final pinned = newSmartPlaylist('s', pinnedDate: 7);
      expect(pinned.copyWith(isPinned: true).pinnedDate, 7);
      expect(pinned.copyWith(moods: ['x']).pinnedDate, 7);
      expect(pinned.copyWith(isPinned: false).pinnedDate, null);
    });
  });

  group('pinned order', () {
    test('newest first, undated last in their source order', () {
      final items = [('a', 5), ('old1', 0), ('b', 9), ('old2', 0), ('c', 7)];
      final sorted = PinnedController.sortedByPinDate(items, (e) => e.$2);
      expect(sorted.map((e) => e.$1), ['b', 'c', 'a', 'old1', 'old2']);
    });

    test('playlists and smart playlists are mixed by pin date', () {
      final playlistsMap = PlaylistController.inst.playlistsMap.value;
      final smartPlaylistsMap = SmartPlaylistsController.inst.smartPlaylistsMap.value;
      addTearDown(() {
        playlistsMap.clear();
        smartPlaylistsMap.clear();
      });
      playlistsMap['p old'] = newPlaylist('p old', pinnedDate: 0);
      playlistsMap['p unpinned'] = newPlaylist('p unpinned');
      playlistsMap['p 10'] = newPlaylist('p 10', pinnedDate: 10);
      smartPlaylistsMap['s 20'] = SmartPlaylistWrapper(newSmartPlaylist('s 20', pinnedDate: 20));
      smartPlaylistsMap['s unpinned'] = SmartPlaylistWrapper(newSmartPlaylist('s unpinned'));
      smartPlaylistsMap['s 5'] = SmartPlaylistWrapper(newSmartPlaylist('s 5', pinnedDate: 5));

      final items = PinnedController.inst.getPinnedItemsR();
      final names = items.map(
        (e) => switch (e) {
          PinnedItemPlaylist(:final playlist) => playlist.name,
          PinnedItemSmartPlaylist(:final smartPlaylistWrapper) => smartPlaylistWrapper.value.name,
        },
      );
      expect(names, ['s 20', 'p 10', 's 5', 'p old']);
      expect(items.map((e) => e.type), [PinnedItemType.smartPlaylist, PinnedItemType.playlist, PinnedItemType.smartPlaylist, PinnedItemType.playlist]);
    });
  });
}
