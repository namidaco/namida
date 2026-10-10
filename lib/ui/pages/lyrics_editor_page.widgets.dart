part of 'lyrics_editor_page.dart';

class _EditorHeader extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _EditorHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return SizedBox(
      height: 46.0,
      child: Row(
        children: [
          NamidaIconButton(
            horizontalPadding: 8.0,
            verticalPadding: 6.0,
            icon: Broken.arrow_left_1,
            iconSize: 22.0,
            onPressed: NamidaNavigator.inst.popRoot,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      lang.lyrics,
                      style: textTheme.displayMedium,
                      maxLines: 1,
                    ),
                    ObxO(
                      rx: state._hasDraft,
                      builder: (context, hasDraft) => hasDraft ? const _DraftBadge() : const SizedBox(),
                    ),
                  ],
                ),
                Text(
                  state.widget.lrcUtils.initialSearchTextHint,
                  style: textTheme.displaySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ObxO(
            rx: state._canUndo,
            builder: (context, canUndo) => _HeaderIconButton(
              icon: Broken.undo,
              tooltip: lang.undo,
              enabled: canUndo,
              onPressed: state._undo,
            ),
          ),
          ObxO(
            rx: state._canRedo,
            builder: (context, canRedo) => _HeaderIconButton(
              icon: Broken.redo,
              tooltip: lang.redo,
              enabled: canRedo,
              onPressed: state._redo,
            ),
          ),
          const SizedBox(
            width: 4.0,
          ),
          _SaveButton(state: state),
          NamidaPopupWrapper(
            childrenDefault: state._getMoreMenuItems,
            child: const MoreIcon(
              padding: 6.0,
              iconSize: 20.0,
            ),
          ),
          const SizedBox(
            width: 2.0,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final void Function() onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.35,
      child: NamidaIconButton(
        horizontalPadding: 6.0,
        verticalPadding: 6.0,
        icon: icon,
        iconSize: 20.0,
        tooltip: () => tooltip,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacityExt(0.5),
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
      ),
      child: Text(
        lang.draft,
        style: theme.textTheme.displaySmall?.copyWith(fontSize: 10.0),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _SaveButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ObxO(
      rx: state._isSaving,
      builder: (context, isSaving) {
        if (isSaving) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ThreeArchedCircle(
              color: theme.colorScheme.secondary,
              size: 22.0,
            ),
          );
        }
        final face = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacityExt(0.2),
            borderRadius: BorderRadius.circular(10.0.multipliedRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Broken.document_download,
                  size: 18.0,
                ),
                const SizedBox(
                  width: 4.0,
                ),
                Text(
                  lang.save,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
        if (state._embeddableTrack == null) {
          return NamidaInkWell(
            borderRadius: 10.0,
            onTap: () => state._save(embed: false),
            child: face,
          );
        }
        return NamidaPopupWrapper(
          childrenDefault: () => [
            NamidaPopupItem(
              icon: Broken.document_download,
              title: lang.save,
              onTap: () => state._save(embed: false),
            ),
            NamidaPopupItem(
              icon: Broken.document_code,
              title: lang.embed,
              onTap: () => state._save(embed: true),
            ),
          ],
          child: face,
        );
      },
    );
  }
}

class _LinesList extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _LinesList({required this.state});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: state._revision,
      builder: (context, _) {
        final lines = state._doc.lines;
        if (lines.isEmpty) {
          return Center(
            child: NamidaButton(
              icon: Broken.document_text,
              text: lang.text,
              onTap: state._showTextDialog,
            ),
          );
        }
        return NotificationListener<UserScrollNotification>(
          onNotification: state._onUserScroll,
          child: CustomScrollView(
            controller: state._scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 12.0),
                sliver: NamidaSliverReorderableList(
                  itemExtent: _LyricsEditorPageState._kRowExtent,
                  itemCount: lines.length,
                  longPressToDrag: false,
                  onReorder: state._moveLine,
                  itemBuilder: (context, i) {
                    final line = lines[i];
                    return _LineRow(
                      key: ObjectKey(line),
                      state: state,
                      index: i,
                      line: line,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LineRow extends StatelessWidget {
  final _LyricsEditorPageState state;
  final int index;
  final _EditorLine line;

  const _LineRow({
    super.key,
    required this.state,
    required this.index,
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final doc = state._doc;
    final isUntimed = doc.isUntimed(index);
    final hasWarning = doc.hasWarning(index);
    final startMS = line.startMS;
    final timestampText = startMS == null ? '--:--.--' : _LyricsEditorPageState._formatMS(startMS);
    final timestampColor = isUntimed
        ? colorScheme.onSurface.withOpacityExt(0.4)
        : hasWarning
        ? Colors.orange
        : colorScheme.onSurface;
    final translation = line.translation;
    final hasTranslation = translation.isNotEmpty;
    final person = line.person;

    final textWidget = line.text.isEmpty
        ? Icon(
            Broken.music,
            size: 18.0,
            color: colorScheme.onSurface.withOpacityExt(0.5),
          )
        : Text(
            line.text,
            style: textTheme.displayMedium,
            maxLines: hasTranslation ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          );

    final lineContentWidget = Row(
      children: [
        Text(
          timestampText,
          style: textTheme.displaySmall?.copyWith(
            color: timestampColor,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(
          width: 12.0,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textWidget,
              if (hasTranslation)
                Text(
                  translation,
                  style: textTheme.displaySmall?.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (line.hasTimedWords())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              Broken.text,
              size: 14.0,
              color: colorScheme.secondary,
            ),
          ),
        if (person != null) _SingerBadge(person: person),
        const SizedBox(
          width: 6.0,
        ),
      ],
    );

    // -- the handle stays out of the popup, its long press would race the drag
    final contentWidget = Row(
      children: [
        SizedBox(
          width: 24.0,
          child: Text(
            '${index + 1}',
            style: textTheme.displaySmall?.copyWith(
              fontSize: 10.0,
              color: colorScheme.onSurface.withOpacityExt(0.45),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
        NamidaReordererableListener(
          index: index,
          child: const ColoredBox(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
              child: ThreeLineSmallContainers(
                enabled: true,
              ),
            ),
          ),
        ),
        Expanded(
          child: NamidaPopupWrapper(
            openOnTap: false,
            onTap: () => state._selectAndSeek(index),
            childrenDefault: () => state._getLineMenuItems(index),
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: lineContentWidget,
              ),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
      child: ListenableBuilder(
        listenable: state._rowStateListenable,
        builder: (context, child) {
          final isSelected = state._selectedIndex.value == index;
          final isPlaying = state._playingIndex.value == index;
          final accentColor = colorScheme.secondary;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isPlaying ? accentColor.withOpacityExt(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(10.0.multipliedRadius),
              border: Border.all(
                color: isSelected ? accentColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: child,
          );
        },
        child: contentWidget,
      ),
    );
  }
}

class _SingerBadge extends StatelessWidget {
  final int person;

  const _SingerBadge({required this.person});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacityExt(0.6),
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
        child: Text(
          _LyricsEditorPageState._singerLabel(person),
          style: theme.textTheme.displaySmall?.copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _ControlsPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 6.0,
        ),
        _EditorTimeline(state: state),
        const SizedBox(
          height: 4.0,
        ),
        _SelectedLineTools(state: state),
        ObxO(
          rx: state._isWordMode,
          builder: (context, isWordMode) => isWordMode ? _WordChips(state: state) : const SizedBox(),
        ),
        _TransportRow(state: state),
        const SizedBox(
          height: 12.0,
        ),
        _StampButton(state: state),
      ],
    );
  }
}

class _SelectedLineTools extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _SelectedLineTools({required this.state});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    const nudgeStepMS = _LyricsEditorPageState._kNudgeStepMS;
    return ListenableBuilder(
      listenable: state._selectionListenable,
      builder: (context, _) {
        final lines = state._doc.lines;
        final index = state._selectedIndex.value;
        if (index >= lines.length) {
          return const SizedBox(
            height: 40.0,
          );
        }
        final line = lines[index];
        final startMS = line.startMS;
        final timestampText = startMS == null ? '--:--.--' : _LyricsEditorPageState._formatMS(startMS);
        return SizedBox(
          height: 40.0,
          child: Row(
            children: [
              const SizedBox(
                width: 6.0,
              ),
              Text(
                '#${index + 1}',
                style: textTheme.displayMedium,
              ),
              const SizedBox(
                width: 8.0,
              ),
              NamidaInkWell(
                onTap: () => state._showLineEditDialog(index),
                borderRadius: 6.0,
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                child: Text(
                  timestampText,
                  style: textTheme.displayMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              const Spacer(),
              NamidaIconButton(
                horizontalPadding: 6.0,
                icon: Broken.minus_cirlce,
                iconSize: 22.0,
                tooltip: () => '-${nudgeStepMS}ms',
                onPressed: () => state._nudgeSelected(-nudgeStepMS),
                onLongPressStart: (_) => state._startNudgeRepeat(-nudgeStepMS),
                onLongPressFinish: state._stopNudgeRepeat,
              ),
              NamidaIconButton(
                horizontalPadding: 6.0,
                icon: Broken.add_circle,
                iconSize: 22.0,
                tooltip: () => '+${nudgeStepMS}ms',
                onPressed: () => state._nudgeSelected(nudgeStepMS),
                onLongPressStart: (_) => state._startNudgeRepeat(nudgeStepMS),
                onLongPressFinish: state._stopNudgeRepeat,
              ),
              NamidaIconButton(
                horizontalPadding: 6.0,
                icon: Broken.play_cricle,
                iconSize: 22.0,
                tooltip: () => lang.play,
                onPressed: () => state._playLine(index),
              ),
              NamidaIconButton(
                horizontalPadding: 6.0,
                icon: Broken.edit_2,
                iconSize: 20.0,
                tooltip: () => lang.edit,
                onPressed: () => state._showLineEditDialog(index),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WordChips extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _WordChips({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state._selectionListenable,
      builder: (context, _) {
        final lines = state._doc.lines;
        final index = state._selectedIndex.value;
        if (index >= lines.length) return const SizedBox();
        final line = lines[index];
        final words = line.words;
        final wordTexts = words == null ? _EditorWord.splitText(line.text) : [for (final w in words) w.text];
        if (wordTexts.isEmpty) return const SizedBox();
        final cursor = state._wordIndex.value;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 76.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Wrap(
              spacing: 4.0,
              runSpacing: 4.0,
              children: [
                for (int i = 0; i < wordTexts.length; i++)
                  _WordChip(
                    text: wordTexts[i].trim(),
                    isTimed: words?[i].startMS != null,
                    isCursor: i == cursor,
                    onTap: () => state._wordIndex.value = i,
                    menuItems: () => state._getWordMenuItems(index, i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WordChip extends StatelessWidget {
  final String text;
  final bool isTimed;
  final bool isCursor;
  final void Function() onTap;
  final List<NamidaPopupItem> Function() menuItems;

  const _WordChip({
    required this.text,
    required this.isTimed,
    required this.isCursor,
    required this.onTap,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accentColor = theme.colorScheme.secondary;
    return NamidaPopupWrapper(
      openOnTap: false,
      onTap: onTap,
      childrenDefault: menuItems,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isTimed ? accentColor.withOpacityExt(0.25) : theme.scaffoldBackgroundColor.withOpacityExt(0.5),
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
          border: Border.all(
            color: isCursor ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            text,
            style: theme.textTheme.displaySmall,
          ),
        ),
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  final _LyricsEditorPageState state;

  const _TransportRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final accentColor = theme.colorScheme.secondary;
    const seekStepMS = _LyricsEditorPageState._kSeekStepMS;
    const seekStepSeconds = seekStepMS ~/ 1000;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ObxO(
          rx: state._isWordMode,
          builder: (context, isWordMode) => NamidaInkWell(
            onTap: state._toggleWordMode,
            borderRadius: 10.0,
            bgColor: isWordMode ? accentColor.withOpacityExt(0.3) : null,
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: lang.wordByWord,
              child: const Icon(
                Broken.text,
                size: 20.0,
              ),
            ),
          ),
        ),
        NamidaIconButton(
          icon: Broken.backward,
          iconSize: 22.0,
          tooltip: () => '-${seekStepSeconds}s',
          onPressed: () => state._seekBy(-seekStepMS),
        ),
        ObxO(
          rx: state._isCurrentItem,
          builder: (context, isCurrentItem) => ObxO(
            rx: Player.inst.isPlaying,
            builder: (context, isPlaying) => NamidaIconButton(
              icon: isCurrentItem && isPlaying ? Broken.pause_circle : Broken.play_cricle,
              iconSize: 34.0,
              tooltip: () => isCurrentItem && isPlaying ? lang.pause : lang.play,
              onPressed: state._togglePlay,
            ),
          ),
        ),
        NamidaIconButton(
          icon: Broken.forward,
          iconSize: 22.0,
          tooltip: () => '+${seekStepSeconds}s',
          onPressed: () => state._seekBy(seekStepMS),
        ),
        ObxO(
          rx: Player.inst.currentSpeed,
          builder: (context, speed) => NamidaInkWell(
            onTap: state._cycleSpeed,
            borderRadius: 10.0,
            bgColor: speed != 1.0 ? accentColor.withOpacityExt(0.3) : null,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Tooltip(
              message: lang.speed,
              child: SizedBox(
                width: 38.0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${speed.toStringAsFixed(2)}x',
                    style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// press stamps the line (or the word start), release stamps the word end.
class _StampButton extends StatefulWidget {
  final _LyricsEditorPageState state;

  const _StampButton({required this.state});

  @override
  State<_StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<_StampButton> {
  late final _labelListenable = Listenable.merge([
    widget.state._selectionListenable,
    widget.state._isWordMode,
    widget.state._isCurrentItem,
  ]);

  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent _) {
    if (!widget.state._isCurrentItem.value) return;
    setState(() => _isPressed = true);
    widget.state._onStampDown();
  }

  void _onPointerUp(PointerUpEvent _) {
    final state = widget.state;
    if (!state._isCurrentItem.value) {
      state._playItem();
      return;
    }
    _release();
  }

  void _onPointerCancel(PointerCancelEvent _) => _release();

  void _release() {
    if (_isPressed) setState(() => _isPressed = false);
    widget.state._onStampUp();
  }

  String _getLabel() {
    final state = widget.state;
    if (!state._isCurrentItem.value) return lang.play;
    final lines = state._doc.lines;
    final index = state._selectedIndex.value;
    if (index >= lines.length) return lang.sync;
    final line = lines[index];
    if (!state._isWordMode.value || line.text.isEmpty) return '${lang.sync}  #${index + 1}';
    final words = line.words;
    final wordTexts = words == null ? _EditorWord.splitText(line.text) : [for (final w in words) w.text];
    final wordIndex = state._wordIndex.value.withMaximum(wordTexts.length - 1);
    return wordTexts[wordIndex].trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accentColor = theme.colorScheme.secondary;
    final buttonWidget = Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 46.0,
        decoration: BoxDecoration(
          color: accentColor.withOpacityExt(_isPressed ? 0.6 : 0.3),
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        ),
        alignment: Alignment.center,
        child: ListenableBuilder(
          listenable: _labelListenable,
          builder: (context, _) {
            final isCurrentItem = widget.state._isCurrentItem.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCurrentItem ? Broken.timer_1 : Broken.play,
                  size: 18.0,
                ),
                const SizedBox(
                  width: 8.0,
                ),
                Flexible(
                  child: Text(
                    _getLabel(),
                    style: theme.textTheme.displayMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (!isDesktop) return buttonWidget;
    return Tooltip(
      message: 'Enter',
      child: buttonWidget,
    );
  }
}
