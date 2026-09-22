part of '../party_page.dart';

const _kQueueItemExtent = 72.0;

class _PartyQueueSection extends StatefulWidget {
  const _PartyQueueSection();

  @override
  State<_PartyQueueSection> createState() => _PartyQueueSectionState();
}

class _PartyQueueSectionState extends State<_PartyQueueSection> {
  final _currentId = 0.obs;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final controller = PartyController.inst;
    final state = controller.state;
    _currentId.value = state.anchor.entryId;
    _scrollController = ScrollController(initialScrollOffset: state.currentIndex.withMinimum(0) * _kQueueItemExtent);
    controller.anchorTick.addListener(_onAnchorChanged);
  }

  @override
  void dispose() {
    PartyController.inst.anchorTick.removeListener(_onAnchorChanged);
    _currentId.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAnchorChanged() => _currentId.value = PartyController.inst.state.anchor.entryId;

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return _MyPermissionsBuilder(
      builder: (context, me) => Column(
        children: [
          _NowPlayingCard(me: me),
          Expanded(
            child: ObxO(
              rx: controller.queueTick,
              builder: (context, _) {
                final state = controller.state;
                final entries = state.entries;
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      lang.partyQueueEmpty,
                      style: context.theme.textTheme.displayMedium,
                    ),
                  );
                }
                final canControl = me != null && state.canControl(me);
                final binder = controller.binder;
                return NamidaScrollbar(
                  controller: _scrollController,
                  child: SuperSmoothListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 8.0),
                    itemExtent: _kQueueItemExtent,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _QueueEntryTile(
                        key: ValueKey(entry.id),
                        entry: entry,
                        currentId: _currentId,
                        addedBy: state.members[entry.by]?.name,
                        isUnavailable: binder?.isUnavailable(entry) == true,
                        canControl: canControl,
                        canRemove: me != null && state.canEditEntry(me, entry),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPermissionsBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, PartyMember? me) builder;

  const _MyPermissionsBuilder({required this.builder});

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    return ObxO(
      rx: controller.infoTick,
      builder: (context, _) => ObxO(
        rx: controller.membersTick,
        builder: (context, _) => builder(context, controller.me),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final PartyMember? me;

  const _NowPlayingCard({required this.me});

  @override
  Widget build(BuildContext context) {
    final controller = PartyController.inst;
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Container(
      margin: const EdgeInsets.all(12.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacityExt(0.6),
        borderRadius: BorderRadius.circular(20.0.multipliedRadius),
      ),
      child: ObxO(
        rx: controller.queueTick,
        builder: (context, _) => ObxO(
          rx: controller.anchorTick,
          builder: (context, _) {
            final state = controller.state;
            final me = this.me;
            final anchor = state.anchor;
            final entry = state.currentEntry;
            final canControl = me != null && entry != null && state.canControl(me);
            final iconColor = canControl ? context.defaultIconColor() : theme.disabledColor;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      entry == null || entry.isLocal ? Broken.musicnote : Broken.video_square,
                      size: 22.0,
                      color: context.defaultIconColor(),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry == null ? lang.partyQueueEmpty : entry.title,
                            style: textTheme.displayMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (entry != null && entry.artist.isNotEmpty)
                            Text(
                              entry.artist,
                              style: textTheme.displaySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const _SyncStateChip(
                      padding: EdgeInsetsDirectional.only(start: 8.0),
                    ),
                  ],
                ),
                _PositionBar(
                  anchor: anchor,
                  durationMS: entry?.durationMS ?? 0,
                  enabled: canControl,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NamidaIconButton(
                      icon: Broken.previous,
                      iconSize: 24.0,
                      iconColor: iconColor,
                      tooltip: () => lang.previous,
                      onPressed: canControl ? () => controller.sendCommand(const PartyMsg.previous()) : null,
                    ),
                    const SizedBox(width: 8.0),
                    NamidaIconButton(
                      icon: anchor.playing ? Broken.pause : Broken.play,
                      iconSize: 32.0,
                      iconColor: iconColor,
                      onPressed: canControl ? () => controller.sendCommand(anchor.playing ? const PartyMsg.pause() : const PartyMsg.play()) : null,
                    ),
                    const SizedBox(width: 8.0),
                    NamidaIconButton(
                      icon: Broken.next,
                      iconSize: 24.0,
                      iconColor: iconColor,
                      tooltip: () => lang.next,
                      onPressed: canControl ? () => controller.sendCommand(const PartyMsg.next()) : null,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PositionBar extends StatefulWidget {
  final PartyAnchor anchor;
  final int durationMS;
  final bool enabled;

  const _PositionBar({
    required this.anchor,
    required this.durationMS,
    required this.enabled,
  });

  @override
  State<_PositionBar> createState() => _PositionBarState();
}

class _PositionBarState extends State<_PositionBar> {
  Timer? _timer;
  double? _draggingMS;

  @override
  void initState() {
    super.initState();
    _refreshTimer();
  }

  @override
  void didUpdateWidget(covariant _PositionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor.playing != widget.anchor.playing) _refreshTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshTimer() {
    if (!widget.anchor.playing) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final durationMS = widget.durationMS;
    final maxMS = durationMS > 0 ? durationMS.toDouble() : 1.0;
    final positionMS = _draggingMS ?? widget.anchor.positionAt(PartyController.inst.nowMS()).toDouble().clampDouble(0.0, maxMS);
    final textStyle = context.theme.textTheme.displaySmall;
    return Row(
      children: [
        Text(
          positionMS.round().milliSecondsLabel,
          style: textStyle,
        ),
        Expanded(
          child: Slider.adaptive(
            max: maxMS,
            value: positionMS,
            onChanged: widget.enabled && durationMS > 0 ? (value) => setState(() => _draggingMS = value) : null,
            onChangeEnd: (value) {
              PartyController.inst.sendCommand(PartyMsg.seek(value.round()));
              setState(() => _draggingMS = null);
            },
          ),
        ),
        Text(
          durationMS.milliSecondsLabel,
          style: textStyle,
        ),
      ],
    );
  }
}

class _QueueEntryTile extends StatelessWidget {
  final PartyEntry entry;
  final RxBase<int> currentId;
  final String? addedBy;
  final bool isUnavailable;
  final bool canControl;
  final bool canRemove;

  const _QueueEntryTile({
    super.key,
    required this.entry,
    required this.currentId,
    required this.addedBy,
    required this.isUnavailable,
    required this.canControl,
    required this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final addedBy = this.addedBy;
    final artist = entry.artist;
    final subtitle = addedBy == null
        ? artist
        : artist.isEmpty
        ? lang.partyAddedBy(name: addedBy)
        : '$artist  •  ${lang.partyAddedBy(name: addedBy)}';
    final content = Row(
      children: [
        Icon(
          entry.isLocal ? Broken.musicnote : Broken.video_square,
          size: 20.0,
          color: context.defaultIconColor(),
        ),
        if (entry.fallbackApproximate)
          NamidaTooltip(
            message: () => lang.partyApproximateMatch,
            child: const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(
                Broken.info_circle,
                size: 14.0,
                color: Colors.orange,
              ),
            ),
          ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: textTheme.displayMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: textTheme.displaySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (isUnavailable)
                Text(
                  lang.partyUnavailableHere,
                  style: textTheme.displaySmall?.copyWith(fontSize: 11.0, color: Colors.orange),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8.0),
        Text(
          entry.durationMS.milliSecondsLabel,
          style: textTheme.displaySmall,
        ),
        if (canRemove)
          NamidaIconButton(
            icon: Broken.close_circle,
            iconSize: 20.0,
            tooltip: () => lang.remove,
            onPressed: () => PartyController.inst.sendCommand(PartyMsg.remove([entry.id])),
          ),
      ],
    );
    final currentColor = theme.colorScheme.primary.withOpacityExt(0.15);
    return ObxO(
      rx: currentId,
      builder: (context, currentId) => NamidaInkWell(
        borderRadius: 12.0,
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        bgColor: currentId == entry.id ? currentColor : null,
        onTap: canControl ? () => PartyController.inst.sendCommand(PartyMsg.skip(entry.id)) : null,
        child: content,
      ),
    );
  }
}
