import 'package:flutter/material.dart';

import 'package:youtipie/class/stream_info_item/stream_info_item.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YTLocalSearchResults extends StatefulWidget {
  final String initialSearch;
  final void Function(StreamInfoItem video)? onVideoTap;
  const YTLocalSearchResults({super.key, this.initialSearch = '', this.onVideoTap});

  @override
  State<YTLocalSearchResults> createState() => YTLocalSearchResultsState();
}

class YTLocalSearchResultsState extends State<YTLocalSearchResults> {
  @override
  void initState() {
    super.initState();
    NamidaNavigator.inst.isytLocalSearchInFullPage = true;

    YTLocalSearchController.inst.scrollController?.dispose();
    YTLocalSearchController.inst.scrollController = NamidaScrollController.create();

    Future(() => YTLocalSearchController.inst.search(widget.initialSearch));
  }

  @override
  void dispose() {
    NamidaNavigator.inst.isytLocalSearchInFullPage = false;
    super.dispose();
  }

  Widget getChipButton({
    required BuildContext context,
    required YTLocalSearchSortType sort,
    required String title,
    required IconData icon,
    required bool Function(YTLocalSearchSortType sort) enabled,
  }) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final isEnabled = enabled(sort);
    return NamidaInkWell(
      animationDurationMS: 100,
      borderRadius: 8.0,
      bgColor: theme.cardTheme.color,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: isEnabled ? Border.all(color: theme.colorScheme.primary) : null,
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
      ),
      onTap: () {
        setState(() => YTLocalSearchController.inst.sortType = sort);
        final sc = YTLocalSearchController.inst.scrollController;
        if (sc != null && sc.hasClients) sc.jumpTo(0);
      },
      child: Row(
        children: [
          Icon(icon, size: 18.0),
          const SizedBox(width: 4.0),
          Text(
            title,
            style: textTheme.displayMedium,
          ),
          const SizedBox(width: 4.0),
          const Icon(Broken.arrow_down_2, size: 14.0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    return BackgroundWrapper(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 34.0,
              child: SuperSmoothListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 32.0,
                        width: 32.0,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: NamidaNavigator.inst.popPage,
                          icon: Obx(
                            (context) => Stack(
                              alignment: Alignment.center,
                              children: [
                                if (YTLocalSearchController.inst.didLoadLookupLists.valueR == false)
                                  IgnorePointer(
                                    child: ThreeArchedCircle(
                                      color: context.defaultIconColor().withValues(alpha: 0.3),
                                      size: 36.0,
                                    ),
                                  ),
                                const Icon(Broken.arrow_left_2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8.0),
                  getChipButton(
                    context: context,
                    sort: YTLocalSearchSortType.mostPlayed,
                    title: lang.MOST_PLAYED,
                    icon: Broken.medal,
                    enabled: (sort) => sort == YTLocalSearchController.inst.sortType,
                  ),
                  const SizedBox(width: 8.0),
                  getChipButton(
                    context: context,
                    sort: YTLocalSearchSortType.latestPlayed,
                    title: lang.RECENT_LISTENS,
                    icon: Broken.timer,
                    enabled: (sort) => sort == YTLocalSearchController.inst.sortType,
                  ),
                  const SizedBox(width: 8.0),
                  getChipButton(
                    context: context,
                    sort: YTLocalSearchSortType.firstListen,
                    title: lang.FIRST_LISTEN,
                    icon: Broken.calendar_search,
                    enabled: (sort) => sort == YTLocalSearchController.inst.sortType,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: VideoTilePropertiesProvider(
              configs: VideoTilePropertiesConfigs(
                queueSource: QueueSourceYoutubeID.search,
                showMoreIcon: true,
              ),
              builder: (properties) => NamidaScrollbar(
                controller: YTLocalSearchController.inst.scrollController,
                child: ObxO(
                  rx: YTLocalSearchController.inst.searchResults,
                  builder: (context, searchResults) => SmoothCustomScrollView(
                    controller: YTLocalSearchController.inst.scrollController,
                    slivers: [
                      searchResults == null
                          ? SliverToBoxAdapter(
                              child: ShimmerWrapper(
                                transparent: false,
                                shimmerEnabled: true,
                                child: SuperSmoothListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 10,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    return const YoutubeVideoCardDummy(
                                      shimmerEnabled: true,
                                      fontMultiplier: 0.9,
                                      thumbnailHeight: thumbnailHeight,
                                      thumbnailWidth: thumbnailWidth,
                                    );
                                  },
                                ),
                              ),
                            )
                          : searchResults.isEmpty
                              ? const SliverToBoxAdapter()
                              : SliverFixedExtentList.builder(
                                  itemExtent: thumbnailItemExtent,
                                  itemCount: searchResults.length,
                                  itemBuilder: (context, index) {
                                    final item = searchResults[index];
                                    return YoutubeVideoCard(
                                      properties: properties,
                                      fontMultiplier: 0.9,
                                      thumbnailHeight: thumbnailHeight,
                                      thumbnailWidth: thumbnailWidth,
                                      isImageImportantInCache: false,
                                      video: item,
                                      playlistID: null,
                                      onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item),
                                    );
                                  },
                                ),
                      kBottomPaddingWidgetSliver,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
