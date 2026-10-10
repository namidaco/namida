import 'package:flutter/material.dart';

import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/playlist_tags_chips_row.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

void showPlaylistTagsManagerDialog(PlaylistManager manager) {
  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      title: lang.manageTags,
      icon: Broken.tag_2,
      normalTitleStyle: true,
      scrollable: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
      actions: const [
        DoneButton(),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: namida.width,
          maxHeight: namida.height * 0.6,
        ),
        child: ObxO(
          rx: manager.tagsFilter.revision,
          builder: (context, _) => _TagsManagerList(
            manager: manager,
          ),
        ),
      ),
    ),
  );
}

class _TagActions {
  final PlaylistManager manager;
  final PlaylistTagInfo tag;

  const _TagActions(this.manager, this.tag);

  List<NamidaPopupItem> buildMenuItems() => [
    NamidaPopupItem(
      icon: Broken.edit_2,
      title: lang.rename,
      onTap: showRenameDialog,
    ),
    NamidaPopupItem(
      icon: Broken.brush_2,
      title: lang.color,
      onTap: showColorPicker,
    ),
    NamidaPopupItem(
      icon: Broken.trash,
      title: lang.remove,
      onTap: showRemoveDialog,
    ),
  ];

  void showRenameDialog() {
    final path = tag.path;
    final controller = TextEditingController(text: path);
    NamidaNavigator.inst.navigateDialog(
      onDisposing: controller.dispose,
      dialog: CustomBlurryDialog(
        title: lang.rename,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              manager.renameTag(path, controller.text);
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 12.0,
            ),
            CustomTagTextField(
              controller: controller,
              hintText: path,
              labelText: lang.name,
            ),
            const SizedBox(
              height: 8.0,
            ),
            Text(
              lang.setTagsNestedSubtitle,
              style: namida.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }

  void showColorPicker() {
    final path = tag.path;
    final filter = manager.tagsFilter;
    final currentColor = filter.colorOf(path);
    final initialColor = currentColor == null ? namida.theme.colorScheme.secondaryContainer : Color(currentColor);
    NamidaNavigator.inst.navigateDialog(
      dialog: NamidaColorPickerDialog(
        cancelButton: true,
        doneText: lang.save,
        initialColor: initialColor,
        onDonePressed: (color) {
          filter.setColor(path, color.intValue);
          NamidaNavigator.inst.closeDialog();
        },
        onRefreshButtonPressed: () {
          filter.setColor(path, null);
          NamidaNavigator.inst.closeDialog();
        },
      ),
    );
  }

  void showRemoveDialog() {
    final path = tag.path;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: '${lang.remove}: ${path.addDQuotation()} (${tag.count.displayPlaylistKeyword})?',
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: lang.remove.toUpperCase(),
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              manager.removeTag(path);
            },
          ),
        ],
      ),
    );
  }
}

class _TagsManagerList extends StatelessWidget {
  final PlaylistManager manager;

  const _TagsManagerList({required this.manager});

  @override
  Widget build(BuildContext context) {
    final filter = manager.tagsFilter;
    final topLevelTags = filter.listTopLevelTags();
    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          sliver: NamidaSliverReorderableList(
            itemCount: topLevelTags.length,
            onReorder: filter.reorderTopLevelTag,
            itemBuilder: (context, i) {
              final tag = topLevelTags[i];
              return _TopLevelTagTile(
                key: ValueKey(tag.path),
                index: i,
                actions: _TagActions(manager, tag),
                tag: tag,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopLevelTagTile extends StatelessWidget {
  final int index;
  final _TagActions actions;
  final PlaylistTagInfo tag;

  const _TopLevelTagTile({
    super.key,
    required this.index,
    required this.actions,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final nestedTags = tag.nested;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withOpacityExt(0.15),
          borderRadius: BorderRadius.circular(14.0.multipliedRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4.0, 6.0, 4.0, 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  NamidaReordererableListener(
                    index: index,
                    child: const ColoredBox(
                      color: Colors.transparent,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                        child: ThreeLineSmallContainers(
                          enabled: true,
                        ),
                      ),
                    ),
                  ),
                  _TagColorButton(
                    color: tag.color,
                    onTap: actions.showColorPicker,
                  ),
                  const SizedBox(
                    width: 10.0,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag.path,
                          style: textTheme.displayMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tag.count.displayPlaylistKeyword,
                          style: textTheme.displaySmall,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  NamidaPopupWrapper(
                    openOnLongPress: false, // -- long press drags the row
                    childrenDefault: actions.buildMenuItems,
                  ),
                  const SizedBox(width: 2.0),
                ],
              ),
              if (nestedTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(34.0, 6.0, 8.0, 4.0),
                  child: Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: nestedTags
                        .map(
                          (nested) => _NestedTagChip(
                            actions: _TagActions(actions.manager, nested),
                            tag: nested,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagColorButton extends StatelessWidget {
  final int? color;
  final VoidCallback onTap;

  const _TagColorButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = this.color;
    const size = 28.0;
    return NamidaTooltip(
      message: () => lang.color,
      child: NamidaInkWell(
        width: size,
        height: size,
        onTap: onTap,
        bgColor: color == null ? null : Color(color),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          border: color == null
              ? Border.all(
                  color: theme.colorScheme.secondaryContainer,
                  width: 1.5,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: color == null
            ? Icon(
                Broken.brush_2,
                size: 14.0,
                color: theme.iconTheme.color?.withOpacityExt(0.6),
              )
            : null,
      ),
    );
  }
}

class _NestedTagChip extends StatelessWidget {
  final _TagActions actions;
  final PlaylistTagInfo tag;

  const _NestedTagChip({
    required this.actions,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final path = tag.path;
    final color = tag.color;
    final relativePathStart = path.indexOf(PlaylistTagsFilter.separator) + 1;
    final relativePath = path.substring(relativePathStart);
    return NamidaPopupWrapper(
      openOnLongPress: false, // -- long press drags the row
      childrenDefault: actions.buildMenuItems,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withOpacityExt(0.35),
          borderRadius: BorderRadius.circular(99.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
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
              Text(
                relativePath,
                style: textTheme.displaySmall,
              ),
              const SizedBox(
                width: 6.0,
              ),
              Text(
                tag.count.formatDecimal(),
                style: textTheme.displaySmall?.copyWith(
                  fontSize: 11.0,
                  color: textTheme.displaySmall?.color?.withOpacityExt(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
