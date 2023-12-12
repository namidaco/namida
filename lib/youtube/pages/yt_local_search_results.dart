import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YTLocalSearchResults extends StatefulWidget {
  final String initialSearch;
  final void Function(StreamInfoItem video)? onVideoTap;
  final void Function(bool didChangeSort) onPopping;
  const YTLocalSearchResults({super.key, this.initialSearch = '', this.onVideoTap, required this.onPopping});

  @override
  State<YTLocalSearchResults> createState() => YTLocalSearchResultsState();
}

class YTLocalSearchResultsState extends State<YTLocalSearchResults> {
  @override
  void initState() {
    super.initState();
    YTLocalSearchController.inst.scrollController = ScrollController();
    YTLocalSearchController.inst.search(widget.initialSearch, maxResults: null);
  }

  List<StreamInfoItem> get _searchResultsLocal => YTLocalSearchController.inst.searchResults;

  bool _didChangeSort = false;

  Widget getChipButton({
    required BuildContext context,
    required YTLocalSearchSortType sort,
    required String title,
    required IconData icon,
    required bool Function(YTLocalSearchSortType sort) enabled,
  }) {
    return NamidaInkWell(
      animationDurationMS: 100,
      borderRadius: 8.0,
      bgColor: context.theme.cardTheme.color,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: enabled(sort) ? Border.all(color: context.theme.colorScheme.primary) : null,
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
      ),
      onTap: () {
        setState(() => YTLocalSearchController.inst.sortType = sort);
        _didChangeSort = true;
      },
      child: Row(
        children: [
          Icon(icon, size: 18.0),
          const SizedBox(width: 4.0),
          Text(
            title,
            style: context.textTheme.displayMedium,
          ),
          const SizedBox(width: 4.0),
          const Icon(Broken.arrow_down_2, size: 14.0),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailWidth = context.width * 0.32;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    final thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: YTLocalSearchController.inst.scrollController,
        child: CustomScrollView(
          controller: YTLocalSearchController.inst.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 34.0,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          NamidaNavigator.inst.popPage();
                          widget.onPopping(_didChangeSort);
                        },
                        icon: const Icon(Broken.arrow_left_2),
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
                        sort: YTLocalSearchSortType.mostPlayed,
                        title: lang.MOST_PLAYED,
                        icon: Broken.medal,
                        enabled: (sort) => sort == YTLocalSearchController.inst.sortType,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverFixedExtentList.builder(
              itemExtent: thumbnailItemExtent,
              itemCount: _searchResultsLocal.length,
              itemBuilder: (context, index) {
                final item = _searchResultsLocal[index];
                return YoutubeVideoCard(
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
    );
  }
}
