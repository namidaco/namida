// by claude
part of 'player_controller.dart';

extension _QueueReplaceConfirmation on Player {
  Future<bool> _askBeforeReplacingQueue(
    List<Playable> queueList,
    int index,
    QueueSourceBase source, {
    required bool shuffle,
    required bool startPlaying,
    required Duration? startPosition,
  }) async {
    final isTracks = queueList.first is Selectable;
    final itemsCount = shuffle ? queueList.length : queueList.length - index;
    final itemsCountText = isTracks ? itemsCount.displayTrackKeyword : itemsCount.displayVideoKeyword;
    final subtitle = [itemsCountText, source.title].joinText();
    final action = await _pickQueueReplaceAction(subtitle: subtitle, canShowMore: isTracks);

    Iterable<Playable> getItems() {
      if (!shuffle) return queueList.skip(index);
      final shuffledItems = queueList.toList();
      shuffledItems.shuffle();
      return shuffledItems;
    }

    switch (action) {
      case null:
        return false;
      case _QueueReplaceAction.replace:
        return true;
      case _QueueReplaceAction.keep:
        final items = getItems();
        final currentIndex = this.currentIndex.value;
        if (startPosition != null) _audioHandler.requestStartPosition(items.first, startPosition);
        _audioHandler.setPlayWhenReady(startPlaying);
        await _audioHandler.insertInQueue(items, currentIndex);
        await _audioHandler.userSkipToQueueItem(currentIndex);
      case _QueueReplaceAction.playNext:
        await addToQueue(getItems(), insertNext: true);
      case _QueueReplaceAction.playAfter:
        await addToQueue(getItems(), insertAfterLatest: true);
      case _QueueReplaceAction.playLast:
        await addToQueue(getItems());
      case _QueueReplaceAction.more:
        final tracks = getItems().whereType<Selectable>().map((e) => e.track).toFixedList();
        if (tracks.length == 1) {
          await NamidaDialogs.inst.showTrackDialog(tracks.first, source: source);
        } else {
          final title = source.title ?? source.toText();
          final subtitle = [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - ');
          await showGeneralPopupDialog(tracks, title, subtitle, source);
        }
    }
    return false;
  }

  Future<_QueueReplaceAction?> _pickQueueReplaceAction({required String subtitle, required bool canShowMore}) async {
    final latestInsertedIndex = this.latestInsertedIndex;
    final playAfterCount = latestInsertedIndex - currentIndex.value;
    String? playAfterTitle;
    String? playAfterSubtitle;
    if (playAfterCount > 0) {
      final playAfterItem = currentQueue.value[latestInsertedIndex];
      final playAfterCountText = playAfterItem is YoutubeID ? playAfterCount.displayVideoKeyword : playAfterCount.displayTrackKeyword;
      playAfterTitle = '${lang.playAfter}: $playAfterCountText';
      playAfterSubtitle = playAfterItem.execute<String?>(
        selectable: (finalItem) => [finalItem.track.artistsList.firstOrNull, finalItem.track.title].joinText(separator: ' - '),
        youtubeID: (finalItem) => YoutubeInfoController.utils.getVideoNameSync(finalItem.id),
      );
    }

    _QueueReplaceAction? action;

    void onPick(_QueueReplaceAction picked) {
      action = picked;
      NamidaNavigator.inst.closeDialog();
    }

    await NamidaNavigator.inst.navigateDialog(
      dialog: _QueueReplaceDialog(
        subtitle: subtitle,
        playAfterTitle: playAfterTitle,
        playAfterSubtitle: playAfterSubtitle,
        canShowMore: canShowMore,
        onPick: onPick,
      ),
    );
    return action;
  }
}

class _QueueReplaceDialog extends StatelessWidget {
  final String subtitle;
  final String? playAfterTitle;
  final String? playAfterSubtitle;
  final bool canShowMore;
  final void Function(_QueueReplaceAction action) onPick;

  const _QueueReplaceDialog({
    required this.subtitle,
    required this.playAfterTitle,
    required this.playAfterSubtitle,
    required this.canShowMore,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final playAfterTitle = this.playAfterTitle;
    return CustomBlurryDialog(
      titleWidgetInPadding: Row(
        children: [
          const Icon(
            Broken.row_vertical,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.queue,
                  style: textTheme.displayLarge,
                ),
                Text(
                  subtitle,
                  style: textTheme.displaySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: const [
        CancelButton(),
      ],
      child: Column(
        children: [
          const SizedBox(height: 12.0),
          CustomListTile(
            icon: Broken.additem,
            title: '${lang.play} (${lang.keepQueue})',
            onTap: () => onPick(_QueueReplaceAction.keep),
          ),
          CustomListTile(
            icon: Broken.play,
            title: '${lang.play} (${lang.replaceQueue})',
            subtitle: lang.defaultLabel,
            onTap: () => onPick(_QueueReplaceAction.replace),
          ),
          CustomListTile(
            icon: Broken.next,
            title: lang.playNext,
            onTap: () => onPick(_QueueReplaceAction.playNext),
          ),
          if (playAfterTitle != null)
            CustomListTile(
              icon: Broken.hierarchy_square,
              title: playAfterTitle,
              subtitle: playAfterSubtitle,
              onTap: () => onPick(_QueueReplaceAction.playAfter),
            ),
          CustomListTile(
            icon: Broken.play_cricle,
            title: lang.playLast,
            onTap: () => onPick(_QueueReplaceAction.playLast),
          ),
          if (canShowMore)
            CustomListTile(
              icon: Broken.more_2,
              title: lang.more,
              onTap: () => onPick(_QueueReplaceAction.more),
            ),
        ],
      ),
    );
  }
}

enum _QueueReplaceAction {
  replace,
  keep,
  playNext,
  playAfter,
  playLast,
  more,
}
