// rewritten by claude, new one groups shortcuts into responsive cards and records global shortcuts inline

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/shortcut_data.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class ShortcutsDialog extends StatefulWidget {
  final ShortcutsManager manager;
  const ShortcutsDialog({super.key, required this.manager});

  @override
  State<ShortcutsDialog> createState() => _ShortcutsDialogState();
}

class _ShortcutsDialogState extends State<ShortcutsDialog> {
  static const _kDialogMaxWidth = 1040.0;
  static const _kMinCardWidth = 300.0;
  static const _kCardsSpacing = 12.0;
  static const _kSectionHeaderRows = 2;

  late final _sections = _buildSections(widget.manager.bindings.keys);
  late final _globalActions = _GlobalShortcutActions(
    toggleRecording: _toggleRecording,
    findConflictTitle: _findConflictTitle,
    save: _saveGlobalShortcut,
    delete: _deleteGlobalShortcut,
    cancel: _stopRecording,
  );
  final _searchController = TextEditingController();
  String _query = '';
  HotkeyAction? _recordingAction;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static List<_ShortcutsSection> _buildSections(Iterable<ShortcutKeyActivator> activators) {
    final activatorsByCategory = <ShortcutCategory, Map<String, List<ShortcutKeyActivator>>>{};
    for (final activator in activators) {
      final activatorsByTitle = activatorsByCategory[activator.category] ??= <String, List<ShortcutKeyActivator>>{};
      activatorsByTitle.addForce(activator.title(), activator);
    }

    final sections = <_ShortcutsSection>[];
    for (final category in ShortcutCategory.values) {
      final activatorsByTitle = activatorsByCategory[category];
      if (activatorsByTitle == null) continue;
      final rows = activatorsByTitle.entries.map((e) => _ShortcutRowData.fromActivators(e.key, e.value)).toFixedList();
      sections.add(_ShortcutsSection(category: category, rows: rows));
    }
    return sections;
  }

  static List<List<_VisibleSection>> _distributeToColumns(List<_VisibleSection> sections, int columnsCount) {
    final columns = List.generate(columnsCount, (_) => <_VisibleSection>[]);
    final columnsRowsCount = List.filled(columnsCount, 0);
    for (final section in sections) {
      int shortestIndex = 0;
      for (int i = 1; i < columnsCount; i++) {
        if (columnsRowsCount[i] < columnsRowsCount[shortestIndex]) shortestIndex = i;
      }
      columns[shortestIndex].add(section);
      columnsRowsCount[shortestIndex] += section.rows.length + _kSectionHeaderRows;
    }
    return columns;
  }

  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    setState(() => _query = query);
  }

  void _toggleRecording(HotkeyAction action) {
    final newRecordingAction = _recordingAction == action ? null : action;
    setState(() => _recordingAction = newRecordingAction);
  }

  void _stopRecording() {
    if (_recordingAction == null) return;
    setState(() => _recordingAction = null);
  }

  Future<void> _saveGlobalShortcut(HotkeyAction action, ShortcutKeyData data) async {
    await widget.manager.setUserShortcut(action: action, data: data);
    if (mounted) _stopRecording();
  }

  Future<void> _deleteGlobalShortcut(HotkeyAction action) async {
    await widget.manager.setUserShortcut(action: action, data: null);
    if (mounted) _stopRecording();
  }

  String? _findConflictTitle(HotkeyAction action, ShortcutKeyData data) {
    final activators = widget.manager.bindings.keys;

    // -- its not likely for already registered system hotkeys to be caught again here, but anyways
    for (final MapEntry(key: userAction, value: userKey) in settings.shortcuts.shortcuts.value.entries) {
      if (userAction == action || userKey == null) continue;
      if (data.isSimilarTo(userKey)) {
        final userActionActivator = activators.firstWhereEff((k) => k.action == userAction);
        return userActionActivator?.title() ?? userAction.name;
      }
    }

    for (final activator in activators) {
      final activatorData = ShortcutKeyData.fromShortcutKeyActivator(activator);
      if (data.isSimilarTo(activatorData)) return activator.title();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final visibleSections = _sections.map((e) => (section: e, rows: e.filterRows(query))).where((e) => e.rows.isNotEmpty).toFixedList();
    return CustomBlurryDialog(
      icon: Broken.flash_1,
      title: lang.shortcuts,
      normalTitleStyle: true,
      maxWidth: _kDialogMaxWidth,
      trailingWidgets: [
        SizedBox(
          width: 160.0,
          child: CustomTagTextField(
            controller: _searchController,
            hintText: lang.search,
            labelText: '',
            icon: Broken.search_normal,
            maxLines: 1,
            height: 38.0,
            borderRadius: 12.0,
            onChanged: _onSearchChanged,
          ),
        ),
      ],
      actions: const [
        DoneButton(),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: _NonShrinkingHeight(
          child: LayoutWidthProvider(
            builder: (context, maxWidth) {
              final fittingColumns = ((maxWidth + _kCardsSpacing) / (_kMinCardWidth + _kCardsSpacing)).floor();
              final columnsCount = fittingColumns.withMinimum(1);
              final columns = _distributeToColumns(visibleSections, columnsCount);
              return ObxO(
                rx: settings.shortcuts.shortcuts,
                builder: (context, userShortcuts) => SmoothSingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: _kCardsSpacing,
                    children: columns
                        .map(
                          (columnSections) => Expanded(
                            child: Column(
                              spacing: _kCardsSpacing,
                              children: columnSections
                                  .map(
                                    (e) => _SectionCard(
                                      section: e.section,
                                      rows: e.rows,
                                      userShortcuts: userShortcuts,
                                      recordingAction: _recordingAction,
                                      globalActions: _globalActions,
                                    ),
                                  )
                                  .toFixedList(),
                            ),
                          ),
                        )
                        .toFixedList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _ShortcutsSection section;
  final List<_ShortcutRowData> rows;
  final Map<HotkeyAction, ShortcutKeyData?> userShortcuts;
  final HotkeyAction? recordingAction;
  final _GlobalShortcutActions globalActions;

  const _SectionCard({
    required this.section,
    required this.rows,
    required this.userShortcuts,
    required this.recordingAction,
    required this.globalActions,
  });

  @override
  Widget build(BuildContext context) {
    final category = section.category;
    return NContainer(
      padding: const EdgeInsets.fromLTRB(14.0, 8.0, 12.0, 10.0),
      decoration: (colors) => BoxDecoration(
        color: colors.card.withOpacityExt(0.4),
        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34.0,
            child: Row(
              children: [
                Icon(
                  category.toIcon(),
                  size: 18.0,
                ),
                const SizedBox(
                  width: 8.0,
                ),
                NamidaText(
                  category.toText(),
                  style: const NText(.medium, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ...rows.map(
            (row) {
              final action = row.action;
              final globalShortcut = action == null ? null : userShortcuts[action];
              return _ShortcutRow(
                row: row,
                globalShortcut: globalShortcut?.key == null ? null : globalShortcut,
                hasGlobalSlot: section.hasGlobalSlot,
                isRecording: action != null && action == recordingAction,
                globalActions: globalActions,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final _ShortcutRowData row;
  final ShortcutKeyData? globalShortcut;
  final bool hasGlobalSlot;
  final bool isRecording;
  final _GlobalShortcutActions globalActions;

  const _ShortcutRow({
    required this.row,
    required this.globalShortcut,
    required this.hasGlobalSlot,
    required this.isRecording,
    required this.globalActions,
  });

  @override
  Widget build(BuildContext context) {
    final action = row.action;
    final globalShortcut = this.globalShortcut;
    final globalKeysGroup = globalShortcut == null ? null : _KeysGroup.fromData(globalShortcut);

    final rowWidget = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32.0),
      child: Row(
        children: [
          Expanded(
            child: NamidaText(
              row.title,
              style: const NText(.medium, size: .s13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(
            width: 6.0,
          ),
          _KeysGroupsRow(
            groups: row.keyGroups,
          ),
          if (hasGlobalSlot) ...[
            const SizedBox(
              width: 6.0,
            ),
            action == null
                ? const SizedBox(
                    width: _GlobalButton.size,
                  )
                : _GlobalButton(
                    keysGroup: globalKeysGroup,
                    isRecording: isRecording,
                    onTap: () => globalActions.toggleRecording(action),
                  ),
          ],
        ],
      ),
    );

    if (!isRecording || action == null) return rowWidget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rowWidget,
        Padding(
          padding: const EdgeInsets.only(top: 2.0, bottom: 6.0),
          child: _GlobalShortcutRecorder(
            initial: globalShortcut,
            findConflictTitle: (data) => globalActions.findConflictTitle(action, data),
            onSave: (data) => globalActions.save(action, data),
            onDelete: globalShortcut == null ? null : () => globalActions.delete(action),
            onCancel: globalActions.cancel,
          ),
        ),
      ],
    );
  }
}

class _GlobalShortcutRecorder extends StatefulWidget {
  final ShortcutKeyData? initial;
  final String? Function(ShortcutKeyData data) findConflictTitle;
  final Future<void> Function(ShortcutKeyData data) onSave;
  final Future<void> Function()? onDelete;
  final VoidCallback onCancel;

  const _GlobalShortcutRecorder({
    required this.initial,
    required this.findConflictTitle,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  State<_GlobalShortcutRecorder> createState() => _GlobalShortcutRecorderState();
}

class _GlobalShortcutRecorderState extends State<_GlobalShortcutRecorder> {
  static final _modifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight, //
    LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight, //
    LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight, //
    LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight, //
  };

  final _focusNode = FocusNode();
  late ShortcutKeyData? _data = widget.initial;
  _RecorderError? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) widget.onCancel();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    final logicalKey = event.logicalKey;
    if (logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.numpadEnter) {
      _save();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }

    final keyboard = HardwareKeyboard.instance;
    final isModifier = _modifierKeys.contains(logicalKey);
    final data = ShortcutKeyData(
      key: isModifier ? null : logicalKey,
      ctrl: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      meta: keyboard.isMetaPressed,
    );
    final error = isModifier ? null : _findError(data, event.character);
    setState(() {
      _data = data;
      _error = error;
    });
    return KeyEventResult.handled;
  }

  /// global hotkeys are system-wide, a combo that types text would block typing it in every app.
  _RecorderError? _findError(ShortcutKeyData data, String? typedCharacter) {
    if (typedCharacter != null && data.canTypeText()) return _RecorderError('${lang.alreadyExists} (${lang.text.toLowerCase()}):', keyText: typedCharacter);
    final conflictTitle = widget.findConflictTitle(data);
    if (conflictTitle != null) return _RecorderError('${lang.alreadyExists}: $conflictTitle');
    return null;
  }

  Future<void> _runReportingFailure(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _RecorderError('${lang.failed}: $e'));
    }
  }

  void _save() {
    final data = _data;
    if (data == null || data.key == null) return;
    if (_error != null) return;
    _runReportingFailure(() => widget.onSave(data));
  }

  void _delete() {
    final onDelete = widget.onDelete;
    if (onDelete != null) _runReportingFailure(onDelete);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final error = _error;
    final hasError = error != null;
    final accentRole = hasError ? NColorRole.error : NColorRole.primary;
    final canSave = data?.key != null && !hasError;
    final keysGroup = data == null ? null : _KeysGroup.fromData(data);
    final hasDelete = widget.onDelete != null;

    final errorWidget = error == null
        ? null
        : _RecorderErrorRow(
            error: error,
          );

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      onFocusChange: _onFocusChange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NContainer(
            height: 34.0,
            padding: const EdgeInsets.only(left: 10.0, right: 2.0),
            decoration: (colors) => BoxDecoration(
              color: colors.scaffold.withOpacityExt(0.5),
              borderRadius: BorderRadius.circular(9.0.multipliedRadius),
              border: Border.all(color: colors.get(accentRole)),
            ),
            child: Row(
              children: [
                NContainer(
                  width: 7.0,
                  height: 7.0,
                  decoration: (colors) => BoxDecoration(
                    color: colors.get(accentRole),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(
                  width: 8.0,
                ),
                if (keysGroup != null)
                  _KeysCombo(
                    group: keysGroup,
                    bgColor: NColors(accentRole, opacity: 0.2),
                  ),
                const Spacer(),
                if (hasDelete)
                  NamidaIconButton(
                    icon: Broken.trash,
                    iconSize: 18.0,
                    horizontalPadding: 4.0,
                    tooltip: () => lang.delete,
                    onPressed: _delete,
                  ),
                NBuilder(
                  builder: (context, colors) => NamidaIconButton(
                    icon: Broken.tick_circle,
                    iconSize: 18.0,
                    horizontalPadding: 4.0,
                    iconColor: NColors.fixed(canSave ? null : colors.disabled),
                    tooltip: () => lang.save,
                    onPressed: canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ),
          ?errorWidget,
        ],
      ),
    );
  }
}

class _RecorderErrorRow extends StatelessWidget {
  final _RecorderError error;
  const _RecorderErrorRow({required this.error});

  @override
  Widget build(BuildContext context) {
    final keyText = error.keyText;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 2.0),
      child: Row(
        children: [
          const NIcon(
            Broken.warning_2,
            size: 14.0,
            color: NColors.error,
          ),
          const SizedBox(
            width: 6.0,
          ),
          Flexible(
            child: NamidaText(
              error.message,
              style: NText.small,
              color: NColors.error,
            ),
          ),
          if (keyText != null) ...[
            const SizedBox(
              width: 6.0,
            ),
            _KeyCap(
              text: keyText,
              bgColor: const NColors(.error, opacity: 0.2),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlobalButton extends StatelessWidget {
  static const size = 26.0;

  final _KeysGroup? keysGroup;
  final bool isRecording;
  final VoidCallback onTap;

  const _GlobalButton({
    required this.keysGroup,
    required this.isRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final keysGroup = this.keysGroup;
    final NColors? bgColor;
    final NColors? iconColor;
    if (isRecording) {
      bgColor = NColors.primary;
      iconColor = NColors.onPrimary;
    } else if (keysGroup != null) {
      bgColor = const NColors(.secondaryContainer, opacity: 0.6);
      iconColor = null;
    } else {
      bgColor = null;
      iconColor = const NColors(.icon, opacity: 0.4);
    }
    final iconWidget = NIcon(
      Broken.global,
      size: 15.0,
      color: iconColor,
    );
    final child = keysGroup == null
        ? iconWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(
                width: 5.0,
              ),
              _KeysCombo(
                group: keysGroup,
              ),
            ],
          );
    return NamidaTooltip(
      message: () => lang.global,
      child: NamidaInkWell(
        width: keysGroup == null ? size : null,
        height: size,
        padding: keysGroup == null ? EdgeInsets.zero : const EdgeInsets.only(left: 6.0, right: 2.0),
        borderRadius: 7.0,
        bgColor: bgColor,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _KeysGroupsRow extends StatelessWidget {
  final List<_KeysGroup> groups;
  const _KeysGroupsRow({required this.groups});

  @override
  Widget build(BuildContext context) {
    final separatorStyle = NText.small.of(context).copyWith(fontSize: 12.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5.0,
      children: groups
          .map(
            (e) => _KeysCombo(
              group: e,
            ),
          )
          .addSeparators(
            separator: Text(
              '·',
              style: separatorStyle,
            ),
          )
          .toFixedList(),
    );
  }
}

class _KeysCombo extends StatelessWidget {
  final _KeysGroup group;
  final NColors? bgColor;
  const _KeysCombo({required this.group, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final separatorStyle = NText.small.of(context).copyWith(fontSize: 12.0);
    final keysCaps = group.keys
        .map(
          (e) => _KeyCap(
            text: e,
            bgColor: bgColor,
          ),
        )
        .addSeparators(
          separator: Text(
            '/',
            style: separatorStyle,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3.0,
      children: [
        ...group.modifiers.map(
          (e) => _KeyCap(
            text: e,
            bgColor: bgColor,
          ),
        ),
        ...keysCaps,
      ],
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String text;
  final NColors? bgColor;
  const _KeyCap({required this.text, this.bgColor});

  @override
  Widget build(BuildContext context) {
    return NContainer(
      constraints: const BoxConstraints(minWidth: 22.0),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: (colors) => BoxDecoration(
        color: bgColor?.resolve(colors) ?? colors.card,
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
      ),
      child: NamidaText(
        text,
        textAlign: TextAlign.center,
        style: const NText(.small, size: .s12, weight: FontWeight.w600),
      ),
    );
  }
}

class _NonShrinkingHeight extends SingleChildRenderObjectWidget {
  const _NonShrinkingHeight({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNonShrinkingHeight();
}

class _RenderNonShrinkingHeight extends RenderProxyBox {
  double _tallestHeight = 0.0;

  @override
  void performLayout() {
    final child = this.child!;
    final minHeight = _tallestHeight.withMaximum(constraints.maxHeight);
    final childConstraints = constraints.copyWith(minHeight: minHeight);
    child.layout(childConstraints, parentUsesSize: true);
    size = child.size;
    if (size.height > _tallestHeight) _tallestHeight = size.height;
  }
}

class _ShortcutsSection {
  final ShortcutCategory category;
  final List<_ShortcutRowData> rows;
  final bool hasGlobalSlot;

  _ShortcutsSection({
    required this.category,
    required this.rows,
  }) : hasGlobalSlot = rows.any((e) => e.action != null);

  List<_ShortcutRowData> filterRows(String query) {
    if (query.isEmpty) return rows;
    return rows.where((e) => e.searchText.contains(query)).toFixedList();
  }
}

class _ShortcutRowData {
  final String title;
  final HotkeyAction? action;
  final List<_KeysGroup> keyGroups;
  final String searchText;

  const _ShortcutRowData({
    required this.title,
    required this.action,
    required this.keyGroups,
    required this.searchText,
  });

  factory _ShortcutRowData.fromActivators(String title, List<ShortcutKeyActivator> activators) {
    final datasByModifiers = <String, List<ShortcutKeyData>>{};
    for (final activator in activators) {
      final data = ShortcutKeyData.fromShortcutKeyActivator(activator);
      final modifiersId = data.buildModifierLabels().join('+');
      datasByModifiers.addForce(modifiersId, data);
    }
    final keyGroups = datasByModifiers.values.map(_KeysGroup.fromSameModifiers).toFixedList();
    final keysText = keyGroups.map((e) => e.toText()).join(' ');
    final searchText = '$title $keysText'.toLowerCase();
    return _ShortcutRowData(
      title: title,
      action: activators.first.action,
      keyGroups: keyGroups,
      searchText: searchText,
    );
  }
}

class _KeysGroup {
  final List<String> modifiers;
  final List<String> keys;

  const _KeysGroup({
    required this.modifiers,
    required this.keys,
  });

  factory _KeysGroup.fromData(ShortcutKeyData data) {
    final keyText = data.buildKeyText();
    return _KeysGroup(
      modifiers: data.buildModifierLabels(),
      keys: [?keyText],
    );
  }

  factory _KeysGroup.fromSameModifiers(List<ShortcutKeyData> datas) {
    final modifiers = datas.first.buildModifierLabels();
    final isDigitsRange = datas.length > 2 && datas.every(_isDigitKey);
    if (isDigitsRange) {
      final firstText = datas.first.buildKeyText();
      final lastText = datas.last.buildKeyText();
      return _KeysGroup(
        modifiers: modifiers,
        keys: ['$firstText–$lastText'],
      );
    }
    final keys = datas.map((e) => e.buildKeyText()).nonNulls.toSet().toFixedList();
    return _KeysGroup(
      modifiers: modifiers,
      keys: keys,
    );
  }

  static bool _isDigitKey(ShortcutKeyData data) {
    final keyId = data.key?.keyId;
    if (keyId == null) return false;
    return keyId >= LogicalKeyboardKey.digit0.keyId && keyId <= LogicalKeyboardKey.digit9.keyId;
  }

  String toText() {
    final keysText = keys.join('/');
    return [...modifiers, keysText].join(' ');
  }
}

class _RecorderError {
  final String message;
  final String? keyText;

  const _RecorderError(this.message, {this.keyText});
}

class _GlobalShortcutActions {
  final void Function(HotkeyAction action) toggleRecording;
  final String? Function(HotkeyAction action, ShortcutKeyData data) findConflictTitle;
  final Future<void> Function(HotkeyAction action, ShortcutKeyData data) save;
  final Future<void> Function(HotkeyAction action) delete;
  final VoidCallback cancel;

  const _GlobalShortcutActions({
    required this.toggleRecording,
    required this.findConflictTitle,
    required this.save,
    required this.delete,
    required this.cancel,
  });
}

extension _ShortcutCategoryUtils on ShortcutCategory {
  String toText() => switch (this) {
    ShortcutCategory.playback => lang.playbackSetting,
    ShortcutCategory.track => lang.track,
    ShortcutCategory.others => lang.others,
    ShortcutCategory.lyrics => lang.lyrics,
  };

  IconData toIcon() => switch (this) {
    ShortcutCategory.playback => Broken.play_cricle,
    ShortcutCategory.track => Broken.heart,
    ShortcutCategory.others => Broken.element_3,
    ShortcutCategory.lyrics => Broken.document,
  };
}

typedef _VisibleSection = ({_ShortcutsSection section, List<_ShortcutRowData> rows});
