import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/subpages/moods_tags_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MoodsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_moods;

  const MoodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MoodsOrTagsPage(
      _FilterType.moods,
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
      _FilterType.tags,
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
      _FilterType.rating,
      route: route,
      icon: LibraryTab.rating.toIcon(),
      queueSource: QueueSource.rating,
      onItemTap: RatingsTracksSubPage.open,
      onItemLongPress: NamidaDialogs.inst.showRatingDialog,
    );
  }
}

enum _FilterType { moods, tags, rating }

class _MoodsOrTagsPage extends StatefulWidget with NamidaRouteWidget {
  @override
  final RouteType route;
  final IconData icon;
  final _FilterType type;
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
  var _allAvailableMap = <String, List<Track>>{};
  var _items = <String>[];

  @override
  void initState() {
    _fillData();
    super.initState();
  }

  void _fillData() {
    _allAvailableMap = switch (widget.type) {
      _FilterType.moods => Indexer.inst.getTracksGroupedByMoods(),
      _FilterType.tags => Indexer.inst.getTracksGroupedByTags(),
      _FilterType.rating => Indexer.inst.getTracksGroupedByRatings(),
    };
    _items = _allAvailableMap.keys.toFixedList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;

    return BackgroundWrapper(
      child: SuperSmoothListView.builder(
        padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotalR + 8.0),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final name = _items[index];
          final tracks = _allAvailableMap[name] ?? [];
          final subtitle = [
            tracks.length.displayTrackKeyword,
            tracks.totalDurationFormatted,
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
    );
  }
}
