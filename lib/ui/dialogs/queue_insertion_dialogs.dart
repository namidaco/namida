import 'package:flutter/material.dart';

import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showAdvancedPlayDialog(Iterable<Selectable> Function() tracksFn, QueueSourceBase source) {
  const type = QueueInsertionType.advancedPlay;
  final minimumCounter = _TrackMinimumCounter(tracksFn);

  List<Selectable> buildTracks() => type.toQueueInsertion().apply(tracksFn().toList());

  final playAfterTrack = _playAfterTrack();

  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      title: lang.play,
      child: Column(
        children: [
          const SizedBox(height: 12.0),
          ObxO(
            rx: settings.queueInsertion,
            builder: (context, _) => _QueueInsertionTiles(
              insertion: type.toQueueInsertion(),
              onChanged: (insertion) => settings.queueInsertion.update((insertions) => insertions[type] = insertion),
              minimumCounter: minimumCounter,
              maxTracksCount: minimumCounter.totalCount(),
              showInsertNext: false,
              shuffleLocked: false,
              forYoutube: false,
            ),
          ),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0)),
          CustomListTile(
            icon: Broken.play,
            title: lang.play,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              Player.inst.playOrPause(0, buildTracks(), source);
            },
          ),
          CustomListTile(
            icon: Broken.next,
            title: lang.playNext,
            onTap: () {
              Player.inst.addToQueue(buildTracks(), insertNext: true);
              NamidaNavigator.inst.closeDialog();
            },
          ),
          if (playAfterTrack != null)
            CustomListTile(
              icon: Broken.hierarchy_square,
              title: lang.playAfter,
              subtitle: [playAfterTrack.artistsList.firstOrNull, playAfterTrack.title].joinText(separator: ' - '),
              onTap: () {
                Player.inst.addToQueue(buildTracks(), insertAfterLatest: true);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          CustomListTile(
            icon: Broken.play_cricle,
            title: lang.playLast,
            onTap: () {
              Player.inst.addToQueue(buildTracks());
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    ),
  );
}

void showAdvancedShuffleDialog(Iterable<Selectable> Function() tracksFn, QueueSourceBase source) {
  const type = QueueInsertionType.advancedShuffle;
  final minimumCounter = _TrackMinimumCounter(tracksFn);

  List<Selectable> buildTracks() {
    final insertion = type.toQueueInsertion();
    final tracks = tracksFn().toList();
    if (settings.shuffleExcludeCount.value <= 0) return insertion.apply(tracks);
    final pool = insertion.filtered(tracks);
    return _buildShuffledQueue(pool, insertion.maxCount);
  }

  final playAfterTrack = _playAfterTrack();

  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      title: lang.shuffle,
      child: Column(
        children: [
          const SizedBox(height: 12.0),
          ObxO(
            rx: settings.queueInsertion,
            builder: (context, _) => _QueueInsertionTiles(
              insertion: type.toQueueInsertion(),
              onChanged: (insertion) => settings.queueInsertion.update((insertions) => insertions[type] = insertion),
              minimumCounter: minimumCounter,
              maxTracksCount: minimumCounter.totalCount(),
              showInsertNext: false,
              shuffleLocked: true,
              forYoutube: false,
            ),
          ),
          const _ShuffleExclusionTile(),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0)),
          CustomListTile(
            icon: Broken.shuffle,
            title: lang.shuffle,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              Player.inst.playOrPause(0, buildTracks(), source);
            },
          ),
          CustomListTile(
            icon: Broken.next,
            title: "${lang.playNext} (${lang.shuffle})",
            onTap: () {
              Player.inst.addToQueue(buildTracks(), insertNext: true);
              NamidaNavigator.inst.closeDialog();
            },
          ),
          if (playAfterTrack != null)
            CustomListTile(
              icon: Broken.hierarchy_square,
              title: "${lang.playAfter} (${lang.shuffle})",
              subtitle: [playAfterTrack.artistsList.firstOrNull, playAfterTrack.title].joinText(separator: ' - '),
              onTap: () {
                Player.inst.addToQueue(buildTracks(), insertAfterLatest: true);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          CustomListTile(
            icon: Broken.play_cricle,
            title: "${lang.playLast} (${lang.shuffle})",
            onTap: () {
              Player.inst.addToQueue(buildTracks());
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showQueueInsertionConfigDialog(QueueInsertionType type, {required String title, bool forYoutube = false}) async {
  final insertionRx = type.toQueueInsertion().obs;
  final minimumCounter = forYoutube ? null : _TrackMinimumCounter(() => allTracksInLibrary);
  final maxTracksCount = 200.withMaximum(allTracksInLibrary.length);
  final recommendedSampleCount = type.recommendedSampleCount;
  final recommendedSampleDaysCount = type.recommendedSampleDaysCount;
  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      insertionRx.close();
    },
    dialog: CustomBlurryDialog(
      title: lang.configure,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.save,
          onTap: () {
            final insertion = insertionRx.value;
            settings.queueInsertion.update((insertions) => insertions[type] = insertion);
            NamidaNavigator.inst.closeDialog();
          },
        ),
      ],
      child: Column(
        children: [
          NamidaInkWell(
            borderRadius: 10.0,
            bgColor: namida.theme.cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Text(title, style: namida.textTheme.displayLarge),
          ),
          const SizedBox(height: 24.0),
          ObxO(
            rx: insertionRx,
            builder: (context, insertion) => _QueueInsertionTiles(
              insertion: insertion,
              onChanged: (insertion) => insertionRx.value = insertion,
              minimumCounter: minimumCounter,
              maxTracksCount: maxTracksCount,
              showInsertNext: true,
              shuffleLocked: false,
              forYoutube: forYoutube,
            ),
          ),
          if (recommendedSampleCount != null)
            CustomListTile(
              icon: Broken.chart_square,
              title: '${lang.sample} (${type == QueueInsertionType.algorithmDiscoverDate ? lang.firstListen : lang.totalListens})',
              trailing: ObxO(
                rx: insertionRx,
                builder: (context, insertion) {
                  final sampleCount = insertion.sample ?? recommendedSampleCount;
                  return NamidaWheelSlider(
                    min: 1,
                    max: 100,
                    initValue: sampleCount,
                    onValueChanged: (val) => insertionRx.value = insertionRx.value.copyWith(sample: val),
                    text: '$sampleCount',
                  );
                },
              ),
            ),
          if (recommendedSampleDaysCount != null)
            CustomListTile(
              icon: Broken.square,
              title: '${lang.sample} (${lang.days})',
              trailing: ObxO(
                rx: insertionRx,
                builder: (context, insertion) {
                  final sampleDaysCount = insertion.sampleDays ?? recommendedSampleDaysCount;
                  return NamidaWheelSlider(
                    min: 1,
                    max: 100,
                    initValue: sampleDaysCount,
                    onValueChanged: (val) => insertionRx.value = insertionRx.value.copyWith(sampleDays: val),
                    text: '$sampleDaysCount',
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

Track? _playAfterTrack() {
  if (Player.inst.currentItem.value is! Selectable || Player.inst.latestInsertedIndex <= Player.inst.currentIndex.value) return null;
  return (Player.inst.currentQueue.value[Player.inst.latestInsertedIndex] as Selectable).track;
}

/// shuffled, with the tracks excluded by [settings.shuffleExcludeCount] going last, only reached when [count] exceeds the rest.
List<Selectable> _buildShuffledQueue(List<Selectable> pool, int? count) {
  final poolLength = pool.length;
  final requiredCount = count == null ? poolLength : count.withMaximum(poolLength);
  final excludeCount = settings.shuffleExcludeCount.value.withMaximum(poolLength);
  if (excludeCount <= 0) {
    final sample = pool.getRandomSample(requiredCount);
    if (requiredCount < poolLength) sample.shuffle();
    return sample;
  }

  final sortKey = SearchSortController.inst.getTracksSortingComparables(settings.shuffleExcludeSort.value);
  final indices = List<int>.generate(poolLength, (i) => i, growable: false);
  final orderedIndices = indices.lazySortedByAltsPrecomputed([(i) => sortKey(pool[i].track)], reverse: settings.shuffleExcludeSortReverse.value);
  final isExcluded = List<bool>.filled(poolLength, false);
  for (final i in orderedIndices.take(excludeCount)) {
    isExcluded[i] = true;
  }

  final included = <Selectable>[];
  final excluded = <Selectable>[];
  for (int i = 0; i < poolLength; i++) {
    final item = pool[i];
    if (isExcluded[i]) {
      excluded.add(item);
    } else {
      included.add(item);
    }
  }

  included.shuffle();
  final missingCount = requiredCount - included.length;
  if (missingCount <= 0) {
    included.length = requiredCount;
    return included;
  }
  excluded.shuffle();
  included.addAll(excluded.take(missingCount));
  return included;
}

/// each sort's values are sorted once, so moving the wheel is a binary search instead of a rescan.
///
/// by claude
class _TrackMinimumCounter {
  final Iterable<Selectable> Function() tracksFn;
  _TrackMinimumCounter(this.tracksFn);

  final _sortedValuesPerSort = <SortType, List<num>>{};
  int? _totalCount;

  int totalCount() => _totalCount ??= tracksFn().length;

  int countAtLeast(SortType sort, TrackMinimum minimum, int value) {
    if (!minimum.isActive(value)) return totalCount();
    final sortedValues = _sortedValuesPerSort[sort] ??= _buildSortedValues(minimum);
    int low = 0;
    int high = sortedValues.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (sortedValues[middle] < value) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return sortedValues.length - low;
  }

  List<num> _buildSortedValues(TrackMinimum minimum) {
    final values = <num>[];
    for (final e in tracksFn()) {
      final value = minimum.valueOf(e.track);
      if (value != null) values.add(value);
    }
    values.sort();
    return values;
  }
}

class _QueueInsertionTiles extends StatelessWidget {
  final QueueInsertion insertion;
  final void Function(QueueInsertion insertion) onChanged;
  final _TrackMinimumCounter? minimumCounter;
  final int maxTracksCount;
  final bool showInsertNext;
  final bool shuffleLocked;
  final bool forYoutube;

  const _QueueInsertionTiles({
    required this.insertion,
    required this.onChanged,
    required this.minimumCounter,
    required this.maxTracksCount,
    required this.showInsertNext,
    required this.shuffleLocked,
    required this.forYoutube,
  });

  void _pickSorts() {
    NamidaOnTaps.inst.onTracksSortIconTap(
      currentSorts: insertion.sorts,
      currentReverse: insertion.sortReverse,
      allSorts: forYoutube ? const [SortType.mostPlayed] : null,
      onChanged: (sorts, reverse) => onChanged(insertion.copyWith(sorts: sorts, sortReverse: reverse, shuffle: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minimumCounter = this.minimumCounter;
    final insertion = this.insertion;
    final sortText = insertion.sorts.firstOrNull?.toText() ?? lang.defaultLabel;
    final numberOfTracks = insertion.numberOfTracks;
    final filterSort = insertion.filterSort;
    final filterMinimum = filterSort == null ? null : TrackMinimum.of(filterSort);
    int filterValue = 0;
    int? matchingCount = minimumCounter?.totalCount();
    if (filterSort != null && filterMinimum != null) {
      filterValue = insertion.filterValueOf(filterSort, filterMinimum);
      matchingCount = minimumCounter?.countAtLeast(filterSort, filterMinimum, filterValue);
    }
    return Column(
      children: [
        if (!shuffleLocked)
          CustomListTile(
            icon: Broken.sort,
            title: lang.sortBy,
            onTap: _pickSorts,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sortText,
                  style: context.textTheme.displayMedium,
                ),
                const SizedBox(width: 4.0),
                Icon(
                  insertion.sortReverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                  size: 18.0,
                ),
              ],
            ),
          ),
        if (!forYoutube)
          _FilterTile(
            sort: filterSort,
            value: filterValue,
            matchingCount: matchingCount,
            allowNone: true,
            onSortChanged: (sort) => onChanged(insertion.withFilterSort(sort)),
            onValueChanged: (value) {
              if (filterSort == null) return;
              final filterMinimums = Map<SortType, int>.of(insertion.filterMinimums);
              filterMinimums[filterSort] = value;
              onChanged(insertion.copyWith(filterMinimums: filterMinimums));
            },
          ),
        CustomListTile(
          icon: Broken.computing,
          title: lang.numberOfTracks,
          subtitle: "${lang.unlimited}-$maxTracksCount",
          trailing: NamidaWheelSlider(
            max: maxTracksCount,
            initValue: numberOfTracks,
            onValueChanged: (val) => onChanged(insertion.copyWith(numberOfTracks: val)),
            text: numberOfTracks == 0 ? lang.unlimited : '$numberOfTracks',
          ),
        ),
        if (!shuffleLocked)
          CustomSwitchListTile(
            icon: Broken.shuffle,
            title: lang.shuffle,
            value: insertion.shuffle,
            onChanged: (isTrue) => onChanged(insertion.copyWith(shuffle: !isTrue)),
          ),
        if (showInsertNext)
          CustomSwitchListTile(
            icon: Broken.next,
            title: lang.playNext,
            value: insertion.insertNext,
            onChanged: (isTrue) => onChanged(insertion.copyWith(insertNext: !isTrue)),
          ),
      ],
    );
  }
}

class _FilterTile extends StatelessWidget {
  final SortType? sort;
  final int value;
  final int? matchingCount;
  final bool allowNone;
  final void Function(SortType? sort) onSortChanged;
  final void Function(int value) onValueChanged;

  const _FilterTile({
    required this.sort,
    required this.value,
    required this.matchingCount,
    required this.allowNone,
    required this.onSortChanged,
    required this.onValueChanged,
  });

  List<Widget> _buildSortChoices() {
    return [
      if (allowNone)
        _FilterSortChoice(
          sort: null,
          isActive: sort == null,
          onSortChanged: onSortChanged,
        ),
      ...TrackMinimum.supportedSorts.map(
        (e) => _FilterSortChoice(
          sort: e,
          isActive: e == sort,
          onSortChanged: onSortChanged,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sort = this.sort;
    final minimum = sort == null ? null : TrackMinimum.of(sort);
    final matchingCount = this.matchingCount;
    final sortText = sort?.toText() ?? lang.none;
    final countText = matchingCount?.displayTrackKeyword;
    final valueText = minimum != null && minimum.isActive(value) ? '≥ ${minimum.formatter(value)}' : lang.any;
    final wheelWidget = minimum == null
        ? null
        : NamidaWheelSlider(
            key: ValueKey(sort),
            initValue: value,
            min: minimum.min,
            max: minimum.max,
            stepper: minimum.stepper,
            onValueChanged: onValueChanged,
            text: valueText,
          );
    return NamidaPopupWrapper(
      children: _buildSortChoices,
      child: CustomListTile(
        icon: Broken.filter,
        title: lang.filterBy,
        subtitleWidget: _PickerSubtitle(pickedText: sortText, trailingText: countText),
        trailing: wheelWidget,
      ),
    );
  }
}

class _FilterSortChoice extends StatelessWidget {
  final SortType? sort;
  final bool isActive;
  final void Function(SortType? sort) onSortChanged;

  const _FilterSortChoice({
    required this.sort,
    required this.isActive,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sort = this.sort;
    return SmallListTile(
      borderRadius: 12.0,
      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
      title: sort?.toText() ?? lang.none,
      trailingIcon: sort?.toIcon() ?? Broken.forbidden_2,
      active: isActive,
      onTap: () {
        onSortChanged(sort);
        NamidaNavigator.inst.popMenu();
      },
    );
  }
}

class _PickerSubtitle extends StatelessWidget {
  final String pickedText;
  final String? trailingText;

  const _PickerSubtitle({
    required this.pickedText,
    required this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = context.textTheme.displaySmall;
    final trailingText = this.trailingText;
    return Row(
      children: [
        Icon(
          Broken.arrow_swap,
          size: 14.0,
          color: textStyle?.color,
        ),
        const SizedBox(width: 4.0),
        Flexible(
          child: Text(
            pickedText,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingText != null)
          Text(
            ' • $trailingText',
            style: textStyle,
            maxLines: 1,
          ),
      ],
    );
  }
}

class _ShuffleExclusionTile extends StatelessWidget {
  const _ShuffleExclusionTile();

  List<Widget> _buildSortChildren() {
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
        child: ListTileWithCheckMark(
          borderRadius: 10.0,
          activeRx: settings.shuffleExcludeSortReverse,
          onTap: () => settings.shuffleExcludeSortReverse.save(!settings.shuffleExcludeSortReverse.value),
        ),
      ),
      ...SortType.forTracks().map(
        (sort) => ObxO(
          rx: settings.shuffleExcludeSort,
          builder: (context, activeSort) => SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: sort.toText(),
            trailingIcon: sort.toIcon(),
            active: activeSort == sort,
            onTap: () => settings.shuffleExcludeSort.save(sort),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final excludeCount = settings.shuffleExcludeCount.valueR;
        final sort = settings.shuffleExcludeSort.valueR;
        final isReverse = settings.shuffleExcludeSortReverse.valueR;
        final sortText = sort.toText();
        return NamidaPopupWrapper(
          children: _buildSortChildren,
          child: CustomListTile(
            icon: Broken.forbidden_2,
            title: lang.exclude,
            subtitleWidget: _PickerSubtitle(
              pickedText: isReverse ? '$sortText (${lang.reverseOrder})' : sortText,
              trailingText: null,
            ),
            trailing: NamidaWheelSlider(
              initValue: excludeCount,
              max: 500,
              onValueChanged: settings.shuffleExcludeCount.save,
              text: excludeCount > 0 ? excludeCount.displayTrackKeyword : lang.none,
            ),
          ),
        );
      },
    );
  }
}
