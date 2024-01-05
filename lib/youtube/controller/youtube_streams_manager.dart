import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

enum YTVideosSorting {
  date,
  views,
  duration,
}

mixin YoutubeStreamsManager {
  List<StreamInfoItem> get streamsList;
  ScrollController get scrollController;
  BuildContext get context;
  Color? get sortChipBGColor;
  void onSortChanged(void Function() fn);

  void disposeResources() {
    sorting.close();
    sortingByTop.close();
  }

  late final _defaultSorting = YTVideosSorting.date;
  late final _defaultSortingByTop = true;
  late final sorting = _defaultSorting.obs;
  late final sortingByTop = _defaultSortingByTop.obs;

  Widget get sortWidget => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ...YTVideosSorting.values.map(
                (e) {
                  final details = sortToTextAndIcon(e);
                  final enabled = sorting.value == e;
                  final itemsColor = enabled ? Colors.white.withOpacity(0.8) : null;
                  return NamidaInkWell(
                    animationDurationMS: 200,
                    borderRadius: 6.0,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    margin: const EdgeInsets.symmetric(horizontal: 3.0),
                    bgColor: enabled ? sortChipBGColor : context.theme.cardColor,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        enabled
                            ? Obx(
                                () => StackedIcon(
                                  baseIcon: details.$2,
                                  secondaryIcon: sortingByTop.value ? Broken.arrow_down_2 : Broken.arrow_up_3,
                                  iconSize: 20.0,
                                  secondaryIconSize: 10.0,
                                  blurRadius: 4.0,
                                  baseIconColor: itemsColor,
                                  // secondaryIconColor: enabled ? context.theme.colorScheme.background : null,
                                ),
                              )
                            : Icon(
                                details.$2,
                                size: 20.0,
                                color: null,
                              ),
                        const SizedBox(width: 4.0),
                        Text(
                          details.$1,
                          style: context.textTheme.displayMedium?.copyWith(color: itemsColor),
                        ),
                      ],
                    ),
                    onTap: () => onSortChanged(
                      () => sortStreams(sort: e, sortingByTop: enabled ? !sortingByTop.value : null),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
  void trySortStreams() {
    if (sorting.value != _defaultSorting || sortingByTop.value != _defaultSortingByTop) {
      sortStreams(jumpToZero: false);
    }
  }

  void sortStreams({List<StreamInfoItem>? streams, YTVideosSorting? sort, bool? sortingByTop, bool jumpToZero = true}) {
    sort ??= sorting.value;
    streams ??= streamsList;
    sortingByTop ??= this.sortingByTop.value;
    switch (sort) {
      case YTVideosSorting.date:
        sortingByTop ? streams.sortByReverse((e) => e.date ?? DateTime(0)) : streams.sortBy((e) => e.date ?? DateTime(0));
        break;

      case YTVideosSorting.views:
        sortingByTop ? streams.sortByReverse((e) => e.viewCount ?? 0) : streams.sortBy((e) => e.viewCount ?? 0);
        break;

      case YTVideosSorting.duration:
        sortingByTop ? streams.sortByReverse((e) => e.duration ?? Duration.zero) : streams.sortBy((e) => e.duration ?? Duration.zero);
        break;

      default:
        null;
    }
    sorting.value = sort;
    this.sortingByTop.value = sortingByTop;

    if (jumpToZero && scrollController.hasClients) scrollController.jumpTo(0);
  }

  (String, IconData) sortToTextAndIcon(YTVideosSorting sort) {
    switch (sort) {
      case YTVideosSorting.date:
        return (lang.DATE, Broken.calendar);
      case YTVideosSorting.views:
        return (lang.VIEWS, Broken.eye);
      case YTVideosSorting.duration:
        return (lang.DURATION, Broken.timer_1);
    }
  }
}
