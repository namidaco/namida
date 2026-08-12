import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class GenreTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => type == MediaType.style ? RouteType.SUBPAGE_styleTracks : RouteType.SUBPAGE_genreTracks;

  @override
  final String name;
  final List<Track> tracks;
  final MediaType type;
  const GenreTracksPage({
    super.key,
    required this.name,
    required this.tracks,
    this.type = MediaType.genre,
  });

  @override
  State<GenreTracksPage> createState() => _GenreTracksPageState();
}

class _GenreTracksPageState extends State<GenreTracksPage> with PortsProvider<Map<String, dynamic>>, TracksSearchWidgetMixin<GenreTracksPage> {
  @override
  Iterable<TrackExtended> getTracksExtended() {
    return widget.tracks.map((e) => e.track.toTrackExt());
  }

  @override
  RxBaseCore listChangesListenerRx() => Indexer.inst.getGenreMapFor(widget.type).rx;

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final tracks = widget.tracks;
    final isStyle = widget.type == MediaType.style;
    final queueSource = isStyle ? QueueSource.style(name) : QueueSource.genre(name);
    final heroTag = isStyle ? 'style_$name' : 'genre_$name';
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: queueSource,
          ),
          builder: (properties) => Obx(
            (context) {
              Indexer.inst.getGenreMapFor(widget.type).valueR; // to update after sorting
              return NamidaListView(
                stickyHeader: TracksSearchWidgetBox(
                  state: this,
                  leftText: [
                    tracks.displayTrackKeyword,
                    tracks.totalDurationFormatted,
                  ].join(' - '),
                  type: widget.type,
                  pageTitle: name,
                ),
                infoBox: (maxWidth) => SubpageInfoContainer(
                  maxWidth: maxWidth,
                  title: name,
                  source: queueSource,
                  subtitle: tracks.map((e) => e.originalArtist).takeUnique(10).join(', '),
                  heroTag: heroTag,
                  imageBuilder: (size) => MultiArtworkContainer(
                    size: size,
                    heroTag: heroTag,
                    tracks: tracks.toImageTracks(),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
