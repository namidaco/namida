// by claude
import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/bookmarks_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showBookmarksSheet(Playable item) {
  NamidaNavigator.inst.showSheet(
    isScrollControlled: true,
    heightPercentage: 0.6,
    builder: (context, bottomPadding, maxWidth, maxHeight) => _BookmarksSheet(
      item: item,
    ),
  );
}

/// builds nothing when [item] has no bookmarks.
class BookmarksSection extends StatefulWidget {
  final Playable item;

  const BookmarksSection({
    super.key,
    required this.item,
  });

  @override
  State<BookmarksSection> createState() => _BookmarksSectionState();
}

class _BookmarksSectionState extends State<BookmarksSection> with _ItemBookmarksMixin {
  @override
  Playable get _item => widget.item;

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: _bookmarks,
      builder: (context, bookmarks) => bookmarks.isEmpty
          ? const SizedBox()
          : Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
              child: Row(
                children: [
                  const Icon(
                    Broken.bookmark,
                    size: 20.0,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: SmoothSingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Row(
                        children: bookmarks
                            .map(
                              (bookmark) => _BookmarkChip(
                                bookmark: bookmark,
                                onTap: () => BookmarksController.inst.play(widget.item, bookmark),
                                menuItems: () => _menuItems(bookmark),
                              ),
                            )
                            .addSeparators(separator: const SizedBox(width: 6.0))
                            .toFixedList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BookmarksSheet extends StatefulWidget {
  final Playable item;

  const _BookmarksSheet({
    required this.item,
  });

  @override
  State<_BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<_BookmarksSheet> with _ItemBookmarksMixin {
  late final _scrollController = NamidaScrollController.create();

  @override
  Playable get _item => widget.item;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final isCurrent = Player.inst.isCurrentItem(widget.item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 18.0, 12.0),
          child: Row(
            children: [
              Expanded(
                child: ObxO(
                  rx: _bookmarks,
                  builder: (context, bookmarks) => Text.rich(
                    TextSpan(
                      text: lang.bookmarks,
                      children: [
                        TextSpan(
                          text: '  •  ${bookmarks.length}',
                          style: textTheme.displayMedium,
                        ),
                      ],
                    ),
                    style: textTheme.displayLarge,
                  ),
                ),
              ),
              if (isCurrent)
                NamidaIconButton(
                  icon: Broken.add,
                  iconSize: 20.0,
                  tooltip: () => lang.addBookmark,
                  onPressed: BookmarksController.inst.addAtCurrentPosition,
                ),
            ],
          ),
        ),
        Expanded(
          child: ObxO(
            rx: _bookmarks,
            builder: (context, bookmarks) => SmoothCustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  sliver: SliverList.builder(
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      return _BookmarkTile(
                        bookmark: bookmark,
                        onTap: () => BookmarksController.inst.play(widget.item, bookmark),
                        menuItems: () => _menuItems(bookmark),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 12.0),
          child: SizedBox(
            width: double.infinity,
            child: NamidaButton(
              text: lang.done,
              minHeight: NamidaButton.kDefaultMinHeight * 1.2,
              onTap: Navigator.of(context).pop,
            ),
          ),
        ),
      ],
    );
  }
}

mixin _ItemBookmarksMixin<T extends StatefulWidget> on State<T> {
  Playable get _item;

  final _bookmarks = const <PlayableBookmark>[].obso;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    BookmarksController.inst.currentBookmarks.addListener(_onCurrentBookmarksChanged);
  }

  @override
  void dispose() {
    BookmarksController.inst.currentBookmarks.removeListener(_onCurrentBookmarksChanged);
    _bookmarks.close();
    super.dispose();
  }

  void _loadBookmarks() async {
    final controller = BookmarksController.inst;
    if (Player.inst.isCurrentItem(_item)) {
      _bookmarks.value = controller.currentBookmarks.value;
      return;
    }
    final bookmarksOrFuture = controller.getBookmarks(_item);
    final bookmarks = bookmarksOrFuture is Future<List<PlayableBookmark>?> ? await bookmarksOrFuture : bookmarksOrFuture;
    if (mounted) _bookmarks.value = bookmarks ?? const [];
  }

  void _onCurrentBookmarksChanged() {
    final controller = BookmarksController.inst;
    if (Player.inst.isCurrentItem(_item)) _bookmarks.value = controller.currentBookmarks.value;
  }

  void _onRemove(PlayableBookmark bookmark) async {
    final bookmarks = await BookmarksController.inst.remove(_item, bookmark);
    if (bookmarks != null && mounted) _bookmarks.value = bookmarks;
  }

  void _onRename(PlayableBookmark bookmark) {
    showNamidaBottomSheetWithTextField(
      title: lang.rename,
      subtitle: bookmark.positionMS.milliSecondsLabel,
      textfieldConfig: BottomSheetTextFieldConfig(
        initalControllerText: bookmark.title,
        hintText: bookmark.title ?? '',
        labelText: lang.title,
        validator: null,
      ),
      buttonText: lang.save,
      onButtonTap: (text) async {
        final bookmarks = await BookmarksController.inst.rename(_item, bookmark, text);
        if (bookmarks != null && mounted) _bookmarks.value = bookmarks;
        return true;
      },
    );
  }

  List<NamidaPopupItem> _menuItems(PlayableBookmark bookmark) {
    return [
      NamidaPopupItem(
        icon: Broken.edit,
        title: lang.rename,
        onTap: () => _onRename(bookmark),
      ),
      NamidaPopupItem(
        icon: Broken.trash,
        title: lang.remove,
        onTap: () => _onRemove(bookmark),
      ),
    ];
  }
}

class _BookmarkTile extends StatelessWidget {
  final PlayableBookmark bookmark;
  final VoidCallback onTap;
  final List<NamidaPopupItem> Function() menuItems;

  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final title = bookmark.title;
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: menuItems,
      child: NamidaInkWell(
        borderRadius: 10.0,
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        bgColor: theme.cardColor.withOpacityExt(0.4),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              Broken.bookmark,
              size: 18.0,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10.0),
            Text(
              bookmark.positionMS.milliSecondsLabel,
              style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: title == null
                  ? const SizedBox()
                  : Text(
                      title,
                      style: textTheme.displaySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            NamidaPopupWrapper(
              childrenDefault: menuItems,
              child: const MoreIcon(
                iconSize: 16.0,
                padding: 6.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkChip extends StatelessWidget {
  final PlayableBookmark bookmark;
  final VoidCallback onTap;
  final List<NamidaPopupItem> Function() menuItems;

  const _BookmarkChip({
    required this.bookmark,
    required this.onTap,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final title = bookmark.title;
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: menuItems,
      child: NamidaInkWell(
        borderRadius: 8.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        bgColor: theme.cardColor.withOpacityExt(0.6),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160.0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: bookmark.positionMS.milliSecondsLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (title != null) TextSpan(text: '  $title'),
              ],
            ),
            style: theme.textTheme.displaySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
