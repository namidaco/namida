import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/now_playing_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/settings/filter_sort_menu.dart';
import 'package:namida/ui/widgets/settings/reverse_order_container.dart';
import 'package:namida/core/extensions.dart';

class SortByMenu extends StatelessWidget {
  const SortByMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final isTracksPage = SettingsController.inst.selectedLibraryTab.value == LibraryTab.tracks;
    final isAlbumsPage = SettingsController.inst.selectedLibraryTab.value == LibraryTab.albums;
    final isArtistsPage = SettingsController.inst.selectedLibraryTab.value == LibraryTab.artists;
    final isGenresPage = SettingsController.inst.selectedLibraryTab.value == LibraryTab.genres;
    //TODO
    // final isFoldersPage = SettingsController.inst.selectedLibraryTab.value == LibraryTab.folders;
    return Row(
      children: [
        TextButton(
          child: Text(
            isTracksPage
                ? Language.inst.SORT_TRACKS_BY
                : isAlbumsPage
                    ? Language.inst.SORT_ALBUMS_BY
                    : isArtistsPage
                        ? Language.inst.SORT_ARTISTS_BY
                        : isGenresPage
                            ? Language.inst.SORT_GENRES_BY
                            : '',
          ),
          onPressed: () async {
            final tracksSort = SettingsController.inst.tracksSort.value;
            await showMenu(
              // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0.multipliedRadius)),
              // color: Color.alphaBlend(context.theme.cardTheme.color!.withAlpha(100), context.theme.colorScheme.background),
              color: context.theme.appBarTheme.backgroundColor,
              context: context,
              position: RelativeRect.fromLTRB(Get.width, Get.statusBarHeight + 64.0, 20, 0), constraints: BoxConstraints(maxHeight: Get.height / 1.5),
              items: [
                if (isTracksPage) ...[
                  PopupMenuItem(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    child: Obx(
                      () {
                        final tracksSort = SettingsController.inst.tracksSort.value;
                        return CustomSortByExpansionTile(
                          title: Language.inst.SORT_TRACKS_BY,
                          children: [
                            ReverseOrderContainer(
                              active: SettingsController.inst.tracksSortReversed.value,
                              onTap: () => Indexer.inst.sortTracks(reverse: !SettingsController.inst.tracksSortReversed.value),
                            ),
                            SmallListTile(
                              title: Language.inst.TITLE,
                              active: tracksSort == SortType.title,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.title),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM,
                              active: tracksSort == SortType.album,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.album),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM_ARTIST,
                              active: tracksSort == SortType.albumArtist,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.albumArtist),
                            ),
                            SmallListTile(
                              title: Language.inst.ARTISTS,
                              active: tracksSort == SortType.artistsList,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.artistsList),
                            ),
                            SmallListTile(
                              title: Language.inst.BITRATE,
                              active: tracksSort == SortType.bitrate,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.bitrate),
                            ),
                            SmallListTile(
                              title: Language.inst.COMPOSER,
                              active: tracksSort == SortType.composer,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.composer),
                            ),
                            SmallListTile(
                              title: Language.inst.DATE_MODIFIED,
                              active: tracksSort == SortType.dateModified,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.dateModified),
                            ),
                            SmallListTile(
                              title: Language.inst.DISC_NUMBER,
                              active: tracksSort == SortType.discNo,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.discNo),
                            ),
                            SmallListTile(
                              title: Language.inst.FILE_NAME,
                              active: tracksSort == SortType.displayName,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.displayName),
                            ),
                            SmallListTile(
                              title: Language.inst.DURATION,
                              active: tracksSort == SortType.duration,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.duration),
                            ),
                            SmallListTile(
                              title: Language.inst.GENRES,
                              active: tracksSort == SortType.genresList,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.genresList),
                            ),
                            SmallListTile(
                              title: Language.inst.SAMPLE_RATE,
                              active: tracksSort == SortType.sampleRate,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.sampleRate),
                            ),
                            SmallListTile(
                              title: Language.inst.SIZE,
                              active: tracksSort == SortType.size,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.size),
                            ),
                            SmallListTile(
                              title: Language.inst.YEAR,
                              active: tracksSort == SortType.year,
                              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.year),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                if (isAlbumsPage) ...[
                  PopupMenuItem(
                    child: TextField(
                      decoration: InputDecoration(
                        constraints: const BoxConstraints(maxHeight: 56.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                        ),
                        hintText: Language.inst.FILTER_ALBUMS,
                      ),
                      onChanged: (value) {
                        Indexer.inst.searchAlbums(value);
                      },
                    ),
                  ),
                  PopupMenuItem(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    child: Obx(
                      () {
                        final albumsort = SettingsController.inst.albumSort.value;
                        return CustomSortByExpansionTile(
                          title: Language.inst.SORT_ALBUMS_BY,
                          children: [
                            ReverseOrderContainer(
                              active: SettingsController.inst.albumSortReversed.value,
                              onTap: () => Indexer.inst.sortAlbums(reverse: !SettingsController.inst.albumSortReversed.value),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM,
                              active: albumsort == GroupSortType.album,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.album),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM_ARTIST,
                              active: albumsort == GroupSortType.albumArtist,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.albumArtist),
                            ),
                            SmallListTile(
                              title: Language.inst.YEAR,
                              active: albumsort == GroupSortType.year,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.year),
                            ),
                            SmallListTile(
                              title: Language.inst.DATE_MODIFIED,
                              active: albumsort == GroupSortType.dateModified,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.dateModified),
                            ),
                            SmallListTile(
                              title: Language.inst.DURATION,
                              active: albumsort == GroupSortType.duration,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.duration),
                            ),
                            SmallListTile(
                              title: Language.inst.ARTISTS,
                              active: albumsort == GroupSortType.artistsList,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.artistsList),
                            ),
                            SmallListTile(
                              title: Language.inst.COMPOSER,
                              active: albumsort == GroupSortType.composer,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.composer),
                            ),
                            SmallListTile(
                              title: Language.inst.NUMBER_OF_TRACKS,
                              active: albumsort == GroupSortType.numberOfTracks,
                              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.numberOfTracks),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                // Artists Sort
                if (isArtistsPage) ...[
                  PopupMenuItem(
                    child: TextField(
                      decoration: InputDecoration(
                        constraints: const BoxConstraints(maxHeight: 56.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                        ),
                        hintText: Language.inst.FILTER_ARTISTS,
                      ),
                      onChanged: (value) {
                        Indexer.inst.searchArtists(value);
                      },
                    ),
                  ),
                  PopupMenuItem(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    child: Obx(
                      () {
                        final artistSort = SettingsController.inst.artistSort.value;
                        return CustomSortByExpansionTile(
                          title: Language.inst.SORT_ARTISTS_BY,
                          children: [
                            ReverseOrderContainer(
                              active: SettingsController.inst.artistSortReversed.value,
                              onTap: () => Indexer.inst.sortArtists(reverse: !SettingsController.inst.artistSortReversed.value),
                            ),
                            SmallListTile(
                              title: Language.inst.ARTISTS,
                              active: artistSort == GroupSortType.artistsList,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.artistsList),
                            ),
                            SmallListTile(
                              title: Language.inst.GENRES,
                              active: artistSort == GroupSortType.genresList,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.genresList),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM,
                              active: artistSort == GroupSortType.album,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.album),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM_ARTIST,
                              active: artistSort == GroupSortType.albumArtist,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.albumArtist),
                            ),
                            SmallListTile(
                              title: Language.inst.YEAR,
                              active: artistSort == GroupSortType.year,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.year),
                            ),
                            SmallListTile(
                              title: Language.inst.DATE_MODIFIED,
                              active: artistSort == GroupSortType.dateModified,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.dateModified),
                            ),
                            SmallListTile(
                              title: Language.inst.DURATION,
                              active: artistSort == GroupSortType.duration,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.duration),
                            ),
                            SmallListTile(
                              title: Language.inst.COMPOSER,
                              active: artistSort == GroupSortType.composer,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.composer),
                            ),
                            SmallListTile(
                              title: Language.inst.NUMBER_OF_TRACKS,
                              active: artistSort == GroupSortType.numberOfTracks,
                              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.numberOfTracks),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                // Genres Sort
                if (isGenresPage) ...[
                  PopupMenuItem(
                    child: TextField(
                      decoration: InputDecoration(
                        constraints: const BoxConstraints(maxHeight: 56.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                        ),
                        hintText: Language.inst.FILTER_GENRES,
                      ),
                      onChanged: (value) {
                        Indexer.inst.searchGenres(value);
                      },
                    ),
                  ),
                  PopupMenuItem(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    child: Obx(
                      () {
                        final genreSort = SettingsController.inst.genreSort.value;
                        return CustomSortByExpansionTile(
                          title: Language.inst.SORT_GENRES_BY,
                          children: [
                            ReverseOrderContainer(
                              active: SettingsController.inst.genreSortReversed.value,
                              onTap: () => Indexer.inst.sortGenres(reverse: !SettingsController.inst.genreSortReversed.value),
                            ),
                            SmallListTile(
                              title: Language.inst.GENRE,
                              active: genreSort == GroupSortType.genresList,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.genresList),
                            ),
                            SmallListTile(
                              title: Language.inst.DURATION,
                              active: genreSort == GroupSortType.duration,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.duration),
                            ),
                            SmallListTile(
                              title: Language.inst.NUMBER_OF_TRACKS,
                              active: genreSort == GroupSortType.numberOfTracks,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.numberOfTracks),
                            ),
                            SmallListTile(
                              title: Language.inst.ARTISTS,
                              active: genreSort == GroupSortType.artistsList,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.artistsList),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM,
                              active: genreSort == GroupSortType.album,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.album),
                            ),
                            SmallListTile(
                              title: Language.inst.ALBUM_ARTIST,
                              active: genreSort == GroupSortType.albumArtist,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.albumArtist),
                            ),
                            SmallListTile(
                              title: Language.inst.YEAR,
                              active: genreSort == GroupSortType.year,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.year),
                            ),
                            SmallListTile(
                              title: Language.inst.DATE_MODIFIED,
                              active: genreSort == GroupSortType.dateModified,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.dateModified),
                            ),
                            SmallListTile(
                              title: Language.inst.COMPOSER,
                              active: genreSort == GroupSortType.composer,
                              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.composer),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        InkWell(
          onTap: () {},
          child: const Icon(
            Broken.arrow_down_2,
            size: 20.0,
          ),
        ),
      ],
    );
  }
}

class SortByMenuTracks extends StatelessWidget {
  SortByMenuTracks({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          TextButton(
            child: Text(
              SettingsController.inst.tracksSort.value.toText,
            ),
            onPressed: () async => await showMenu(
              color: context.theme.appBarTheme.backgroundColor,
              context: context,
              position: RelativeRect.fromLTRB(Get.width, Get.statusBarHeight + 64.0, 20, 0),
              constraints: BoxConstraints(maxHeight: Get.height / 1.5),
              items: [
                PopupMenuItem(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  child: Obx(
                    () {
                      final tracksSort = SettingsController.inst.tracksSort.value;
                      return CustomSortByExpansionTile(
                        title: Language.inst.SORT_TRACKS_BY,
                        children: [
                          ReverseOrderContainer(
                            active: SettingsController.inst.tracksSortReversed.value,
                            onTap: () => Indexer.inst.sortTracks(reverse: !SettingsController.inst.tracksSortReversed.value),
                          ),
                          SmallListTile(
                            title: Language.inst.TITLE,
                            active: tracksSort == SortType.title,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.title),
                          ),
                          SmallListTile(
                            title: Language.inst.ALBUM,
                            active: tracksSort == SortType.album,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.album),
                          ),
                          SmallListTile(
                            title: Language.inst.ALBUM_ARTIST,
                            active: tracksSort == SortType.albumArtist,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.albumArtist),
                          ),
                          SmallListTile(
                            title: Language.inst.ARTISTS,
                            active: tracksSort == SortType.artistsList,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.artistsList),
                          ),
                          SmallListTile(
                            title: Language.inst.BITRATE,
                            active: tracksSort == SortType.bitrate,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.bitrate),
                          ),
                          SmallListTile(
                            title: Language.inst.COMPOSER,
                            active: tracksSort == SortType.composer,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.composer),
                          ),
                          SmallListTile(
                            title: Language.inst.DATE_MODIFIED,
                            active: tracksSort == SortType.dateModified,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.dateModified),
                          ),
                          SmallListTile(
                            title: Language.inst.DISC_NUMBER,
                            active: tracksSort == SortType.discNo,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.discNo),
                          ),
                          SmallListTile(
                            title: Language.inst.FILE_NAME,
                            active: tracksSort == SortType.displayName,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.displayName),
                          ),
                          SmallListTile(
                            title: Language.inst.DURATION,
                            active: tracksSort == SortType.duration,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.duration),
                          ),
                          SmallListTile(
                            title: Language.inst.GENRES,
                            active: tracksSort == SortType.genresList,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.genresList),
                          ),
                          SmallListTile(
                            title: Language.inst.SAMPLE_RATE,
                            active: tracksSort == SortType.sampleRate,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.sampleRate),
                          ),
                          SmallListTile(
                            title: Language.inst.SIZE,
                            active: tracksSort == SortType.size,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.size),
                          ),
                          SmallListTile(
                            title: Language.inst.YEAR,
                            active: tracksSort == SortType.year,
                            onTap: () => Indexer.inst.sortTracks(sortBy: SortType.year),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Indexer.inst.sortTracks(reverse: !SettingsController.inst.tracksSortReversed.value);
            },
            child: Icon(
              SettingsController.inst.tracksSortReversed.value ? Broken.arrow_up_3 : Broken.arrow_down_2,
              size: 20.0,
            ),
          ),
        ],
      ),
    );
  }
}

// class SortByMenuGlobal extends StatelessWidget {
//   final String text;
//   final String title;
//   final List<PopupMenuEntry<void>>? popupItems;
//   final List<Widget>? children;
//   final void Function()? onIconTap;
//   final bool isIconUpward;
//   const SortByMenuGlobal({super.key, required this.text, this.popupItems, this.children, required this.title, this.onIconTap, required this.isIconUpward});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         TextButton(
//           child: Text(
//             text,
//           ),
//           onPressed: () async => await showMenu(
//             color: context.theme.appBarTheme.backgroundColor,
//             context: context,
//             position: RelativeRect.fromLTRB(Get.width, Get.statusBarHeight + 64.0, 20, 0),
//             constraints: BoxConstraints(maxHeight: Get.height / 1.5),
//             items: popupItems ??
//                 [
//                   if (children != null)
//                     PopupMenuItem(
//                       padding: const EdgeInsets.symmetric(vertical: 0.0),
//                       child: CustomSortByExpansionTile(
//                         title: title,
//                         children: children!,
//                       ),
//                     ),
//                 ],
//           ),
//         ),
//         InkWell(
//           onTap: onIconTap,
//           child: Icon(
//             isIconUpward ? Broken.arrow_up_3 : Broken.arrow_down_2,
//             size: 20.0,
//           ),
//         ),
//       ],
//     );
//   }
// }
