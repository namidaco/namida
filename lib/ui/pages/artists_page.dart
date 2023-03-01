import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class ArtistsPage extends StatelessWidget {
  ArtistsPage({super.key});
  final ScrollController _scrollController = ScrollSearchController.inst.artistScrollcontroller.value;
  final gridCount = SettingsController.inst.artistGridCount.value;
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
                  currentCount: SettingsController.inst.artistGridCount.value,
                  onTap: () {
                    final n = SettingsController.inst.artistGridCount.value;
                    if (n < 4) {
                      SettingsController.inst.save(artistGridCount: n + 1);
                    } else {
                      SettingsController.inst.save(artistGridCount: 1);
                    }
                  },
                ),
                isBarVisible: ScrollSearchController.inst.isArtistBarVisible.value,
                showSearchBox: ScrollSearchController.inst.showArtistSearchBox.value,
                leftText: Indexer.inst.artistSearchList.length.displayArtistKeyword,
                onFilterIconTap: () => ScrollSearchController.inst.switchArtistSearchBoxVisibilty(),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearArtistSearchTextField();
                },
                sortByMenuWidget: SortByMenu(
                  title: SettingsController.inst.artistSort.value.toText,
                  popupMenuChild: const SortByMenuArtists(),
                  isCurrentlyReversed: SettingsController.inst.artistSortReversed.value,
                  onReverseIconTap: () {
                    Indexer.inst.sortArtists(reverse: !SettingsController.inst.artistSortReversed.value);
                  },
                ),
                textField: CustomTextFiled(
                  textFieldController: Indexer.inst.artistsSearchController.value,
                  textFieldHintText: Language.inst.FILTER_ARTISTS,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchArtists(value),
                ),
              ),
              if (gridCount == 1)
                Expanded(
                  child: Obx(
                    () => ListView.builder(
                      controller: _scrollController,
                      itemCount: Indexer.inst.artistSearchList.length,
                      padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                      itemBuilder: (BuildContext context, int i) {
                        final artist = Indexer.inst.artistSearchList.entries.toList()[i];
                        return AnimationConfiguration.staggeredList(
                          position: i,
                          duration: const Duration(milliseconds: 400),
                          child: SlideAnimation(
                            verticalOffset: 25.0,
                            child: FadeInAnimation(
                              duration: const Duration(milliseconds: 400),
                              child: ArtistTile(
                                tracks: artist.value.toList(),
                                name: artist.key,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (gridCount > 1)
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCount,
                      childAspectRatio: 0.88,
                      mainAxisSpacing: 8.0,
                      // crossAxisSpacing: 4.0,
                    ),
                    controller: _scrollController,
                    itemCount: Indexer.inst.artistSearchList.length,
                    padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                    itemBuilder: (BuildContext context, int i) {
                      final artist = Indexer.inst.artistSearchList.entries.toList()[i];
                      return AnimationConfiguration.staggeredGrid(
                        columnCount: Indexer.inst.artistSearchList.length,
                        position: i,
                        duration: const Duration(milliseconds: 400),
                        child: SlideAnimation(
                          verticalOffset: 25.0,
                          child: FadeInAnimation(
                            duration: const Duration(milliseconds: 400),
                            child: ArtistCard(
                              name: artist.key,
                              artist: artist.value.toList(),
                              gridCount: gridCount,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtistTracksPage extends StatelessWidget {
  final String name;
  ArtistTracksPage({super.key, required this.name});
  @override
  Widget build(BuildContext context) {
    final artist = Indexer.inst.artistSearchList[name]!.toList();
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Broken.arrow_left_2)),
          title: Text(
            name,
            style: context.textTheme.displayLarge,
          ),
        ),
        body: ListView(
          children: [
            // Top Container holding image and info and buttons
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24.0),
              height: Get.width / 2.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    ),
                    width: 140,
                    child: Hero(
                      tag: 'artist$name',
                      child: ArtworkWidget(
                        thumnailSize: 60,
                        track: artist.elementAt(0),
                        compressed: false,
                        // size: (SettingsController.inst.albumThumbnailSizeinList.value * 2).round(),

                        // borderRadiusValue: 8.0,
                        forceSquared: SettingsController.inst.forceSquaredAlbumThumbnail.value,
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
                            name,
                            style: context.textTheme.displayLarge,
                          ),
                        ),
                        const SizedBox(
                          height: 2.0,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Text(
                            [artist.displayTrackKeyword, if (artist.isNotEmpty) artist.totalDurationFormatted].join(' - '),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: context.textTheme.displayMedium?.copyWith(fontSize: 14.0.multipliedFontScale),
                          ),
                        ),
                        const SizedBox(
                          height: 18.0,
                        ),
                        Row(
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
            ...artist
                .asMap()
                .entries
                .map((track) => TrackTile(
                      track: track.value,
                    ))
                .toList()
          ],
        ),
      ),
    );
  }
}
