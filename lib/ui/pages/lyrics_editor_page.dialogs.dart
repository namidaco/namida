part of 'lyrics_editor_page.dart';

extension _LyricsEditorDialogs on _LyricsEditorPageState {
  List<NamidaPopupItem> _getMoreMenuItems() {
    final hasLines = _doc.lines.isNotEmpty;
    final latencyMS = settings.lyricsEditorLatencyMS.value;
    return [
      NamidaPopupItem(
        icon: Broken.document_text,
        title: lang.text,
        onTap: _showTextDialog,
      ),
      NamidaPopupItem(
        icon: Broken.eye,
        title: lang.preview,
        enabled: hasLines && _isCurrentItem.value,
        onTap: _preview,
      ),
      NamidaPopupItem(
        icon: Broken.timer_1,
        title: lang.offset,
        enabled: hasLines,
        onTap: _showShiftDialog,
      ),
      NamidaPopupItem(
        icon: Broken.maximize_4,
        title: lang.stretchLyricsDuration,
        enabled: hasLines,
        onTap: _showStretchDialog,
      ),
      NamidaPopupItem(
        icon: Broken.eraser,
        title: lang.clear,
        enabled: hasLines,
        onTap: () => _edit(_doc.clearTimestamps),
      ),
      NamidaPopupItem(
        icon: Broken.timer_pause,
        title: '${lang.latency}: ${latencyMS}ms',
        onTap: _showLatencyDialog,
      ),
      if (isDesktop)
        NamidaPopupItem(
          icon: Broken.keyboard,
          title: lang.shortcuts,
          onTap: _showShortcutsDialog,
        ),
      if (_hasDraft.value)
        NamidaPopupItem(
          icon: Broken.trash,
          title: lang.discard,
          onTap: _showDiscardDraftDialog,
        ),
    ];
  }

  List<NamidaPopupItem> _getLineMenuItems(int index) {
    final line = _doc.lines[index];
    final isTimed = line.startMS != null;
    return [
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.play,
        enabled: isTimed && _isCurrentItem.value,
        onTap: () => _playLine(index),
      ),
      NamidaPopupItem(
        icon: Broken.edit_2,
        title: lang.edit,
        onTap: () => _showLineEditDialog(index),
      ),
      NamidaPopupItem(
        icon: Broken.add_square,
        title: lang.add,
        onTap: () => _insertLineAfter(index),
      ),
      NamidaPopupItem(
        icon: Broken.eraser,
        title: lang.clear,
        enabled: isTimed,
        onTap: () => _clearLineTimestamps(index),
      ),
      NamidaPopupItem(
        icon: Broken.trash,
        title: lang.delete,
        onTap: () => _deleteLine(index),
      ),
    ];
  }

  List<NamidaPopupItem> _getWordMenuItems(int lineIndex, int wordIndex) {
    final line = _doc.lines[lineIndex];
    final wordsCount = line.words?.length ?? _EditorWord.splitText(line.text).length;
    return [
      NamidaPopupItem(
        icon: Broken.link,
        title: lang.merge,
        enabled: wordIndex + 1 < wordsCount,
        onTap: () => _edit(() {
          line.ensureWords();
          _doc.mergeWordWithNext(lineIndex, wordIndex);
        }),
      ),
      NamidaPopupItem(
        icon: Broken.scissor,
        title: lang.edit,
        onTap: () => _showWordEditDialog(lineIndex, wordIndex),
      ),
    ];
  }

  void _showLineEditDialog(int index) {
    final line = _doc.lines[index];
    final startMS = line.startMS;
    final timeText = startMS == null ? '' : _LyricsEditorPageState._formatMS(startMS);
    final timeController = TextEditingController(text: timeText);
    final textController = TextEditingController(text: line.text);
    final translationController = TextEditingController(text: line.translation);
    final personRx = Rxn<int>(line.person);

    void apply() {
      final newTimeText = timeController.text.trim();
      final newStartMS = newTimeText.isEmpty ? null : LrcParser.parseTimestamp(newTimeText)?.inMilliseconds;
      if (newTimeText.isNotEmpty && newStartMS == null) {
        snackyy(title: lang.error, message: newTimeText, isError: true);
        return;
      }
      final newText = _LyricsDocument.normalizeText(textController.text);
      final newTranslation = _LyricsDocument.normalizeText(translationController.text);
      final newPerson = personRx.value;
      final didChangeTime = newStartMS != line.startMS;
      _edit(() {
        if (newStartMS == null) {
          if (line.startMS != null) line.clearTimestamps();
        } else if (didChangeTime) {
          _doc.stampLine(index, newStartMS);
        }
        if (newText != line.text) line.setText(newText);
        line.translation = newTranslation;
        line.person = newPerson;
      });
      if (didChangeTime) _placeLineInTimeOrder(index);
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        timeController.dispose();
        textController.dispose();
        translationController.dispose();
        personRx.close();
      },
      dialog: CustomBlurryDialog(
        icon: Broken.edit_2,
        title: '${lang.edit} #${index + 1}',
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: apply,
          ),
        ],
        child: _LineEditDialogContent(
          timeController: timeController,
          textController: textController,
          translationController: translationController,
          personRx: personRx,
        ),
      ),
    );
  }

  /// all lines as plain text for bulk edits and pasting, see [_LyricsEditorPageState._applyText].
  void _showTextDialog() {
    final controller = TextEditingController(text: _doc.toPlainText());

    void apply() {
      _applyText(controller.text);
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: controller.dispose,
      dialog: CustomBlurryDialog(
        icon: Broken.document_text,
        title: lang.text,
        normalTitleStyle: true,
        scrollable: false,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: apply,
          ),
        ],
        child: _TextDialogContent(controller: controller),
      ),
    );
  }

  void _showWordEditDialog(int lineIndex, int wordIndex) {
    final line = _doc.lines[lineIndex];
    final words = line.words;
    final wordTexts = words == null ? _EditorWord.splitText(line.text) : [for (final w in words) w.text];
    final controller = TextEditingController(text: wordTexts[wordIndex]);

    void apply() {
      final pieces = controller.text.split('|').where((e) => e.isNotEmpty).toFixedList();
      if (pieces.isEmpty) return;
      _edit(() {
        line.ensureWords();
        _doc.replaceWord(lineIndex, wordIndex, pieces);
      });
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: controller.dispose,
      dialog: CustomBlurryDialog(
        icon: Broken.scissor,
        title: lang.edit,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: apply,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: CustomTagTextField(
            controller: controller,
            hintText: 'a|b',
            labelText: lang.text,
            icon: Broken.text,
            autofocus: true,
            onFieldSubmitted: (_) => apply(),
          ),
        ),
      ),
    );
  }

  void _showShiftDialog() {
    final deltaRx = 0.obs;
    final fromSelectedRx = false.obs;
    final selectedIndex = _selectedIndex.value;
    final lastIndex = _doc.lines.length - 1;

    void apply() {
      final deltaMS = deltaRx.value;
      final fromIndex = fromSelectedRx.value ? selectedIndex : 0;
      if (deltaMS != 0) _edit(() => _doc.shiftLines(fromIndex, lastIndex, deltaMS));
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        deltaRx.close();
        fromSelectedRx.close();
      },
      dialog: CustomBlurryDialog(
        icon: Broken.timer_1,
        title: lang.offset,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.confirm,
            onTap: apply,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MSValueEditor(valueRx: deltaRx),
              const SizedBox(
                height: 12.0,
              ),
              ObxO(
                rx: fromSelectedRx,
                builder: (context, fromSelected) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ChoiceChip(
                      text: lang.all,
                      isSelected: !fromSelected,
                      onTap: () => fromSelectedRx.value = false,
                    ),
                    const SizedBox(
                      width: 8.0,
                    ),
                    _ChoiceChip(
                      text: '#${selectedIndex + 1} - #${lastIndex + 1}',
                      isSelected: fromSelected,
                      onTap: () => fromSelectedRx.value = true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStretchDialog() {
    final controller = TextEditingController(text: '1.0');

    void apply() {
      final speed = double.tryParse(controller.text.trim());
      final isValid = speed != null && speed >= 0.25 && speed <= 4.0;
      if (!isValid) {
        snackyy(title: lang.error, message: controller.text, isError: true);
        return;
      }
      if (speed != 1.0) _edit(() => _doc.scaleAll(1.0 / speed));
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: controller.dispose,
      dialog: CustomBlurryDialog(
        icon: Broken.maximize_4,
        title: lang.stretchLyricsDuration,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.confirm,
            onTap: apply,
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: CustomTagTextField(
            controller: controller,
            hintText: '1.25',
            labelText: '${lang.speed} (x)',
            icon: Broken.forward,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onFieldSubmitted: (_) => apply(),
          ),
        ),
      ),
    );
  }

  void _showLatencyDialog() {
    final latencyRx = settings.lyricsEditorLatencyMS.value.obs;

    NamidaNavigator.inst.navigateDialog(
      onDisposing: latencyRx.close,
      dialog: CustomBlurryDialog(
        icon: Broken.timer_pause,
        title: lang.latency,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () {
              settings.lyricsEditorLatencyMS.save(latencyRx.value);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: _MSValueEditor(valueRx: latencyRx),
        ),
      ),
    );
  }

  void _showShortcutsDialog() {
    const seekStepSeconds = _LyricsEditorPageState._kSeekStepMS ~/ 1000;
    const nudgeStepMS = _LyricsEditorPageState._kNudgeStepMS;
    final shortcuts = [
      ('Enter', lang.sync),
      ('Space', '${lang.play} / ${lang.pause}'),
      ('← →', '-${seekStepSeconds}s / +${seekStepSeconds}s'),
      ('↑ ↓', '${lang.previous} / ${lang.next}'),
      ('[ ]', '${lang.offset} -${nudgeStepMS}ms / +${nudgeStepMS}ms'),
      ('Ctrl+Z', lang.undo),
      ('Ctrl+Y', lang.redo),
      ('Ctrl+S', lang.save),
    ];
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.keyboard,
        title: lang.shortcuts,
        normalTitleStyle: true,
        actions: const [
          CancelButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (keys, action) in shortcuts)
              _ShortcutRow(
                keys: keys,
                action: action,
              ),
          ],
        ),
      ),
    );
  }

  void _showDiscardDraftDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        title: lang.discardChanges,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.discard,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              _discardDraft();
            },
          ),
        ],
      ),
    );
  }

  /// the lines without a timestamp are left out of the saved file.
  Future<bool> _confirmUntimedLines() async {
    const maxShown = 4;
    final lines = _doc.lines;
    final untimedTexts = <String>[];
    for (int i = 0; i < lines.length && untimedTexts.length < maxShown; i++) {
      if (_doc.isUntimed(i)) untimedTexts.add(lines[i].text);
    }
    final remainingCount = _doc.untimedCount - untimedTexts.length;
    var confirmed = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        title: lang.warning,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () {
              confirmed = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: _UntimedLinesPreview(
          texts: untimedTexts,
          remainingCount: remainingCount,
        ),
      ),
    );
    return confirmed;
  }
}

class _TextDialogContent extends StatelessWidget {
  final TextEditingController controller;

  const _TextDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0.multipliedRadius),
      borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacityExt(0.15)),
    );
    final height = context.height * 0.55;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        height: height,
        child: TextField(
          controller: controller,
          expands: true,
          maxLines: null,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: theme.textTheme.displayMedium,
          decoration: InputDecoration(
            hintText: lang.lyrics,
            border: border,
            enabledBorder: border,
            contentPadding: const EdgeInsets.all(12.0),
          ),
        ),
      ),
    );
  }
}

class _LineEditDialogContent extends StatelessWidget {
  final TextEditingController timeController;
  final TextEditingController textController;
  final TextEditingController translationController;
  final Rxn<int> personRx;

  const _LineEditDialogContent({
    required this.timeController,
    required this.textController,
    required this.translationController,
    required this.personRx,
  });

  static const _kSingers = <int?>[null, 1, 2, 0];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTagTextField(
            controller: timeController,
            hintText: '00:00.00',
            labelText: lang.start,
            icon: Broken.timer_1,
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(
            height: 12.0,
          ),
          CustomTagTextField(
            controller: textController,
            hintText: lang.lyrics,
            labelText: lang.text,
            icon: Broken.text,
            maxLines: 3,
          ),
          const SizedBox(
            height: 12.0,
          ),
          CustomTagTextField(
            controller: translationController,
            hintText: lang.translation,
            labelText: lang.translation,
            icon: Broken.translate,
            maxLines: 3,
          ),
          const SizedBox(
            height: 12.0,
          ),
          ObxO(
            rx: personRx,
            builder: (context, person) => Row(
              children: [
                const SizedBox(
                  width: 4.0,
                ),
                const Icon(
                  Broken.microphone,
                  size: 20.0,
                ),
                const SizedBox(
                  width: 8.0,
                ),
                for (final singer in _kSingers)
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: _ChoiceChip(
                      text: singer == null ? '-' : _LyricsEditorPageState._singerLabel(singer),
                      isSelected: person == singer,
                      onTap: () => personRx.value = singer,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final void Function() onTap;

  const _ChoiceChip({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accentColor = theme.colorScheme.secondary;
    return NamidaInkWell(
      onTap: onTap,
      borderRadius: 8.0,
      animationDurationMS: 150,
      bgColor: isSelected ? accentColor.withOpacityExt(0.3) : theme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Text(
        text,
        style: theme.textTheme.displaySmall?.copyWith(fontWeight: isSelected ? FontWeight.w700 : null),
      ),
    );
  }
}

class _MSValueEditor extends StatefulWidget {
  final Rx<int> valueRx;

  const _MSValueEditor({required this.valueRx});

  @override
  State<_MSValueEditor> createState() => _MSValueEditorState();
}

class _MSValueEditorState extends State<_MSValueEditor> {
  static const _kStepMS = 10;
  static const _kHoldStepMS = 100;

  late final _controller = TextEditingController(text: '${widget.valueRx.value}');
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _setValue(int value) {
    widget.valueRx.value = value;
    _controller.text = '$value';
  }

  void _step(int deltaMS) => _setValue(widget.valueRx.value + deltaMS);

  void _startHold(int deltaMS) {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => _step(deltaMS));
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _onTextChanged(String text) {
    final parsed = int.tryParse(text.trim());
    if (parsed != null) widget.valueRx.value = parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NamidaIconButton(
          icon: Broken.minus_cirlce,
          iconSize: 24.0,
          onPressed: () => _step(-_kStepMS),
          onLongPressStart: (_) => _startHold(-_kHoldStepMS),
          onLongPressFinish: _stopHold,
        ),
        Expanded(
          child: CustomTagTextField(
            controller: _controller,
            hintText: '0',
            labelText: 'ms',
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onChanged: _onTextChanged,
          ),
        ),
        NamidaIconButton(
          icon: Broken.add_circle,
          iconSize: 24.0,
          onPressed: () => _step(_kStepMS),
          onLongPressStart: (_) => _startHold(_kHoldStepMS),
          onLongPressFinish: _stopHold,
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String action;

  const _ShortcutRow({
    required this.keys,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 86.0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  child: Text(
                    keys,
                    style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              action,
              style: textTheme.displayMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _UntimedLinesPreview extends StatelessWidget {
  final List<String> texts;
  final int remainingCount;

  const _UntimedLinesPreview({
    required this.texts,
    required this.remainingCount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final text in texts)
            Text(
              '--:--.--  $text',
              style: textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (remainingCount > 0)
            Text(
              '+$remainingCount',
              style: textTheme.displaySmall,
            ),
        ],
      ),
    );
  }
}
