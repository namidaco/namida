import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class GenreTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => switch (type) {
    MediaType.style => RouteType.SUBPAGE_styleTracks,
    MediaType.language => RouteType.SUBPAGE_languageTracks,
    _ => RouteType.SUBPAGE_genreTracks,
  };

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

class _GenreTracksPageState extends State<GenreTracksPage> with PortsProvider<TracksSearchParams>, TracksSearchWidgetMixin<GenreTracksPage> {
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
    final searchResults = this.searchResults;
    final queueSource = switch (widget.type) {
      MediaType.style => QueueSource.style(name),
      MediaType.language => QueueSource.language(name),
      _ => QueueSource.genre(name),
    };
    final heroTag = widget.type.toGenreHeroTag(name);
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
                  type: widget.type,
                  onOpenMenu: () => NamidaDialogs.inst.showGenreDialog(name, widget.type),
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
                  bannerBuilder: (width, height) => ArtworkStripBanner(
                    tracks: tracks,
                    width: width,
                    height: height,
                  ),
                ),
                itemCount: searchResults?.length ?? tracks.length,
                itemExtent: Dimensions.inst.trackTileItemExtent,
                itemBuilder: (context, i) {
                  final index = searchResults == null ? i : searchResults[i];
                  final track = tracks[index];
                  return AnimatingTile(
                    key: ValueKey(index),
                    position: i,
                    child: TrackTile(
                      properties: properties,
                      index: index,
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
