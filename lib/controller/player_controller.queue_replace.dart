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
    final canKeepSingle = !shuffle && itemsCount > 1;
    final keepSingleSubtitle = canKeepSingle ? _getQueueItemTitle(queueList[index]) : null;
    final keepSubtitle = canKeepSingle ? itemsCountText : null;
    final action = await _pickQueueReplaceAction(subtitle: subtitle, keepSubtitle: keepSubtitle, keepSingleSubtitle: keepSingleSubtitle, canShowMore: isTracks);

    Iterable<Playable> getItems() {
      if (!shuffle) return queueList.skip(index);
      final shuffledItems = queueList.toList();
      shuffledItems.shuffle();
      return shuffledItems;
    }

    Future<void> playKeepingQueue(Iterable<Playable> items) async {
      final currentIndex = this.currentIndex.value;
      if (startPosition != null) _audioHandler.requestStartPosition(items.first, startPosition);
      _audioHandler.setPlayWhenReady(startPlaying);
      await _audioHandler.insertInQueue(items, currentIndex);
      await _audioHandler.userSkipToQueueItem(currentIndex);
    }

    switch (action) {
      case null:
        return false;
      case _QueueReplaceAction.replace:
        return true;
      case _QueueReplaceAction.keep:
        await playKeepingQueue(getItems());
      case _QueueReplaceAction.keepSingle:
        await playKeepingQueue([queueList[index]]);
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

  String? _getQueueItemTitle(Playable item) {
    return item.execute<String?>(
      selectable: (finalItem) => [finalItem.track.artistsList.firstOrNull, finalItem.track.title].joinText(separator: ' - '),
      youtubeID: (finalItem) => YoutubeInfoController.utils.getVideoNameSync(finalItem.id) ?? finalItem.id,
    );
  }

  Future<_QueueReplaceAction?> _pickQueueReplaceAction({
    required String subtitle,
    required String? keepSubtitle,
    required String? keepSingleSubtitle,
    required bool canShowMore,
  }) async {
    final latestInsertedIndex = this.latestInsertedIndex;
    final playAfterCount = latestInsertedIndex - currentIndex.value;
    String? playAfterTitle;
    String? playAfterSubtitle;
    if (playAfterCount > 0) {
      final playAfterItem = currentQueue.value[latestInsertedIndex];
      final playAfterCountText = playAfterItem is YoutubeID ? playAfterCount.displayVideoKeyword : playAfterCount.displayTrackKeyword;
      playAfterTitle = '${lang.playAfter}: $playAfterCountText';
      playAfterSubtitle = _getQueueItemTitle(playAfterItem);
    }

    _QueueReplaceAction? action;

    void onPick(_QueueReplaceAction picked) {
      action = picked;
      NamidaNavigator.inst.closeDialog();
    }

    await NamidaNavigator.inst.navigateDialog(
      dialog: _QueueReplaceDialog(
        subtitle: subtitle,
        keepSubtitle: keepSubtitle,
        keepSingleSubtitle: keepSingleSubtitle,
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
  final String? keepSubtitle;
  final String? keepSingleSubtitle;
  final String? playAfterTitle;
  final String? playAfterSubtitle;
  final bool canShowMore;
  final void Function(_QueueReplaceAction action) onPick;

  const _QueueReplaceDialog({
    required this.subtitle,
    required this.keepSubtitle,
    required this.keepSingleSubtitle,
    required this.playAfterTitle,
    required this.playAfterSubtitle,
    required this.canShowMore,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final playAfterTitle = this.playAfterTitle;
    final keepSingleSubtitle = this.keepSingleSubtitle;
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
                NamidaText(
                  lang.queue,
                  style: NText.large,
                ),
                NamidaText(
                  subtitle,
                  style: NText.small,
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
            subtitle: keepSubtitle,
            onTap: () => onPick(_QueueReplaceAction.keep),
          ),
          if (keepSingleSubtitle != null)
            CustomListTile(
              icon: Broken.music_square_add,
              title: '${lang.play} (${lang.keepQueue})',
              subtitle: keepSingleSubtitle,
              onTap: () => onPick(_QueueReplaceAction.keepSingle),
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
  keepSingle,
  playNext,
  playAfter,
  playLast,
  more,
}
