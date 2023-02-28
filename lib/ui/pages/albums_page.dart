import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/album_tile.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class AlbumsPage extends StatelessWidget {
  final Map<String?, Set<Track>>? albums;
  AlbumsPage({super.key, this.albums});
  final ScrollController _scrollController = ScrollSearchController.inst.albumScrollcontroller.value;
  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () => Column(
            children: [
              ExpandableBox(
                gridWidget: ChangeGridCountWidget(
                  currentCount: SettingsController.inst.albumGridCount.value,
                  forStaggered: SettingsController.inst.useAlbumStaggeredGridView.value,
                  onTap: () {
                    final n = SettingsController.inst.albumGridCount.value;
                    if (n < 4) {
                      SettingsController.inst.save(albumGridCount: n + 1);
                    } else {
                      SettingsController.inst.save(albumGridCount: 1);
                    }
                  },
                ),
                isBarVisible: ScrollSearchController.inst.isAlbumBarVisible.value,
                showSearchBox: ScrollSearchController.inst.showAlbumSearchBox.value,
                leftText: Indexer.inst.albumSearchList.length.displayAlbumKeyword,
                onFilterIconTap: () => ScrollSearchController.inst.switchAlbumSearchBoxVisibilty(),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearAlbumSearchTextField();
                },
                sortByMenuWidget: SortByMenu(
                  title: SettingsController.inst.albumSort.value.toText,
                  popupMenuChild: const SortByMenuAlbums(),
                  isCurrentlyReversed: SettingsController.inst.albumSortReversed.value,
                  onReverseIconTap: () {
                    Indexer.inst.sortAlbums(reverse: !SettingsController.inst.albumSortReversed.value);
                  },
                ),
                textField: CustomTextFiled(
                  textFieldController: Indexer.inst.albumsSearchController.value,
                  textFieldHintText: Language.inst.FILTER_ALBUMS,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchAlbums(value),
                ),
              ),
              Obx(
                () {
                  return SettingsController.inst.albumGridCount.value == 1
                      ? Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                            padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                            itemBuilder: (BuildContext context, int i) {
                              return AnimationConfiguration.staggeredList(
                                position: i,
                                duration: const Duration(milliseconds: 400),
                                child: SlideAnimation(
                                  verticalOffset: 25.0,
                                  child: FadeInAnimation(
                                    duration: const Duration(milliseconds: 400),
                                    child: AlbumTile(
                                      album: (albums ?? Indexer.inst.albumSearchList).entries.toList()[i].value.toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Expanded(
                          child: MasonryGridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0).add(EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value)),
                            itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                            mainAxisSpacing: 8.0,
                            crossAxisSpacing: 6.0,
                            gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: SettingsController.inst.albumGridCount.value),
                            itemBuilder: (context, i) {
                              final album = (albums ?? Indexer.inst.albumSearchList).entries.toList()[i].value.toList();
                              return AnimationConfiguration.staggeredList(
                                position: i,
                                duration: const Duration(milliseconds: 400),
                                child: SlideAnimation(
                                  verticalOffset: 25.0,
                                  child: FadeInAnimation(
                                    duration: const Duration(milliseconds: 400),
                                    child: AlbumCard(album: album),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumTracksPage extends StatelessWidget {
  final List<Track> album;
  const AlbumTracksPage({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    // final AlbumTracksController albumtracksc = AlbumTracksController(album);
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Broken.arrow_left_2)),
          title: Text(
            album[0].album,
            style: context.textTheme.displayLarge,
          ),
        ),
        body: ListView(
          // cacheExtent: 1000,
          children: [
            // Top Container holding image and info and buttons
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24.0),
              height: Get.width / 2.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'album_artwork_${album[0].path}',
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                      ),
                      width: 140,
                      height: 140,
                      child: ArtworkWidget(
                        thumnailSize: SettingsController.inst.albumThumbnailSizeinList.value,
                        forceSquared: SettingsController.inst.forceSquaredAlbumThumbnail.value,
                        track: album[0],
                        compressed: false,
                        // size: (SettingsController.inst.albumThumbnailSizeinList.value * 2).round(),

                        borderRadius: 8.0,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 18.0,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 18.0,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Text(
                            album[0].album,
                            style: context.textTheme.displayLarge,
                          ),
                        ),
                        const SizedBox(
                          height: 2.0,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Text(
                            [album.displayTrackKeyword, if (album.isNotEmpty) album.totalDurationFormatted].join(' - '),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: context.textTheme.displayMedium?.copyWith(fontSize: 14.0.multipliedFontScale),
                          ),
                        ),
                        const SizedBox(
                          height: 18.0,
                        ),
                        Row(
                          // mainAxisAlignment:
                          //     MainAxisAlignment.spaceEvenly,
                          children: [
                            const Spacer(),
                            FittedBox(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Playback.instance.open(
                                  //   [...widget.playlist.tracks]..shuffle(),
                                  // );
                                },
                                child: const Icon(Broken.shuffle),
                              ),
                            ),
                            const Spacer(),
                            FittedBox(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Playback.instance.open(
                                  //   [
                                  //     ...widget.playlist.tracks,
                                  //     if (Configuration.instance.seamlessPlayback) ...[...Collection.instance.tracks]..shuffle()
                                  //   ],
                                  // );
                                },
                                child: Row(
                                  children: [
                                    const Icon(Broken.play),
                                    const SizedBox(
                                      width: 8.0,
                                    ),
                                    Text(Language.inst.PLAY_ALL),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            ...album
                .asMap()
                .entries
                .map((track) => TrackTile(
                      track: track.value,
                      queue: album,
                    ))
                .toList()
          ],
        ),
      ),
    );
  }
}
