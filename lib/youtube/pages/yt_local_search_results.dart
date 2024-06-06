import 'package:flutter/material.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
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
  final _searchListenerKey = "YTLocalSearchResultsState";

  @override
  void initState() {
    super.initState();
    YTLocalSearchController.inst.addOnSearchStart(_searchListenerKey, () => _updateIsSearching(true));
    YTLocalSearchController.inst.addOnSearchDone(_searchListenerKey, (_) => _updateIsSearching(false));

    YTLocalSearchController.inst.scrollController = ScrollController();
    YTLocalSearchController.inst.search(widget.initialSearch, maxResults: null);
  }

  @override
  void dispose() {
    YTLocalSearchController.inst.removeOnSearchStart(_searchListenerKey);
    YTLocalSearchController.inst.removeOnSearchDone(_searchListenerKey);
    super.dispose();
  }

  void _updateIsSearching(bool searching) {
    if (mounted) {
      setState(() => _isSearching = searching);
    } else {
      _isSearching = searching;
    }
  }

  List<StreamInfoItem> get _searchResultsLocal => YTLocalSearchController.inst.searchResults;

  bool _didChangeSort = false;
  bool? _isSearching;

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
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
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
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 32.0,
                            width: 32.0,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                NamidaNavigator.inst.popPage();
                                widget.onPopping(_didChangeSort);
                              },
                              icon: Obx(
                                () => Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (YTLocalSearchController.inst.didLoadLookupLists.valueR == false)
                                      IgnorePointer(
                                        child: NamidaOpacity(
                                          opacity: 0.3,
                                          child: ThreeArchedCircle(
                                            color: context.defaultIconColor(),
                                            size: 36.0,
                                          ),
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
            _isSearching == null
                ? const SliverToBoxAdapter()
                : _isSearching == true
                    ? SliverToBoxAdapter(
                        child: ShimmerWrapper(
                          transparent: false,
                          shimmerEnabled: true,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 10,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return const YoutubeVideoCard(
                                fontMultiplier: 0.9,
                                thumbnailHeight: thumbnailHeight,
                                thumbnailWidth: thumbnailWidth,
                                isImageImportantInCache: false,
                                video: null,
                                playlistID: null,
                                onTap: null,
                              );
                            },
                          ),
                        ),
                      )
                    : SliverFixedExtentList.builder(
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
