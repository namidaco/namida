import 'package:flutter/material.dart';

import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/playlist_tags_manager_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

const _kChipsRowHeight = 30.0;

class PlaylistTagsChipsRow extends StatelessWidget {
  final PlaylistManager manager;
  final EdgeInsetsGeometry padding;
  final void Function({required bool shuffle})? onPlay;
  final List<NamidaPopupItem> Function()? extraMenuItems;

  const PlaylistTagsChipsRow({
    super.key,
    required this.manager,
    this.padding = EdgeInsets.zero,
    this.onPlay,
    this.extraMenuItems,
  });

  List<NamidaPopupItem> _buildMenuItems() {
    final filter = manager.tagsFilter;
    final isActive = filter.isActive;
    final onPlay = this.onPlay;
    final canPlay = isActive && onPlay != null;
    final canSaveFilter = isActive && !filter.savedSelections.contains(filter.selection);
    final hasTags = filter.allPaths.isNotEmpty;
    return [
      if (canPlay) ...[
        NamidaPopupItem(
          icon: Broken.play,
          title: lang.playAll,
          onTap: () => onPlay(shuffle: false),
        ),
        NamidaPopupItem(
          icon: Broken.shuffle,
          title: lang.shuffleAll,
          onTap: () => onPlay(shuffle: true),
        ),
      ],
      if (canSaveFilter)
        NamidaPopupItem(
          icon: Broken.bookmark,
          title: lang.saveFilter,
          onTap: filter.saveCurrentSelection,
        ),
      if (hasTags)
        NamidaPopupItem(
          icon: Broken.tag_2,
          title: lang.manageTags,
          onTap: () => showPlaylistTagsManagerDialog(manager),
        ),
      ...?extraMenuItems?.call(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filter = manager.tagsFilter;
    return ObxO(
      rx: filter.revision,
      builder: (context, _) {
        final chips = filter.computeChips();
        final isActive = filter.isActive;
        final savedSelections = isActive ? const <PlaylistTagsSelection>[] : filter.savedSelections;
        if (chips.isEmpty && savedSelections.isEmpty) return const SizedBox();
        final savedCount = savedSelections.length;
        return Padding(
          padding: padding,
          child: SizedBox(
            height: _kChipsRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: NamidaEndEdgeFeather(
                    child: SuperSmoothListView.builder(
                      padding: const EdgeInsetsDirectional.only(start: 12.0, end: 16.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: savedCount + chips.length,
                      itemBuilder: (context, index) {
                        if (index < savedCount) {
                          final saved = savedSelections[index];
                          return _SavedFilterChip(
                            selection: saved,
                            onTap: () => filter.applySelection(saved),
                            onRemove: () => filter.removeSavedSelection(saved),
                          );
                        }
                        final chip = chips[index - savedCount];
                        return _TagChip(
                          chip: chip,
                          onTap: () => filter.toggleIncluded(chip.key),
                          onLongPress: () => filter.toggleExcluded(chip.key),
                        );
                      },
                    ),
                  ),
                ),
                _SquareChip(
                  icon: Broken.more,
                  menuItems: _buildMenuItems,
                ),
                if (isActive)
                  _SquareChip(
                    icon: Broken.filter_remove,
                    tooltip: lang.clear,
                    onTap: filter.clear,
                  ),
                const SizedBox(
                  width: 10.0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  final PlaylistTagChip chip;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TagChip({
    required this.chip,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final key = chip.key;
    final state = chip.state;
    final isExcluded = state == PlaylistTagFilterState.excluded;
    final bgColor = switch (state) {
      PlaylistTagFilterState.none => colorScheme.secondaryContainer.withOpacityExt(0.25),
      PlaylistTagFilterState.included => colorScheme.secondaryContainer,
      PlaylistTagFilterState.excluded => colorScheme.errorContainer.withOpacityExt(0.5),
    };
    final icon = switch (key) {
      PlaylistVirtualTag() => key.toIcon(),
      PlaylistUserTag() => chip.depth > 0 ? Broken.arrow_right_3 : null,
    };
    final text = switch (key) {
      PlaylistVirtualTag() => key.toVirtualText(),
      PlaylistUserTag() => chip.label ?? key.path,
    };
    final color = chip.color;
    final textStyle = textTheme.displaySmall?.copyWith(
      decoration: isExcluded ? TextDecoration.lineThrough : null,
      fontWeight: state == PlaylistTagFilterState.included ? FontWeight.w600 : null,
    );
    return NamidaInkWell(
      animationDurationMS: 200,
      margin: const EdgeInsetsDirectional.only(end: 6.0),
      borderRadius: 99.0,
      bgColor: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      enableSecondaryTap: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            PlaylistTagColorDot(
              color: Color(color),
            ),
            const SizedBox(
              width: 6.0,
            ),
          ],
          if (icon != null) ...[
            Icon(
              icon,
              size: 12.0,
            ),
            const SizedBox(
              width: 4.0,
            ),
          ],
          Text(
            text,
            style: textStyle,
            maxLines: 1,
          ),
          if (!isExcluded) ...[
            const SizedBox(
              width: 6.0,
            ),
            Text(
              chip.count.formatDecimal(),
              style: textTheme.displaySmall?.copyWith(
                fontSize: 11.0,
                color: textTheme.displaySmall?.color?.withOpacityExt(0.6),
              ),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _SavedFilterChip extends StatelessWidget {
  final PlaylistTagsSelection selection;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedFilterChip({
    required this.selection,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6.0),
      child: NamidaPopupWrapper(
        openOnTap: false,
        onTap: onTap,
        childrenDefault: () => [
          NamidaPopupItem(
            icon: Broken.trash,
            title: lang.remove,
            onTap: onRemove,
          ),
        ],
        child: Container(
          height: _kChipsRowHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99.0),
            border: Border.all(
              color: theme.colorScheme.secondaryContainer,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Broken.bookmark,
                  size: 12.0,
                ),
                const SizedBox(
                  width: 4.0,
                ),
                Text(
                  selection.toText(),
                  style: theme.textTheme.displaySmall,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareChip extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final List<NamidaPopupItem> Function()? menuItems;

  const _SquareChip({
    required this.icon,
    this.tooltip,
    this.onTap,
    this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = context.theme.colorScheme.secondaryContainer.withOpacityExt(0.25);
    final menuItems = this.menuItems;
    final tooltip = this.tooltip;
    Widget child = NamidaInkWell(
      height: _kChipsRowHeight,
      margin: const EdgeInsetsDirectional.only(start: 4.0),
      borderRadius: 99.0,
      bgColor: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      onTap: onTap,
      child: Icon(
        icon,
        size: 14.0,
      ),
    );
    if (menuItems != null) {
      child = NamidaPopupWrapper(
        childrenDefault: menuItems,
        child: child,
      );
    }
    if (tooltip != null) {
      child = NamidaTooltip(
        message: () => tooltip,
        child: child,
      );
    }
    return child;
  }
}

class PlaylistTagsColorDots extends StatelessWidget {
  final PlaylistTagsFilter filter;
  final List<String> tags;
  final double trailingGap;

  const PlaylistTagsColorDots({
    super.key,
    required this.filter,
    required this.tags,
    this.trailingGap = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = filter.colorsOf(tags);
    if (colors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(end: trailingGap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final color in colors)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 3.0),
              child: PlaylistTagColorDot(
                color: Color(color),
              ),
            ),
        ],
      ),
    );
  }
}

class PlaylistTagColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const PlaylistTagColorDot({
    super.key,
    required this.color,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
