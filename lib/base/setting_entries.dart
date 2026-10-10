// by claude
part of 'setting_subpage_provider.dart';

/// declared once as a `static final`, search jumps to that instance.
abstract class SettingEntry {
  final String Function() title;
  final List<String> Function()? aliases;
  final NamidaFeaturesAvailablityBase? availability;
  final bool Function()? visibleWhen;

  const SettingEntry({required this.title, this.aliases, this.availability, this.visibleWhen});

  /// title first, then anything else that should find it.
  List<String> getSearchTitles() => [title(), ...?aliases?.call()];

  /// shown inline, never in a dialog, since search jumps into them.
  List<SettingEntry> get children => const [];

  /// what it saves, for the modified filter and its reset.
  List<SettingsKey<Object?>> get keys => const [];

  Widget toTile(SettingTileArgs args);

  bool isModified() {
    for (final key in keys) {
      if (key.userValue != null) return true;
    }
    return false;
  }

  void resetToDefault() {
    for (final key in keys) {
      key.reset();
    }
  }

  bool containsDeep(SettingEntry key) {
    for (final child in children) {
      if (child == key || child.containsDeep(key)) return true;
    }
    return false;
  }
}

class SettingEntryTile extends StatelessWidget {
  final SettingEntry entry;
  final SettingSubpageProvider? page;

  const SettingEntryTile({super.key, required this.entry, this.page});

  @override
  Widget build(BuildContext context) {
    final isAvailable = entry.availability?.resolve();
    if (isAvailable == false) return const SizedBox();

    final page = this.page;
    final bgColor = page?.getBgColor(entry);
    final args = (entry: entry, page: page, bgColor: bgColor);
    final tile = entry.toTile(args);
    final shownTile = page == null || entry != page.initialItem
        ? tile
        : _SettingTargetHighlight(
            key: SettingsSearchController.inst.getTargetKey(entry),
            child: tile,
          );
    final visibleWhen = entry.visibleWhen;
    if (visibleWhen == null) return shownTile;
    return Obx(
      (context) => visibleWhen() ? shownTile : const SizedBox(),
    );
  }
}

class SettingSectionsColumn extends StatelessWidget {
  final SettingSubpageProvider page;

  const SettingSectionsColumn({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final children = page.sections
        .map(
          (section) => Column(
            mainAxisSize: MainAxisSize.min,
            children: section
                .map(
                  (e) => SettingEntryTile(
                    entry: e,
                    page: page,
                  ),
                )
                .toFixedList(),
          ),
        )
        .addSeparators(
          separator: const NamidaContainerDivider(
            height: 1.0,
            margin: EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
          ),
        )
        .toFixedList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class SettingToggle extends SettingEntry {
  final SettingsKey<bool> setting;
  final String Function()? subtitle;
  final IconData? icon;
  final Widget? leading;
  final bool Function()? enabledWhen;

  /// called after the new value is saved.
  final void Function(bool isEnabled)? onChanged;

  SettingToggle(
    this.setting, {
    required super.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.enabledWhen,
    this.onChanged,
    super.aliases,
    super.availability,
    super.visibleWhen,
  });

  @override
  late final List<SettingsKey<Object?>> keys = [setting];

  @override
  List<String> getSearchTitles() => [title(), ?subtitle?.call(), ...?aliases?.call()];

  @override
  Widget toTile(SettingTileArgs args) => _SettingToggleTile(
    entry: this,
    bgColor: args.bgColor,
  );

  void toggle() {
    final isEnabled = !setting.value;
    setting.save(isEnabled);
    onChanged?.call(isEnabled);
  }

  @override
  void resetToDefault() {
    setting.reset();
    onChanged?.call(setting.value);
  }
}

/// a switch header, its children show while it's on.
class SettingToggleGroup extends SettingToggle {
  @override
  final List<SettingEntry> children;

  SettingToggleGroup(
    super.setting, {
    required super.title,
    super.subtitle,
    super.icon,
    super.leading,
    super.enabledWhen,
    super.onChanged,
    required this.children,
    super.aliases,
    super.availability,
    super.visibleWhen,
  });

  @override
  Widget toTile(SettingTileArgs args) => _SettingToggleGroupTile(
    entry: this,
    args: args,
  );
}

class SettingChoice<E extends Enum> extends SettingEntry {
  final SettingsKey<E> setting;
  final List<E> values;
  final String Function(E value) valueToText;

  /// lists the values in a dialog with these subtitles instead of a popup menu.
  final String Function(E value)? valueToSubtitle;
  final IconData Function(E value)? valueToIcon;
  final IconData icon;
  final bool isValueInSubtitle;
  final bool Function()? enabledWhen;

  /// called after the new value is saved.
  final void Function(E value)? onChanged;

  SettingChoice(
    this.setting, {
    required this.values,
    required this.valueToText,
    this.valueToSubtitle,
    this.valueToIcon,
    required super.title,
    required this.icon,
    this.isValueInSubtitle = false,
    this.enabledWhen,
    this.onChanged,
    super.aliases,
    super.availability,
    super.visibleWhen,
  });

  @override
  late final List<SettingsKey<Object?>> keys = [setting];

  @override
  Widget toTile(SettingTileArgs args) => _SettingChoiceTile<E>(
    entry: this,
    bgColor: args.bgColor,
  );

  @override
  void resetToDefault() {
    setting.reset();
    onChanged?.call(setting.value);
  }
}

class SettingWheel extends SettingEntry {
  final SettingsKey<int> setting;
  final IconData icon;
  final int min;
  final int max;
  final int stepper;

  /// adds a value after [max] that saves -1.
  final bool extraValue;
  final String Function(int value) valueToText;
  final bool Function()? enabledWhen;

  SettingWheel(
    this.setting, {
    required super.title,
    required this.icon,
    this.min = 0,
    required this.max,
    this.stepper = 1,
    this.extraValue = false,
    required this.valueToText,
    this.enabledWhen,
    super.aliases,
    super.availability,
    super.visibleWhen,
  });

  @override
  late final List<SettingsKey<Object?>> keys = [setting];

  @override
  Widget toTile(SettingTileArgs args) => _SettingWheelTile(
    entry: this,
    bgColor: args.bgColor,
  );
}

class SettingExpansion extends SettingEntry {
  final String Function()? subtitle;
  final IconData? icon;
  final Widget? leading;
  final bool Function()? initiallyExpandedWhen;

  @override
  final List<SettingEntry> children;

  SettingExpansion({
    required super.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.initiallyExpandedWhen,
    required this.children,
    super.aliases,
    super.availability,
    super.visibleWhen,
  });

  @override
  List<String> getSearchTitles() => [title(), ?subtitle?.call(), ...?aliases?.call()];

  @override
  Widget toTile(SettingTileArgs args) => _SettingExpansionTile(
    entry: this,
    args: args,
  );
}

/// an option with its own tile widget, [tile] only instantiates it.
class SettingCustom extends SettingEntry {
  final Widget Function(SettingTileArgs args) tile;

  @override
  final List<SettingEntry> children;

  @override
  final List<SettingsKey<Object?>> keys;

  /// applies what the tile applies after a save, once [keys] are reset.
  final VoidCallback? onReset;

  SettingCustom({
    required super.title,
    required this.tile,
    this.children = const [],
    this.keys = const [],
    this.onReset,
    super.aliases,
    super.availability,
    super.visibleWhen,
  });

  @override
  Widget toTile(SettingTileArgs args) => tile(args);

  @override
  void resetToDefault() {
    super.resetToDefault();
    onReset?.call();
  }
}

class _SettingToggleTile extends StatelessWidget {
  final SettingToggle entry;
  final Color? bgColor;

  const _SettingToggleTile({required this.entry, required this.bgColor});

  void _onChanged(bool _) => entry.toggle();

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final isEnabled = entry.enabledWhen?.call() ?? true;
        final subtitle = entry.subtitle?.call();
        return CustomSwitchListTile(
          bgColor: bgColor,
          enabled: isEnabled,
          icon: entry.icon,
          leading: entry.leading,
          title: entry.title(),
          subtitle: subtitle,
          value: entry.setting.valueR,
          onChanged: _onChanged,
        );
      },
    );
  }
}

class _SettingChoiceTile<E extends Enum> extends StatelessWidget {
  final SettingChoice<E> entry;
  final Color? bgColor;

  const _SettingChoiceTile({required this.entry, required this.bgColor});

  void _choose(E value) {
    entry.setting.save(value);
    entry.onChanged?.call(value);
  }

  void _onTap(BuildContext context) {
    final valueToSubtitle = entry.valueToSubtitle;
    if (valueToSubtitle == null) {
      _showMenu(context);
    } else {
      _showDialog(valueToSubtitle);
    }
  }

  Iterable<NamidaPopupItem> _getMenuItems() => entry.values.map(
    (e) => NamidaPopupItem(
      icon: entry.valueToIcon?.call(e) ?? entry.icon,
      title: entry.valueToText(e),
      selected: e == entry.setting.value,
      onTap: () {
        _choose(e);
        NamidaNavigator.inst.popMenu();
      },
    ),
  );

  void _showMenu(BuildContext context) {
    final menu = NamidaPopupWrapper(
      childrenDefault: _getMenuItems,
    );
    menu.showPopupMenu(context);
  }

  void _showDialog(String Function(E value) valueToSubtitle) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: entry.title(),
        actions: [
          IconButton(
            onPressed: () => _choose(entry.setting.fallback),
            icon: const Icon(Broken.refresh),
          ),
          const DoneButton(),
        ],
        child: ObxO(
          rx: entry.setting,
          builder: (context, selected) => SuperSmoothListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              ...entry.values.map(
                (e) => Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: ListTileWithCheckMark(
                    active: selected == e,
                    icon: entry.valueToIcon?.call(e),
                    title: entry.valueToText(e),
                    subtitle: valueToSubtitle(e),
                    onTap: () => _choose(e),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final value = entry.setting.valueR;
        final valueText = entry.valueToText(value);
        final isEnabled = entry.enabledWhen?.call() ?? true;
        final isValueInSubtitle = entry.isValueInSubtitle;
        final title = entry.title();
        final hasMenu = entry.valueToSubtitle == null;
        final valueMenu = hasMenu && !isValueInSubtitle
            ? NamidaPopupWrapper(
                childrenDefault: _getMenuItems,
                child: Text(
                  valueText,
                  style: CustomListTile.getTrailingTextStyle(context.theme),
                  maxLines: 1,
                ),
              )
            : null;
        final trailingText = isValueInSubtitle || hasMenu ? null : valueText;
        return CustomListTile(
          bgColor: bgColor,
          enabled: isEnabled,
          icon: entry.icon,
          title: isValueInSubtitle ? '$title:' : title,
          subtitle: isValueInSubtitle ? valueText : null,
          trailing: valueMenu,
          trailingText: trailingText,
          onTap: () => _onTap(context),
        );
      },
    );
  }
}

class _SettingWheelTile extends StatelessWidget {
  final SettingWheel entry;
  final Color? bgColor;

  const _SettingWheelTile({required this.entry, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final value = entry.setting.valueR;
        final isEnabled = entry.enabledWhen?.call() ?? true;
        return CustomListTile(
          bgColor: bgColor,
          enabled: isEnabled,
          icon: entry.icon,
          title: entry.title(),
          trailing: NamidaWheelSlider(
            min: entry.min,
            max: entry.max,
            stepper: entry.stepper,
            extraValue: entry.extraValue,
            initValue: value,
            onValueChanged: entry.setting.save,
            text: entry.valueToText(value),
          ),
        );
      },
    );
  }
}

class _SettingExpansionTile extends StatelessWidget {
  final SettingExpansion entry;
  final SettingTileArgs args;

  const _SettingExpansionTile({required this.entry, required this.args});

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final isTargetWithin = page?.isTargetWithin(entry) == true;
    final children = entry.children
        .map(
          (e) => SettingEntryTile(
            entry: e,
            page: page,
          ),
        )
        .toFixedList();
    final isInitiallyExpanded = entry.initiallyExpandedWhen?.call() == true;
    final subtitle = entry.subtitle?.call();
    return NamidaExpansionTile(
      bgColor: args.bgColor,
      icon: entry.icon,
      leading: entry.leading,
      titleText: entry.title(),
      subtitleText: subtitle,
      initiallyExpanded: isInitiallyExpanded || isTargetWithin,
      children: children,
    );
  }
}

class _SettingToggleGroupTile extends StatelessWidget {
  final SettingToggleGroup entry;
  final SettingTileArgs args;

  const _SettingToggleGroupTile({required this.entry, required this.args});

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final setting = entry.setting;
    final isTargetWithin = page?.isTargetWithin(entry) == true;
    final initiallyExpanded = setting.value || isTargetWithin;
    final children = entry.children
        .map(
          (e) => SettingEntryTile(
            entry: e,
            page: page,
          ),
        )
        .toFixedList();
    return Obx(
      (context) {
        final isEnabled = entry.enabledWhen?.call() ?? true;
        final isOn = setting.valueR;
        final subtitle = entry.subtitle?.call();
        return AnimatedEnabled(
          enabled: isEnabled,
          child: NamidaExpansionTile(
            bgColor: args.bgColor,
            icon: entry.icon,
            leading: entry.leading,
            titleText: entry.title(),
            subtitleText: subtitle,
            initiallyExpanded: initiallyExpanded,
            expandedRx: setting,
            onTap: entry.toggle,
            trailingBuilder: (_) => CustomSwitch(
              active: isOn,
            ),
            children: children,
          ),
        );
      },
    );
  }
}
