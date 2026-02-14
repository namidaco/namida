import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

class SortByMenuTracks with SortByMenuBase {
  const SortByMenuTracks();

  @override
  List<Widget> children(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return [
      NamidaInkWell(
        borderRadius: 10.0,
        margin: EdgeInsets.symmetric(horizontal: 6.0),
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        bgColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        onTap: () {
          NamidaNavigator.inst.popMenu();
          NamidaOnTaps.inst.onSubPageTracksSortIconTap(MediaType.track);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                lang.ADVANCED,
                style: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
            Icon(
              Broken.sort,
              size: 20.0,
            ),
          ],
        ),
      ),
      NamidaContainerDivider(
        margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      ),
      Padding(
        padding: EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
        child: ObxO(
          rx: settings.mediaItemsTrackSortingReverse,
          builder: (context, mediaItemsTrackSortingReverse) => ListTileWithCheckMark(
            borderRadius: 10.0,
            active: mediaItemsTrackSortingReverse[MediaType.track] == true,
            onTap: () {
              SearchSortController.inst.sortMedia(MediaType.track, reverse: !(settings.mediaItemsTrackSortingReverse[MediaType.track] == true));
            },
          ),
        ),
      ),
      ...[
        SortType.title,
        SortType.album,
        SortType.artistsList,
        SortType.albumArtist,
        SortType.composer,
        SortType.genresList,
        SortType.year,
        SortType.dateAdded,
        SortType.dateModified,
        SortType.bitrate,
        SortType.trackNo,
        SortType.discNo,
        SortType.filename,
        SortType.duration,
        SortType.sampleRate,
        SortType.size,
        SortType.rating,
        SortType.latestPlayed,
        SortType.mostPlayed,
        SortType.firstListen,
        SortType.shuffle,
      ].map(
        (e) => ObxO(
          rx: settings.mediaItemsTrackSorting,
          builder: (context, mediaItemsTrackSorting) => SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            active: mediaItemsTrackSorting[MediaType.track]?.firstOrNull == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.track, sortBy: e, forceSingleSorting: true),
          ),
        ),
      ),
    ];
  }
}

class SortByMenuTracksSearch extends StatelessWidget {
  const SortByMenuTracksSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.height * 0.5,
      child: SmoothSingleChildScrollView(
        child: Obx(
          (context) {
            final tracksSortSearch = settings.tracksSortSearch.valueR;
            final reversed = settings.tracksSortSearchReversed.valueR;
            final isAuto = settings.tracksSortSearchIsAuto.valueR;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
                  child: ListTileWithCheckMark(
                    borderRadius: 10.0,
                    icon: Broken.arrow_swap_horizontal,
                    title: lang.AUTO,
                    activeRx: settings.tracksSortSearchIsAuto,
                    onTap: () {
                      settings.save(tracksSortSearchIsAuto: !settings.tracksSortSearchIsAuto.value);
                      SearchSortController.inst.sortTracksSearch(canSkipSorting: false);
                    },
                  ),
                ),
                TapDetector(
                  onTap: isAuto ? () {} : null,
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: IgnorePointer(
                      ignoring: isAuto,
                      child: AnimatedOpacity(
                        opacity: isAuto ? 0.6 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
                              child: ListTileWithCheckMark(
                                borderRadius: 10.0,
                                active: isAuto ? settings.mediaItemsTrackSortingReverse.valueR[MediaType.track] == true : reversed,
                                onTap: () {
                                  SearchSortController.inst.sortTracksSearch(reverse: !reversed);
                                },
                              ),
                            ),
                            ...[
                              SortType.title,
                              SortType.album,
                              SortType.artistsList,
                              SortType.albumArtist,
                              SortType.composer,
                              SortType.genresList,
                              SortType.year,
                              SortType.dateAdded,
                              SortType.dateModified,
                              SortType.bitrate,
                              SortType.trackNo,
                              SortType.discNo,
                              SortType.filename,
                              SortType.duration,
                              SortType.sampleRate,
                              SortType.size,
                              SortType.rating,
                              SortType.latestPlayed,
                              SortType.mostPlayed,
                              SortType.firstListen,
                              SortType.shuffle,
                            ].map(
                              (e) => SmallListTile(
                                borderRadius: 12.0,
                                visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                title: e.toText(),
                                active: (isAuto ? settings.mediaItemsTrackSorting[MediaType.track]?.firstOrNull : tracksSortSearch) == e,
                                onTap: () {
                                  SearchSortController.inst.sortTracksSearch(sortBy: e);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SortByMenuAlbums with SortByMenuBase {
  const SortByMenuAlbums();

  @override
  List<Widget> children(BuildContext context) => [
    Padding(
      padding: EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
      child: ListTileWithCheckMark(
        borderRadius: 10.0,
        activeRx: settings.albumSortReversed,
        onTap: () => SearchSortController.inst.sortMedia(MediaType.album, reverse: !settings.albumSortReversed.value),
      ),
    ),
    ...[
      GroupSortType.album,
      GroupSortType.albumArtist,
      GroupSortType.year,
      GroupSortType.duration,
      GroupSortType.numberOfTracks,
      GroupSortType.playCount,
      GroupSortType.firstListen,
      GroupSortType.latestPlayed,
      GroupSortType.dateModified,
      GroupSortType.artistsList,
      GroupSortType.composer,
      GroupSortType.label,
      GroupSortType.shuffle,
    ].map(
      (e) => ObxO(
        rx: settings.albumSort,
        builder: (context, albumsort) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          active: albumsort == e,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.album, groupSortBy: e),
        ),
      ),
    ),
  ];
}

class SortByMenuArtists with SortByMenuBase {
  const SortByMenuArtists();

  @override
  List<Widget> children(BuildContext context) {
    final artistType = settings.activeArtistType.value;
    return [
      Padding(
        padding: EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
        child: ListTileWithCheckMark(
          borderRadius: 10.0,
          activeRx: settings.artistSortReversed,
          onTap: () => SearchSortController.inst.sortMedia(settings.activeArtistType.value, reverse: !settings.artistSortReversed.value),
        ),
      ),
      ...[
        artistType == MediaType.albumArtist
            ? GroupSortType.albumArtist
            : artistType == MediaType.composer
            ? GroupSortType.composer
            : GroupSortType.artistsList,
        GroupSortType.numberOfTracks,
        GroupSortType.playCount,
        GroupSortType.firstListen,
        GroupSortType.latestPlayed,
        GroupSortType.albumsCount,
        GroupSortType.duration,
        GroupSortType.genresList,
        GroupSortType.album,
        GroupSortType.year,
        GroupSortType.dateModified,
        GroupSortType.shuffle,
      ].map(
        (e) => ObxO(
          rx: settings.artistSort,
          builder: (context, artistSort) => SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            active: artistSort == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, groupSortBy: e),
          ),
        ),
      ),
    ];
  }
}

class SortByMenuGenres with SortByMenuBase {
  const SortByMenuGenres();

  @override
  List<Widget> children(BuildContext context) => [
    Padding(
      padding: EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
      child: ListTileWithCheckMark(
        borderRadius: 10.0,
        activeRx: settings.genreSortReversed,
        onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, reverse: !settings.genreSortReversed.value),
      ),
    ),
    ...[
      GroupSortType.genresList,
      GroupSortType.duration,
      GroupSortType.numberOfTracks,
      GroupSortType.playCount,
      GroupSortType.firstListen,
      GroupSortType.latestPlayed,
      GroupSortType.year,
      GroupSortType.artistsList,
      GroupSortType.album,
      GroupSortType.albumArtist,
      GroupSortType.dateModified,
      GroupSortType.composer,
      GroupSortType.shuffle,
    ].map(
      (e) => ObxO(
        rx: settings.genreSort,
        builder: (context, genreSort) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          active: genreSort == e,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, groupSortBy: e),
        ),
      ),
    ),
  ];
}

class SortByMenuPlaylist with SortByMenuBase {
  const SortByMenuPlaylist();

  @override
  List<Widget> children(BuildContext context) => [
    Padding(
      padding: EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
      child: ListTileWithCheckMark(
        borderRadius: 10.0,
        activeRx: settings.playlistSortReversed,
        onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !settings.playlistSortReversed.value),
      ),
    ),
    ...[
      GroupSortType.title,
      GroupSortType.creationDate,
      GroupSortType.modifiedDate,
      GroupSortType.duration,
      GroupSortType.numberOfTracks,
      GroupSortType.playCount,
      GroupSortType.firstListen,
      GroupSortType.latestPlayed,
      GroupSortType.shuffle,
      GroupSortType.custom,
    ].map(
      (e) => ObxO(
        rx: settings.playlistSort,
        builder: (context, playlistSort) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          active: playlistSort == e,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, groupSortBy: e),
        ),
      ),
    ),
  ];
}
