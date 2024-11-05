import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

mixin HistoryDaysRebuilderMixin<T extends StatefulWidget, E extends ItemWithDate, S> on State<T> {
  HistoryManager<E, S> get historyManager;

  Iterable<E> getHistoryTracks(Map<int, List<E>> history) sync* {
    final map = history;
    for (final trs in map.values) {
      yield* trs;
    }
  }

  int dayToMillis(int day) => day * 24 * 60 * 60 * 1000;

  List<int> _listifyHistoryDays() => historyManager.historyMap.value.keys.toList();

  late List<int> historyDays = _listifyHistoryDays();

  void _updateDays() {
    if (mounted) {
      setState(() {
        historyDays = _listifyHistoryDays();
      });
    }
  }

  @override
  void initState() {
    historyManager.modifiedDays.addListener(_updateDays);
    super.initState();
  }

  @override
  void dispose() {
    historyManager.modifiedDays.removeListener(_updateDays);
    super.dispose();
  }

  Widget? listenOrderWidget(ItemWithDate watch, S subitem, TextStyle? smallTextStyle) {
    final listens = historyManager.topTracksMapListens[subitem];
    Widget? topRightWidget;
    if (listens != null) {
      final listensLength = listens.length;
      final watchMS = watch.dateAddedMS;
      if (listensLength > 1) {
        final firstListen = listens.firstOrNull;
        if (watchMS == firstListen) {
          topRightWidget = const Icon(
            Broken.cake,
            size: 12.0,
          );
        } else {
          final watchOrder = listens.indexOf(watchMS) + 1;
          topRightWidget = Text(
            '$watchOrder',
            style: smallTextStyle,
          );
        }
      }
    }

    if (topRightWidget != null) {
      topRightWidget = NamidaBlurryContainer(
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6.0.multipliedRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: topRightWidget,
      );
    }
    return topRightWidget;
  }
}
