import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class ArtistTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route {
    return type == MediaType.albumArtist
        ? RouteType.SUBPAGE_albumArtistTracks
        : type == MediaType.composer
            ? RouteType.SUBPAGE_composerTracks
            : RouteType.SUBPAGE_artistTracks;
  }

  @override
  final String name;

  final List<Track> tracks;
  final List<String> albumIdentifiers;
  final List<String> singlesIdentifiers;
  final MediaType type;

  const ArtistTracksPage({
    super.key,
    required this.name,
    required this.tracks,
    required this.albumIdentifiers,
    required this.singlesIdentifiers,
    required this.type,
  });

  @override
  State<ArtistTracksPage> createState() => _ArtistTracksPageState();
}

class _ArtistTracksPageState extends State<ArtistTracksPage> with PortsProvider<Map<String, dynamic>>, TracksSearchWidgetMixin<ArtistTracksPage> {
  @override
  Iterable<TrackExtended> getTracksExtended() {
    return widget.tracks.map((e) => e.track.toTrackExt());
  }

  @override
  RxBaseCore listChangesListenerRx() => Indexer.inst.getArtistMapFor(widget.type).rx;

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final queueSource = type == MediaType.albumArtist
        ? QueueSource.albumArtist
        : type == MediaType.composer
            ? QueueSource.composer
            : QueueSource.artist;
    final tracks = widget.tracks;
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: queueSource,
          ),
          builder: (properties) => Obx(
            (context) {
              // to update after sorting
              Indexer.inst.getArtistMapFor(widget.type).valueR;

              return NamidaListView(
                header: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AlbumsRow(
                      title: lang.ALBUMS,
                      icon: Broken.music_dashboard,
                      identifiers: widget.albumIdentifiers,
                      initiallyExpanded: settings.extra.artistAlbumsExpanded ?? true,
                      onExpansionChanged: (value) => settings.extra.save(artistAlbumsExpanded: value),
                    ),
                    _AlbumsRow(
                      title: lang.SINGLES,
                      icon: Broken.music_square,
                      identifiers: widget.singlesIdentifiers,
                      initiallyExpanded: settings.extra.artistSinglesExpanded ?? false, // cuz no space
                      onExpansionChanged: (value) => settings.extra.save(artistSinglesExpanded: value),
                    ),
                    TracksSearchWidgetBox(
                      state: this,
                      leftText: [
                        tracks.displayTrackKeyword,
                        tracks.totalDurationFormatted,
                      ].join(' - '),
                      type: type,
                    )
                  ],
                ),
                infoBox: (maxWidth) => SubpageInfoContainer(
                  maxWidth: maxWidth,
                  topPadding: 8.0,
                  bottomPadding: 8.0,
                  title: widget.name,
                  source: queueSource,
                  subtitle: tracks.year.yearFormatted,
                  heroTag: 'artist_${widget.name}',
                  imageBuilder: (size) {
                    final info = NetworkArtworkInfo.artist(widget.name);
                    final tracksPathToImage = tracks.pathToImage;
                    final artworkPre = NetworkArtwork.orLocal(
                      key: Key(tracksPathToImage),
                      info: info,
                      path: tracksPathToImage,
                      track: tracks.trackOfImage,
                      thumbnailSize: size,
                      fit: BoxFit.cover,
                      forceSquared: true,
                      isCircle: true,
                      blur: 12.0,
                      iconSize: 32.0,
                    );
                    final artwork = NamidaArtworkExpandableToFullscreen(
                      artwork: artworkPre,
                      heroTag: 'artist_${widget.name}',
                      imageFile: () => info.toArtworkIfExistsAndValidAndEnabled() ?? File(tracksPathToImage),
                      fetchImage: () => null,
                      onSave: (imgFile, _) => imgFile == null ? null : EditDeleteController.inst.saveImageToStorage(imgFile),
                      themeColor: null,
                    );
                    return NamidaHero(
                      tag: 'artist_${widget.name}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ContainerWithBorder(
                          child: artwork,
                        ),
                      ),
                    );
                  },
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

class _AlbumsRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> identifiers;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const _AlbumsRow({
    required this.title,
    required this.icon,
    required this.identifiers,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      icon: icon,
      titleText: "$title ${identifiers.length}",
      initiallyExpanded: identifiers.isNotEmpty && initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      children: [
        SizedBox(
          height: 130.0 + 28.0,
          child: SuperSmoothListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            scrollDirection: Axis.horizontal,
            itemExtent: 100.0,
            itemCount: identifiers.length,
            itemBuilder: (context, i) {
              final albumId = identifiers[i];
              return Container(
                width: 100.0,
                margin: const EdgeInsets.only(left: 2.0),
                child: AlbumCard(
                  identifier: albumId,
                  album: albumId.getAlbumTracks(),
                  staggered: false,
                  compact: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
