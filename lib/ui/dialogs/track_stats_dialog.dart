import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showSetTrackStatsDialog({
  required List<Track> tracks,
  void Function(TrackStats newStat)? onEdit,
  Color? iconColor,
  Color? colorScheme,
}) async {
  if (tracks.isEmpty) return;

  final statsEditor = TrackStatsEditController(tracks);
  final isEditing = false.obs;

  Future<void> onSave() async {
    final editedTagsPerTrack = statsEditor.buildEditedTagsPerTrack(tracks);
    if (editedTagsPerTrack.isNotEmpty) {
      isEditing.value = true;
      int failedCount = 0;
      String? lastError;
      await NamidaTaggerController.inst
          .updateTracksMetadata(
            tracks: editedTagsPerTrack.keys.toList(),
            editedTags: const {},
            editedTagsPerTrack: editedTagsPerTrack,
            onStatsEdit: onEdit,
            onEdit: (didUpdate, error, _) {
              if (!didUpdate) {
                failedCount++;
                lastError = error ?? lastError;
              }
            },
            keepFileDates: true,
            displayFFmpegFallbackWarning: false,
          )
          .ignoreError();
      isEditing.value = false;

      if (failedCount > 0) {
        var msg = lang.metadataEditFailed;
        if (failedCount > 1) msg += ' ($failedCount)';
        if (lastError != null) msg += '\n$lastError';
        snackyy(title: lang.warning, message: msg, isError: true);
      }
    }
    NamidaNavigator.inst.closeAllDialogs();
  }

  await NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    lighterDialogColor: true,
    onDisposing: () {
      statsEditor.dispose();
      isEditing.close();
    },
    dialogBuilder: (theme) => CustomBlurryDialog(
      contentPadding: EdgeInsets.zero,
      title: tracks.length > 1 ? '${lang.configure} (${tracks.displayTrackKeyword})' : lang.configure,
      actions: [
        const CancelButton(),
        ObxO(
          rx: isEditing,
          builder: (context, editing) => NamidaButton(
            enabled: !editing,
            isLoading: editing,
            text: lang.save,
            onTap: onSave,
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: namida.height * 0.6),
        child: SuperSmoothListView(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          shrinkWrap: true,
          children: [
            TrackStatsEditSections(
              controller: statsEditor,
              iconColor: iconColor,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12.0),
          ],
        ),
      ),
    ),
  );
}

void showSetTrackStatsDialogSimple({
  required Track track,
  required TrackStats? stats,
}) {
  final selectedRatingRx = (stats?.rating ?? 0).obs;
  final selectedFixedRatingRx = (stats?.rating ?? 0).obs;
  Future<void> onSave() async {
    NamidaNavigator.inst.closeAllDialogs();
    await NamidaTaggerController.inst
        .updateTracksMetadata(
          tracks: [track],
          editedTags: {
            TagField.rating: selectedRatingRx.value.toString(),
          },
          onEdit: (didUpdate, error, _) {
            if (!didUpdate) {
              var msg = lang.metadataEditFailed;
              if (error != null) msg += '\n$error';
              snackyy(title: lang.warning, message: msg, isError: true);
            }
          },
          keepFileDates: true,
          displayFFmpegFallbackWarning: false,
        )
        .ignoreError();
  }

  selectedFixedRatingRx.addListener(onSave); // auto save on clicking fixed percentage

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      selectedRatingRx.close();
      selectedFixedRatingRx.close();
    },
    dialog: CustomBlurryDialog(
      title: lang.rating,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.save,
          onTap: onSave,
        ),
      ],
      child: TrackRatingRowWidget(
        selectedRatingRx: selectedRatingRx,
        selectedFixedRatingRx: selectedFixedRatingRx,
      ),
    ),
  );
}

class TrackStatsEditController {
  final bool _hasMixedRatings;
  final String? _mixedRatingsText;
  final int _initialRating;
  final Rx<int> _selectedRatingRx;
  final Rx<int> _selectedFixedRatingRx;
  final _ratingEditedRx = false.obs;
  final _TrackStatsItemsSelection _moods;
  final _TrackStatsItemsSelection _tags;

  TrackStatsEditController._({
    required this._hasMixedRatings,
    required this._mixedRatingsText,
    required this._initialRating,
    required this._moods,
    required this._tags,
  }) : _selectedRatingRx = _initialRating.obs,
       _selectedFixedRatingRx = _initialRating.obs {
    _selectedRatingRx.addListener(_onRatingEdited);
  }

  factory TrackStatsEditController(List<Track> tracks) {
    final ratingsCounts = <int, int>{};
    for (final tr in tracks) {
      ratingsCounts.update(tr.effectiveRating, (c) => c + 1, ifAbsent: () => 1);
    }
    final hasMixedRatings = ratingsCounts.length > 1;
    return TrackStatsEditController._(
      hasMixedRatings: hasMixedRatings,
      mixedRatingsText: hasMixedRatings ? _buildRatingsCountsText(ratingsCounts) : null,
      initialRating: hasMixedRatings ? 0 : ratingsCounts.keys.first,
      moods: _TrackStatsItemsSelection._fromTracksItems(
        tracks.map((tr) => tr.effectiveMoods),
        computeAvailableCounts: () => _computeLibraryCounts((stats) => stats.moods, (tr) => tr.moodList),
      ),
      tags: _TrackStatsItemsSelection._fromTracksItems(
        tracks.map((tr) => tr.effectiveTags),
        computeAvailableCounts: () => _computeLibraryCounts((stats) => stats.tags, (tr) => tr.tagsList),
      ),
    );
  }

  void _onRatingEdited() => _ratingEditedRx.value = true;

  void addChangesListener(VoidCallback listener) {
    _selectedRatingRx.addListener(listener);
    for (final selection in [_moods, _tags]) {
      selection.selectedForAllRx.addListener(listener);
      selection.partialKeptRx.addListener(listener);
    }
  }

  Map<Track, Map<TagField, String>> buildEditedTagsPerTrack(Iterable<Track> tracks) {
    final ratingEdited = _ratingEditedRx.value;
    final rating = _selectedRatingRx.value;
    final editedTagsPerTrack = <Track, Map<TagField, String>>{};
    for (final track in tracks) {
      Map<TagField, String>? editedTags;
      if (ratingEdited && track.effectiveRating != rating) {
        (editedTags ??= {})[TagField.rating] = rating.toString();
      }
      final newMoods = _moods._newItemsJoinedOrNull(track.effectiveMoods);
      if (newMoods != null) (editedTags ??= {})[TagField.mood] = newMoods;
      final newTags = _tags._newItemsJoinedOrNull(track.effectiveTags);
      if (newTags != null) (editedTags ??= {})[TagField.tags] = newTags;

      if (editedTags != null) editedTagsPerTrack[track] = editedTags;
    }
    return editedTagsPerTrack;
  }

  String? get moodsChangesText => _moods._changesText();

  String? get tagsChangesText => _tags._changesText();

  String? get ratingChangesText {
    if (!_ratingEditedRx.value) return null;
    final initialText = _hasMixedRatings ? '<${lang.multipleValues}>' : '$_initialRating';
    return '$initialText → ${_selectedRatingRx.value}';
  }

  void dispose() {
    _selectedRatingRx.close();
    _selectedFixedRatingRx.close();
    _ratingEditedRx.close();
    _moods._dispose();
    _tags._dispose();
  }

  static String _buildRatingsCountsText(Map<int, int> ratingsCounts) {
    const maxRatingsShown = 6;
    final sorted = ratingsCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxRatingsShown).map((e) => '${e.key}% ×${e.value}').join(' • ');
  }

  static Map<String, int> _computeLibraryCounts(List<String>? Function(TrackStats stats) fromStats, List<String> Function(Track tr) fromTrack) {
    final counts = <String, int>{};
    for (final stats in Indexer.inst.trackStatsMap.value.values) {
      final items = fromStats(stats);
      if (items != null) {
        for (final item in items) {
          counts.update(item, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    for (final tr in allTracksInLibrary) {
      for (final item in fromTrack(tr)) {
        counts.update(item, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    counts.sortByReverse((e) => e.value);
    return counts;
  }
}

class _TrackStatsItemsSelection {
  final int tracksCount;
  final Set<String> _initialForAll;
  final Map<String, int> initialPartialCounts;
  final Rx<Set<String>> selectedForAllRx;
  final Rx<Set<String>> partialKeptRx;

  final Map<String, int> Function() _computeAvailableCounts;
  RxMap<String, int>? _allAvailableCountRx;

  RxMap<String, int> get allAvailableCountRx => _allAvailableCountRx ??= _computeAvailableCounts().obs;

  _TrackStatsItemsSelection._({
    required this.tracksCount,
    required this._initialForAll,
    required this.initialPartialCounts,
    required this._computeAvailableCounts,
  }) : selectedForAllRx = _initialForAll.toSet().obs,
       partialKeptRx = initialPartialCounts.keys.toSet().obs;

  factory _TrackStatsItemsSelection._fromTracksItems(Iterable<List<String>> tracksItems, {required Map<String, int> Function() computeAvailableCounts}) {
    final counts = <String, int>{};
    final seenInTrack = <String>{};
    int tracksCount = 0;
    for (final items in tracksItems) {
      tracksCount++;
      seenInTrack.clear();
      for (final item in items) {
        if (item.isNotEmpty && seenInTrack.add(item)) {
          counts.update(item, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    final initialForAll = <String>{};
    final initialPartialCounts = <String, int>{};
    for (final e in counts.entries) {
      if (e.value == tracksCount) {
        initialForAll.add(e.key);
      } else {
        initialPartialCounts[e.key] = e.value;
      }
    }
    return _TrackStatsItemsSelection._(
      tracksCount: tracksCount,
      initialForAll: initialForAll,
      initialPartialCounts: initialPartialCounts,
      computeAvailableCounts: computeAvailableCounts,
    );
  }

  void selectForAll(Iterable<String> items) {
    for (final item in items) {
      if (selectedForAllRx.value.add(item)) {
        allAvailableCountRx.value.update(item, (value) => value + 1, ifAbsent: () => 1);
      }
      partialKeptRx.value.remove(item);
    }
    selectedForAllRx.refresh();
    partialKeptRx.refresh();
    allAvailableCountRx.refresh();
  }

  void unselect(String item) {
    selectedForAllRx.value.remove(item);
    selectedForAllRx.refresh();
  }

  void keepPartial(String item) {
    partialKeptRx.value.add(item);
    partialKeptRx.refresh();
  }

  String? _changesText() {
    final selected = selectedForAllRx.value;
    final partialKept = partialKeptRx.value;
    final changes = <String>[];
    for (final item in selected) {
      if (!_initialForAll.contains(item)) changes.add('+$item');
    }
    for (final item in _initialForAll) {
      if (!selected.contains(item)) changes.add('-$item');
    }
    for (final item in initialPartialCounts.keys) {
      if (!selected.contains(item) && !partialKept.contains(item)) changes.add('-$item');
    }
    return changes.isEmpty ? null : changes.join(', ');
  }

  String? _newItemsJoinedOrNull(List<String> current) {
    final selected = selectedForAllRx.value;
    final partialKept = partialKeptRx.value;
    final result = <String>[];
    int currentCount = 0;
    for (final item in current) {
      if (item.isEmpty) continue;
      currentCount++;
      if (selected.contains(item) || partialKept.contains(item)) result.add(item);
    }
    final keptCount = result.length;
    for (final item in selected) {
      if (!current.contains(item)) result.add(item);
    }
    if (keptCount == currentCount && result.length == keptCount) return null;
    return result.join(', ');
  }

  void _dispose() {
    selectedForAllRx.close();
    partialKeptRx.close();
    _allAvailableCountRx?.close();
  }
}

class TrackStatsEditSections extends StatelessWidget {
  final TrackStatsEditController controller;
  final Color? iconColor;
  final Color? colorScheme;

  const TrackStatsEditSections({
    super.key,
    required this.controller,
    this.iconColor,
    this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatsItemsSection(
          title: lang.setMoods,
          icon: Broken.smileys,
          selection: controller._moods,
          iconColor: iconColor,
          colorScheme: colorScheme,
        ),
        const NamidaContainerDivider(
          margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
        ),
        _StatsItemsSection(
          title: lang.setTags,
          icon: Broken.ticket_discount,
          selection: controller._tags,
          iconColor: iconColor,
          colorScheme: colorScheme,
        ),
        const NamidaContainerDivider(
          margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
        ),
        const SizedBox(height: 6.0),
        TrackRatingRowWidget(
          selectedRatingRx: controller._selectedRatingRx,
          selectedFixedRatingRx: controller._selectedFixedRatingRx,
          subtitle: controller._mixedRatingsText,
        ),
      ],
    );
  }
}

class TrackRatingRowWidget extends StatelessWidget {
  final Rx<int> selectedRatingRx;
  final Rx<int> selectedFixedRatingRx;
  final String? subtitle;

  const TrackRatingRowWidget({
    super.key,
    required this.selectedRatingRx,
    required this.selectedFixedRatingRx,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomListTile(
          icon: Broken.grammerly,
          title: lang.setRating,
          subtitle: subtitle,
          trailing: ObxO(
            rx: selectedFixedRatingRx,
            builder: (context, fixedrating) => ObxO(
              rx: selectedRatingRx,
              builder: (context, rating) => NamidaWheelSlider(
                key: ValueKey(fixedrating), // rebuild on selecting fixed rating
                min: -1,
                max: 100,
                initValue: rating == 0 ? -1 : 100 - rating,
                text: rating == 0 ? '' : '$rating',
                onValueChanged: (val) {
                  selectedRatingRx.value = val == -1 ? 0 : (100 - val);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6.0),
        SmoothSingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ObxO(
            rx: selectedRatingRx,
            builder: (context, selectedRating) => Row(
              children: const [100, 95, 90, 85, 80, 75, 70, 60, 50].map(
                (e) {
                  final isSelected = e == selectedRating;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: NamidaInkWellButton(
                      borderRadius: 99.0,
                      sizeMultiplier: 0.85,
                      paddingMultiplier: 0.6,
                      icon: null,
                      leading:
                          Icon(
                            Broken.tick_circle,
                            size: 12.0,
                          ).animateEntrance(
                            showWhen: isSelected,
                            allCurves: Curves.fastLinearToSlowEaseIn,
                            durationMS: 200,
                          ),
                      text: '$e',
                      bgColor: context.theme.colorScheme.secondaryContainer.withOpacityExt(0.2),
                      onTap: () {
                        selectedRatingRx.value = e; // -- must be first
                        selectedFixedRatingRx.value = e;
                      },
                    ),
                  );
                },
              ).toFixedList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsItemsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final _TrackStatsItemsSelection selection;
  final Color? iconColor;
  final Color? colorScheme;

  const _StatsItemsSection({
    required this.title,
    required this.icon,
    required this.selection,
    required this.iconColor,
    required this.colorScheme,
  });

  void _showAddItemsDialog() {
    final controller = TextEditingController();
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      lighterDialogColor: true,
      onDisposing: controller.dispose,
      dialogBuilder: (theme) => CustomBlurryDialog(
        title: lang.add,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.add,
            onTap: () {
              selection.selectForAll(Indexer.splitByCommaList(controller.text));
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: namida.height * 0.5),
          child: SuperSmoothListView(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            shrinkWrap: true,
            children: [
              const SizedBox(height: 12.0),
              _StatsItemsAddField(
                controller: controller,
                labelText: title,
                icon: icon,
                iconColor: iconColor,
              ),
              const SizedBox(height: 12.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomListTile(
          icon: icon,
          title: title,
          trailing: NamidaInkWellButton(
            text: lang.add,
            icon: Broken.add_circle,
            onTap: _showAddItemsDialog,
          ),
        ),
        _SetMoodsTagsRows(
          selection: selection,
        ),
      ],
    );
  }
}

class _StatsItemsAddField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final Color? iconColor;

  const _StatsItemsAddField({
    required this.controller,
    required this.labelText,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    const iconSize = 24.0;
    const iconRightPadding = 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
            const SizedBox(width: iconRightPadding),
            Expanded(
              child: CustomTagTextField(
                controller: controller,
                hintText: '',
                labelText: labelText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Padding(
          padding: const EdgeInsets.only(left: iconSize + iconRightPadding),
          child: Text(
            lang.setMoodsSubtitle,
            style: context.textTheme.displaySmall,
          ),
        ),
      ],
    );
  }
}

class _SetMoodsTagsRows extends StatelessWidget {
  final _TrackStatsItemsSelection selection;
  const _SetMoodsTagsRows({required this.selection});

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = EdgeInsets.symmetric(horizontal: 12.0);
    final smallTextStyle = context.textTheme.displaySmall?.copyWith(fontSize: 11.0);
    final secondaryContainer = context.theme.colorScheme.secondaryContainer;
    final highlightedColor = secondaryContainer.withOpacityExt(0.5);
    final normalColor = secondaryContainer.withOpacityExt(0.2);
    final removedColor = Color.alphaBlend(Colors.red.withOpacityExt(0.2), highlightedColor);
    final suggestionDecoration = BoxDecoration(
      border: Border.all(
        color: secondaryContainer.withOpacityExt(0.8),
      ),
    );
    final suggestionItemsColor = context.theme.colorScheme.onSurface.withOpacityExt(0.6);
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        SmoothSingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: horizontalPadding,
          child: Obx(
            (context) {
              final selected = selection.selectedForAllRx.valueR;
              final partialKept = selection.partialKeptRx.valueR;
              final initialForAll = selection._initialForAll;
              final initialPartialCounts = selection.initialPartialCounts;
              return Row(
                children: [
                  ...initialForAll.map(
                    (item) {
                      final isKept = selected.contains(item);
                      return _StatsItemChip(
                        text: item,
                        icon: isKept ? null : Broken.minus_cirlce,
                        bgColor: isKept ? normalColor : removedColor,
                        onTap: () => isKept ? selection.unselect(item) : selection.selectForAll([item]),
                      );
                    },
                  ),
                  ...initialPartialCounts.entries.map(
                    (e) {
                      final item = e.key;
                      final isAdded = selected.contains(item);
                      final isKept = partialKept.contains(item);
                      return _StatsItemChip(
                        text: item,
                        icon: isAdded
                            ? Broken.add_circle
                            : isKept
                            ? null
                            : Broken.minus_cirlce,
                        bgColor: isAdded
                            ? highlightedColor
                            : isKept
                            ? normalColor
                            : removedColor,
                        trailing: Text(
                          '${e.value}/${selection.tracksCount}',
                          style: smallTextStyle,
                        ),
                        onTap: () => isAdded
                            ? selection.unselect(item)
                            : isKept
                            ? selection.selectForAll([item])
                            : selection.keepPartial(item),
                      );
                    },
                  ),
                  ...selected
                      .where((item) => !initialForAll.contains(item) && !initialPartialCounts.containsKey(item))
                      .map(
                        (item) => _StatsItemChip(
                          text: item,
                          icon: Broken.add_circle,
                          bgColor: highlightedColor,
                          onTap: () => selection.unselect(item),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6.0),
        Obx(
          (context) {
            final selected = selection.selectedForAllRx.valueR;
            final initialForAll = selection._initialForAll;
            final initialPartialCounts = selection.initialPartialCounts;
            final suggestions = selection.allAvailableCountRx.valueR.keys
                .where((e) => !selected.contains(e) && !initialForAll.contains(e) && !initialPartialCounts.containsKey(e))
                .toList();
            return SmoothSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: horizontalPadding,
              child: Row(
                children: suggestions
                    .map(
                      (e) => _StatsItemSuggestionChip(
                        text: e,
                        decoration: suggestionDecoration,
                        itemsColor: suggestionItemsColor,
                        onTap: () => selection.selectForAll([e]),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 6.0),
      ],
    );
  }
}

class _StatsItemChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color bgColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _StatsItemChip({
    required this.text,
    required this.icon,
    required this.bgColor,
    this.trailing,
    required this.onTap,
  });

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: NamidaInkWellButton(
        borderRadius: 99.0,
        paddingMultiplier: 0.8,
        icon: icon,
        iconSize: _iconSize,
        leading: icon == null
            ? const SizedBox(
                height: _iconSize,
              )
            : null,
        text: text,
        trailing: trailing,
        bgColor: bgColor,
        onTap: onTap,
      ),
    );
  }
}

class _StatsItemSuggestionChip extends StatelessWidget {
  final String text;
  final BoxDecoration decoration;
  final Color itemsColor;
  final VoidCallback onTap;

  const _StatsItemSuggestionChip({
    required this.text,
    required this.decoration,
    required this.itemsColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: NamidaInkWellButton(
        borderRadius: 99.0,
        sizeMultiplier: 0.9,
        paddingMultiplier: 0.8,
        icon: Broken.add,
        iconSize: 14.0,
        text: text,
        bgColor: Colors.transparent,
        decoration: decoration,
        itemsColor: itemsColor,
        onTap: onTap,
      ),
    );
  }
}
