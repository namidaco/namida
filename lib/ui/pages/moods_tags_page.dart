import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/subpages/moods_tags_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class MoodsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_moods;

  const MoodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MoodsOrTagsPage(
      MediaType.mood,
      route: route,
      icon: LibraryTab.moods.toIcon(),
      queueSource: QueueSource.moods,
      onItemTap: MoodsTracksSubPage.open,
      onItemLongPress: NamidaDialogs.inst.showMoodDialog,
    );
  }
}

class TagsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_tags;

  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MoodsOrTagsPage(
      MediaType.tag,
      route: route,
      icon: LibraryTab.tags.toIcon(),
      queueSource: QueueSource.tags,
      onItemTap: TagsTracksSubPage.open,
      onItemLongPress: NamidaDialogs.inst.showTagDialog,
    );
  }
}

class RatingsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_rating;

  const RatingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MoodsOrTagsPage(
      MediaType.rating,
      route: route,
      icon: LibraryTab.rating.toIcon(),
      queueSource: QueueSource.rating,
      onItemTap: RatingsTracksSubPage.open,
      onItemLongPress: NamidaDialogs.inst.showRatingDialog,
    );
  }
}

class _MoodsOrTagsPage extends StatefulWidget with NamidaRouteWidget {
  @override
  final RouteType route;
  final IconData icon;
  final MediaType type;
  final QueueSource Function(String name) queueSource;
  final void Function(String name, List<Track> tracks) onItemTap;
  final void Function(String name, List<Track> tracks) onItemLongPress;

  const _MoodsOrTagsPage(
    this.type, {
    required this.route,
    required this.icon,
    required this.queueSource,
    required this.onItemTap,
    required this.onItemLongPress,
  });

  @override
  State<_MoodsOrTagsPage> createState() => _MoodsOrTagsPageState();
}

class _MoodsOrTagsPageState extends State<_MoodsOrTagsPage> {
  var _allEntries = <MapEntry<String, List<Track>>>[];
  var _entries = <MapEntry<String, List<Track>>>[];
  late final _sortingRx = settings.groupSortingRxOf(widget.type);
  late final _libraryTab = widget.type.toLibraryTab();

  @override
  void initState() {
    _fillData();
    final sortingRx = _sortingRx;
    if (sortingRx != null) {
      final (sortsRx, reverseRx) = sortingRx;
      sortsRx.addListener(_onSortingChanged);
      reverseRx.addListener(_onSortingChanged);
    }
    super.initState();
  }

  @override
  void dispose() {
    final sortingRx = _sortingRx;
    if (sortingRx != null) {
      final (sortsRx, reverseRx) = sortingRx;
      sortsRx.removeListener(_onSortingChanged);
      reverseRx.removeListener(_onSortingChanged);
    }
    super.dispose();
  }

  void _fillData() {
    final allAvailableMap = switch (widget.type) {
      MediaType.tag => Indexer.inst.getTracksGroupedByTags(sort: false),
      MediaType.rating => Indexer.inst.getTracksGroupedByRatings(),
      _ => Indexer.inst.getTracksGroupedByMoods(sort: false),
    };
    _allEntries = allAvailableMap.entries.toFixedList();
    _sortEntries();
    final searchText = _libraryTab.textSearchController?.text ?? '';
    _filterEntries(searchText);
  }

  void _sortEntries() {
    if (_sortingRx == null) return;
    SearchSortController.inst.sortMoodsTagsEntries(widget.type, _allEntries);
  }

  void _filterEntries(String text) {
    _entries = text.isEmpty ? _allEntries : SearchSortController.inst.filterMoodsTagsEntries(_allEntries, text);
  }

  void _onSortingChanged() {
    _sortEntries();
    final searchText = _libraryTab.textSearchController?.text ?? '';
    _filterEntries(searchText);
    setState(() {});
  }

  void _onSearchChanged(String text) {
    _filterEntries(text);
    setState(() {});
  }

  void _onSearchClosed() {
    ScrollSearchController.inst.clearSearchTextField(_libraryTab);
    _onSearchChanged('');
  }

  String _countText(int count) => widget.type == MediaType.tag ? lang.countTags(count: count) : lang.countMoods(count: count);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final type = widget.type;
    final libraryTab = _libraryTab;
    final scrollController = libraryTab.scrollController;
    final entries = _entries;
    final entriesLength = entries.length;
    final allEntriesLength = _allEntries.length;

    String? Function(String name, List<Track> tracks)? extraTextResolver;
    Widget? header;
    final sortingRx = _sortingRx;
    if (sortingRx != null) {
      final (sortsRx, reverseRx) = sortingRx;
      final sort = sortsRx.value.first;
      final sortReverse = reverseRx.value;
      final sortTextIsUseless = sort == GroupSortType.title || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration;
      extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getMoodsTagsExtraTextResolver(type, sort);
      final leftText = entriesLength != allEntriesLength ? '$entriesLength/${_countText(allEntriesLength)}' : _countText(entriesLength);
      final hintText = type == MediaType.tag ? lang.filterTags : lang.filterMoods;
      header = Obx(
        (context) => ExpandableBox(
          enableHero: false,
          isBarVisible: libraryTab.isBarVisible.valueR,
          leftText: leftText,
          onSearchBoxVisibilityChange: (newShow) => ScrollSearchController.inst.onSearchBoxVisibiltyChange(libraryTab, newShow),
          onCloseButtonPressed: _onSearchClosed,
          sortByMenuWidget: SortByMenu(
            title: sort.toText(),
            popupMenuChild: SortByMenuMoodsTags(type),
            isCurrentlyReversed: sortReverse,
            onReverseIconTap: () => SearchSortController.inst.sortMedia(type, reverse: !sortReverse),
          ),
          textField: CustomTextField(
            textFieldController: libraryTab.textSearchControllerR,
            textFieldHintText: hintText,
            onTextFieldValueChanged: _onSearchChanged,
          ),
        ),
      );
    }

    final listWidget = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: ExpandableBoxEmptyAnimatedPadding(tab: libraryTab),
        ),
        SuperSliverList.builder(
          itemCount: entriesLength,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final name = entry.key;
            final tracks = entry.value;
            final extraText = extraTextResolver?.call(name, tracks)?.nullifyEmpty();
            final subtitle = [
              tracks.length.displayTrackKeyword,
              tracks.totalDurationFormatted,
              ?extraText,
            ].join(' - ');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
              child: NamidaInkWell(
                borderRadius: 10.0,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                bgColor: theme.cardColor,
                onTap: () => widget.onItemTap(name, tracks),
                onLongPress: () => widget.onItemLongPress(name, tracks),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const SizedBox(width: 12.0),
                    Icon(
                      widget.icon,
                      size: 22.0,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        mainAxisAlignment: .start,
                        children: [
                          Text(
                            name,
                            style: textTheme.displayMedium,
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: textTheme.displaySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    NamidaIconButton(
                      horizontalPadding: 6.0,
                      icon: Broken.play,
                      iconSize: 20.0,
                      onPressed: () {
                        Player.inst.playOrPause(
                          0,
                          tracks,
                          widget.queueSource(name),
                        );
                      },
                    ),
                    NamidaIconButton(
                      horizontalPadding: 6.0,
                      icon: Broken.shuffle,
                      iconSize: 20.0,
                      onPressed: () {
                        Player.inst.playOrPause(
                          0,
                          tracks,
                          widget.queueSource(name),
                          shuffle: true,
                        );
                      },
                    ),
                    IgnorePointer(
                      child: NamidaIconButton(
                        horizontalPadding: 6.0,
                        icon: Broken.arrow_right_3,
                        iconSize: 20.0,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                  ],
                ),
              ),
            );
          },
        ),
        kBottomPaddingWidgetSliver,
      ],
    );

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: Column(
          children: [
            ?header,
            Expanded(
              child: listWidget,
            ),
          ],
        ),
      ),
    );
  }
}
