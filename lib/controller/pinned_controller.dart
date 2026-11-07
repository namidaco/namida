// by claude
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

/// pinned items of every type in one list, a new pinnable type adds a [PinnedItemType], a [PinnedItem] and its loop here.
class PinnedController {
  static final inst = PinnedController._();
  PinnedController._();

  /// reads inside an `Obx` rebuild on any pin change.
  List<PinnedItem> getPinnedItemsR() {
    final items = <PinnedItem>[];

    for (final playlist in PlaylistController.inst.playlistsMap.valueR.values) {
      final pinnedDate = playlist.pinnedDate;
      if (pinnedDate != null) items.add(PinnedItemPlaylist(playlist, pinnedDate: pinnedDate));
    }

    for (final smartPlaylistWrapper in SmartPlaylistsController.inst.smartPlaylistsMap.valueR.values) {
      final pinnedDate = smartPlaylistWrapper.value.pinnedDate;
      if (pinnedDate != null) items.add(PinnedItemSmartPlaylist(smartPlaylistWrapper, pinnedDate: pinnedDate));
    }

    return sortedByPinDate(items, (e) => e.pinnedDate);
  }

  /// newest pin first, pins from before pin dates were saved (`0`) last in their source order.
  static List<E> sortedByPinDate<E>(Iterable<E> pinnedItems, int Function(E item) pinnedDateOf) {
    final items = <E>[];
    final undatedItems = <E>[];
    for (final item in pinnedItems) {
      final pinnedDate = pinnedDateOf(item);
      if (pinnedDate > 0) {
        items.add(item);
      } else {
        undatedItems.add(item);
      }
    }
    items.sortByReverse(pinnedDateOf);
    items.addAll(undatedItems);
    return items;
  }
}

sealed class PinnedItem {
  final int pinnedDate;

  const PinnedItem({required this.pinnedDate});

  PinnedItemType get type;
}

final class PinnedItemPlaylist extends PinnedItem {
  final LocalPlaylist playlist;

  const PinnedItemPlaylist(this.playlist, {required super.pinnedDate});

  @override
  PinnedItemType get type => PinnedItemType.playlist;
}

final class PinnedItemSmartPlaylist extends PinnedItem {
  final SmartPlaylistWrapper smartPlaylistWrapper;

  const PinnedItemSmartPlaylist(this.smartPlaylistWrapper, {required super.pinnedDate});

  @override
  PinnedItemType get type => PinnedItemType.smartPlaylist;
}
