// all favourites sorting logic by claude
part of 'indexer_controller.dart';

/// keeps lists sorted by [SortType.favourite] in order by moving only the changed tracks instead of sorting again.
class _FavouritesSorting<T extends Track> {
  final Indexer<T> _indexer;
  _FavouritesSorting(this._indexer);

  /// above this, sorting again is cheaper than searching each list per track.
  static const _kMaxTracksToReposition = 32;

  /// {track: wasFavourite}, tracks changed from inside a list are kept in place until the user leaves that page.
  final _deferredTracks = <T, bool>{};

  void defer(T track) {
    final medias = _getMediasSortedByFavourites();
    if (medias.isEmpty) return;
    if (_deferredTracks.isEmpty) NamidaNavigator.inst.currentWidgetStack.addListener(_onPageChanged);
    _deferredTracks[track] ??= track.isFavourite;
  }

  void onChanged(Iterable<T>? tracks) {
    if (!_indexer.mainMapsGroup.didFill) return; // -- the first sort reads favourites
    final medias = _getMediasSortedByFavourites();
    if (medias.isEmpty) return;

    if (tracks == null || tracks.length > _kMaxTracksToReposition) {
      _indexer.sortMediaTracksSubLists(medias);
      return;
    }

    final tracksToReposition = tracks.where((tr) => !_deferredTracks.containsKey(tr));
    _reposition(tracksToReposition, medias);
  }

  void _onPageChanged() {
    NamidaNavigator.inst.currentWidgetStack.removeListener(_onPageChanged);
    final tracksToReposition = <T>[];
    for (final e in _deferredTracks.entries) {
      final tr = e.key;
      final wasFavourite = e.value;
      if (tr.isFavourite != wasFavourite) tracksToReposition.add(tr);
    }
    _deferredTracks.clear();
    if (tracksToReposition.isEmpty) return;

    final medias = _getMediasSortedByFavourites();
    if (medias.isEmpty) return;
    _reposition(tracksToReposition, medias);
  }

  void _reposition(Iterable<T> tracks, List<MediaType> medias) {
    final sorters = {for (final e in medias) e: SearchSortController.inst.getMediaTracksSortingComparables(e)};
    final changedMedias = _indexer.mainMapsGroup.repositionTracksSync(
      tracks,
      sorters,
      settings.mediaItemsTrackSortingReverse.value,
      _indexer.tracksInfoList.value,
      (tr) => tr.toTrackExt(),
      settings.albumIdentifiers.value,
    );
    if (changedMedias.isEmpty) return;

    // -- the search isolate keeps the old order, it's spawned again on the next search
    if (changedMedias.contains(MediaType.track)) SearchSortController.inst.closePorts(MediaType.track);
    _indexer.mainMapsGroup.refreshMedias(changedMedias);
    _indexer._refreshMediaTracksSubListsAfterSort(changedMedias);
  }

  /// a [SortType.shuffle] before it makes the favourite key unreachable.
  List<MediaType> _getMediasSortedByFavourites() {
    final medias = <MediaType>[];
    for (final e in settings.mediaItemsTrackSorting.value.entries) {
      for (final sort in e.value) {
        if (sort == SortType.shuffle) break;
        if (sort == SortType.favourite) {
          medias.add(e.key);
          break;
        }
      }
    }
    return medias;
  }
}
