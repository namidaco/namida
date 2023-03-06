import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
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
                      padding: const EdgeInsets.only(bottom: kBottomPadding),
                      itemBuilder: (BuildContext context, int i) {
                        final artist = Indexer.inst.artistSearchList.entries.toList()[i];
                        return AnimatingTile(
                          position: i,
                          child: ArtistTile(
                            tracks: artist.value.toList(),
                            name: artist.key,
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
                    ),
                    controller: _scrollController,
                    itemCount: Indexer.inst.artistSearchList.length,
                    padding: const EdgeInsets.only(bottom: kBottomPadding),
                    itemBuilder: (BuildContext context, int i) {
                      final artist = Indexer.inst.artistSearchList.entries.toList()[i];
                      return AnimatingGrid(
                        columnCount: Indexer.inst.artistSearchList.length,
                        position: i,
                        child: ArtistCard(
                          name: artist.key,
                          artist: artist.value.toList(),
                          gridCount: gridCount,
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
