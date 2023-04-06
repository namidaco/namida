import 'package:flutter/cupertino.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/group.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class ArtistsPage extends StatelessWidget {
  final List<Group>? artists;
  ArtistsPage({super.key, this.artists});
  final ScrollController _scrollController = ScrollSearchController.inst.artistScrollcontroller;
  final gridCount = SettingsController.inst.artistGridCount.value;
  @override
  Widget build(BuildContext context) {
    final finalArtists = artists ?? Indexer.inst.artistSearchList;
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Column(
          children: [
            Obx(
              () => ExpandableBox(
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
                leftText: finalArtists.length.displayArtistKeyword,
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
                  textFieldController: Indexer.inst.artistsSearchController,
                  textFieldHintText: Language.inst.FILTER_ARTISTS,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchArtists(value),
                ),
              ),
            ),
            if (gridCount == 1)
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    controller: _scrollController,
                    itemCount: finalArtists.length,
                    padding: const EdgeInsets.only(bottom: kBottomPadding),
                    itemExtent: 65.0 + 2.0 * 9,
                    itemBuilder: (BuildContext context, int i) {
                      final artist = finalArtists[i];
                      return AnimatingTile(
                        position: i,
                        child: ArtistTile(
                          tracks: artist.tracks.toList(),
                          name: artist.name,
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (gridCount > 1)
              Expanded(
                child: Obx(
                  () => GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCount,
                      childAspectRatio: 0.88,
                      mainAxisSpacing: 8.0,
                    ),
                    controller: _scrollController,
                    itemCount: finalArtists.length,
                    padding: const EdgeInsets.only(bottom: kBottomPadding),
                    itemBuilder: (BuildContext context, int i) {
                      final artist = finalArtists[i];
                      return AnimatingGrid(
                        columnCount: finalArtists.length,
                        position: i,
                        child: ArtistCard(
                          name: artist.name,
                          artist: artist.tracks,
                          gridCount: gridCount,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
