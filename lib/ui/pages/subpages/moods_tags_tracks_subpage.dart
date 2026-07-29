import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:nampack/reactive/class/rx_base.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class MoodsTracksSubPage {
  static Future<void> open(String name, List<Track> tracks) async {
    return _MoodsTagsTracksPage(
      route: RouteType.SUBPAGE_moodsTracks,
      name: name,
      icon: LibraryTab.moods.toIcon(),
      mediaType: MediaType.mood,
      queueSource: QueueSource.moods(name),
      tracks: tracks,
    ).navigate();
  }
}

class TagsTracksSubPage {
  static Future<void> open(String name, List<Track> tracks) {
    return _MoodsTagsTracksPage(
      route: RouteType.SUBPAGE_tagsTracks,
      name: name,
      icon: LibraryTab.tags.toIcon(),
      mediaType: MediaType.tag,
      queueSource: QueueSource.tags(name),
      tracks: tracks,
    ).navigate();
  }
}

class RatingsTracksSubPage {
  static Future<void> open(String name, List<Track> tracks) {
    return _MoodsTagsTracksPage(
      route: RouteType.SUBPAGE_ratingTracks,
      name: name,
      icon: LibraryTab.rating.toIcon(),
      mediaType: MediaType.rating,
      queueSource: QueueSource.rating(name),
      tracks: tracks,
    ).navigate();
  }
}

class _MoodsTagsTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  final RouteType route;
  @override
  final String name;
  final IconData icon;
  final QueueSource queueSource;
  final MediaType mediaType;
  final List<Track> tracks;

  const _MoodsTagsTracksPage({
    required this.route,
    required this.name,
    required this.icon,
    required this.queueSource,
    required this.mediaType,
    required this.tracks,
  });

  @override
  State<_MoodsTagsTracksPage> createState() => _MoodsTagsTracksPageState();
}

class _MoodsTagsTracksPageState extends State<_MoodsTagsTracksPage> with PortsProvider<Map<String, dynamic>>, TracksSearchWidgetMixin<_MoodsTagsTracksPage> {
  @override
  Iterable<TrackExtended> getTracksExtended() {
    return widget.tracks.map((e) => e.toTrackExt());
  }

  @override
  RxBaseCore<dynamic> listChangesListenerRx() => Indexer.inst.trackStatsMap;
  @override
  RxBaseCore<dynamic> listChangesListenerAltRx() => Indexer.inst.tracksInfoList;

  @override
  Widget build(BuildContext context) {
    final tracks = widget.tracks;
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: widget.queueSource,
          ),
          builder: (properties) => NamidaListView(
            stickyHeader: TracksSearchWidgetBox(
              state: this,
              leftText: [
                tracks.displayTrackKeyword,
                tracks.totalDurationFormatted,
              ].join(' - '),
              type: widget.mediaType,
              pageTitle: widget.name,
              disableSort: true,
            ),
            infoBox: (maxWidth) => SubpageInfoContainer(
              maxWidth: maxWidth,
              source: widget.queueSource,
              title: widget.name,
              subtitle: [
                tracks.length.displayTrackKeyword,
                tracks.totalDurationFormatted,
              ].join(' - '),
              heroTag: '',
              imageBuilder: (size) => MultiArtworkContainer(
                heroTag: '',
                size: size,
                tracks: tracks.toImageTracks(),
                fallbackIcon: widget.icon,
              ),
              tracksFn: () => tracks,
            ),
            itemCount: tracks.length,
            itemExtent: null,
            itemExtentBuilder: (i, dimensions) {
              if (shouldHideIndex(i)) return 0;
              return Dimensions.inst.trackTileItemExtent;
            },
            itemBuilder: (context, i) {
              if (shouldHideIndex(i)) {
                return const SizedBox();
              }
              final track = tracks[i];
              return AnimatingTile(
                key: ValueKey(i),
                position: i,
                child: TrackTile(
                  properties: properties,
                  index: i,
                  trackOrTwd: track,
                  tracks: tracks,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
