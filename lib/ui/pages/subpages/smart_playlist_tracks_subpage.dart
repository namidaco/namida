import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class SmartPlaylistTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_smartPlaylistTracks;

  @override
  String get name => smartPlaylistWrapper.value.name;

  final SmartPlaylistWrapper smartPlaylistWrapper;

  const SmartPlaylistTracksPage({
    super.key,
    required this.smartPlaylistWrapper,
  });

  @override
  State<SmartPlaylistTracksPage> createState() => _SmartPlaylistTracksPageState();
}

class _SmartPlaylistTracksPageState extends State<SmartPlaylistTracksPage>
    with TickerProviderStateMixin, PullToRefreshMixin, PortsProvider<Map<String, dynamic>>, TracksSearchWidgetMixin<SmartPlaylistTracksPage> {
  @override
  Iterable<TrackExtended> getTracksExtended() {
    return _tracks.map((e) => e.track.toTrackExt());
  }

  @override
  RxBaseCore listChangesListenerRx() =>
      SmartPlaylistsController.inst.smartPlaylistsMap.value[widget.smartPlaylistWrapper.value.key] ?? SmartPlaylistsController.inst.smartPlaylistsMap;

  final _controller = ScrollController();

  var _tracks = <Track>[];

  void _reFetchTracks() {
    setState(() {
      _tracks = widget.smartPlaylistWrapper.resolve();
    });
  }

  @override
  void initState() {
    _reFetchTracks();
    widget.smartPlaylistWrapper.addListener(_reFetchTracks);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    widget.smartPlaylistWrapper.removeListener(_reFetchTracks);
    _controller.dispose();
  }

  Future<void> _editAndRefresh(SmartPlaylist oldSmartPlaylist, SmartPlaylist smartPlaylist) async {
    await SmartPlaylistsController.inst.edit(oldSmartPlaylist, smartPlaylist);
    if (mounted) _reFetchTracks();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final queueSource = QueueSource.smartPlaylist(name);
    return BackgroundWrapper(
      child: AnimationLimiter(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: queueSource,
          ),
          builder: (properties) => PullToRefreshWidget(
            state: this,
            controller: _controller,
            onRefresh: () async => _reFetchTracks(),
            child: ObxO(
              rx: SmartPlaylistsController.inst.smartPlaylistsMap,
              builder: (context, smartPlaylistsMap) {
                final smartPlaylistWrapper = smartPlaylistsMap[widget.smartPlaylistWrapper.value.key];
                if (smartPlaylistWrapper == null) return const SizedBox();
                return ObxO(
                  rx: smartPlaylistWrapper,
                  builder: (context, smartPlaylist) => NamidaListView(
                    scrollController: _controller,
                    infoBox: (maxWidth) => SubpageInfoContainer(
                      maxWidth: maxWidth,
                      source: queueSource,
                      title: name,
                      subtitle: [
                        _tracks.length.displayTrackKeyword,
                        _tracks.totalDurationFormatted,
                      ].join(' - '),
                      heroTag: '',
                      imageBuilder: (size) => MultiArtworkContainer(
                        heroTag: '',
                        size: size,
                        tracks: _tracks.toImageTracks(),
                      ),
                      tracksFn: () => _tracks,
                    ),
                    stickyHeader: TracksSearchWidgetBoxBase(
                      state: this,
                      leftText: [
                        _tracks.displayTrackKeyword,
                        _tracks.totalDurationFormatted,
                      ].join(' - '),
                      sort: smartPlaylist.sort,
                      sortReverse: smartPlaylist.sortReverse,
                      onSortTap: () {
                        CreateSmartPlaylistDialog.openSortMenu(
                          context: context,
                          activeSort: smartPlaylist.sort,
                          activeSortReverse: smartPlaylist.sortReverse,
                          setSort: (newSort) => _editAndRefresh(
                            smartPlaylist,
                            smartPlaylist.copyWith(sort: newSort),
                          ),
                          setSortReverse: (newSortReverse) => _editAndRefresh(
                            smartPlaylist,
                            smartPlaylist.copyWith(sortReverse: newSortReverse),
                          ),
                          popMenuOnSortReverse: true,
                        );
                      },
                      onReverseIconTap: (newSortReverse) => _editAndRefresh(
                        smartPlaylist,
                        smartPlaylist.copyWith(sortReverse: newSortReverse),
                      ),
                    ),
                    itemCount: _tracks.length,
                    itemExtent: null,
                    itemExtentBuilder: (i, dimensions) {
                      if (shouldHideIndex(i)) return 0;
                      return Dimensions.inst.trackTileItemExtent;
                    },
                    itemBuilder: (context, i) {
                      final track = _tracks[i];

                      if (shouldHideIndex(i)) {
                        return SizedBox();
                      }

                      return AnimatingTile(
                        key: ValueKey(i),
                        position: i,
                        child: TrackTile(
                          properties: properties,
                          index: i,
                          trackOrTwd: track,
                          tracks: _tracks,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
