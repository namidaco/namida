import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/controller/text_suggestions_provider.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/text_suggestions.dart';

class CreateSmartPlaylistDialog extends StatefulWidget {
  final SmartPlaylistWrapper? initialSmartPlaylistWrapper;
  final Completer<SmartPlaylistWrapper?>? _onSearchCompleter;

  const CreateSmartPlaylistDialog({super.key, this.initialSmartPlaylistWrapper}) : _onSearchCompleter = null;

  const CreateSmartPlaylistDialog.forTempSmartSearch({
    super.key,
    this.initialSmartPlaylistWrapper,
    required Completer<SmartPlaylistWrapper?> completer,
  }) : _onSearchCompleter = completer;

  @override
  State<CreateSmartPlaylistDialog> createState() => _CreateSmartPlaylistDialogState();

  static Future<SmartPlaylistWrapper?> getTempPlaylist({SmartPlaylistWrapper? initialSmartPlaylistWrapper}) async {
    final smartSearchCompleter = Completer<SmartPlaylistWrapper?>();
    NamidaNavigator.inst.navigateDialog(
      dialog: CreateSmartPlaylistDialog.forTempSmartSearch(
        initialSmartPlaylistWrapper: initialSmartPlaylistWrapper,
        completer: smartSearchCompleter,
      ),
    );
    return await smartSearchCompleter.future;
  }

  static void promptDeletePlaylist(SmartPlaylist pl) {
    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) => CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.delete.toUpperCase(),
            colorScheme: Colors.red,
            onTap: () async {
              SmartPlaylistsController.inst.delete(pl.key);
              NamidaNavigator.inst.closeAllDialogs();
            },
          ),
        ],
        bodyText: '${lang.deletePlaylist}: "${pl.name}"?',
      ),
    );
  }
}

class _CreateSmartPlaylistDialogState extends State<CreateSmartPlaylistDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _resolvedTracksCountForCurrentSmartPlaylist;

  final _nameController = TextEditingController();
  SmartJoiner _joiner = SmartJoiner.defaultForGroups;
  List<SortType> _sorts = const [];
  bool _sortReverse = false;
  final _moods = <String>[];
  final _ruleGroups = <SmartPlaylistRuleGroup>[];
  SmartPlaylistLimit? _limit;

  @override
  void initState() {
    final sp = widget.initialSmartPlaylistWrapper?.value;
    if (sp != null) {
      _nameController.text = sp.name;
      _joiner = sp.joiner;
      _sorts = sp.sorts;
      _sortReverse = sp.sortReverse;
      _moods.addAll(sp.moods);
      _ruleGroups.addAll(sp.ruleGroups.map((e) => e.copy()));
      _limit = sp.limit;
    }
    if (_ruleGroups.isEmpty) {
      _ruleGroups.add(
        SmartPlaylistRuleGroup.create(),
      );
    }

    _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    widget._onSearchCompleter?.completeIfWasnt(null);
    super.dispose();
  }

  void _resetEverything() {
    _nameController.text = '';
    _joiner = SmartJoiner.defaultForGroups;
    _sorts = const [];
    _sortReverse = false;
    _moods.clear();
    _ruleGroups.clear();
    _limit = null;

    _ruleGroups.add(SmartPlaylistRuleGroup.create());

    _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();

    setState(() {});
  }

  SmartPlaylist _buildSmartPlaylistFromCurrentParams() {
    return SmartPlaylist(
      name: _nameController.text,
      creationDate: DateTime.now(),
      joiner: _joiner,
      sorts: _sorts,
      sortReverse: _sortReverse,
      moods: _moods,
      ruleGroups: _ruleGroups,
      limit: _limit,
    );
  }

  int? _buildResolvedTracksCount() {
    final pl = _buildSmartPlaylistFromCurrentParams();
    if (pl.ruleGroups.isEmpty) return null;
    if (pl.ruleGroups.every((g) => g.rules.isEmpty)) return null;
    return pl.resolveCount();
  }

  void _createOrEdit() async {
    if (_formKey.currentState?.validate() == true) {
      NamidaNavigator.inst.closeDialog();

      _ruleGroups.removeWhere((g) => g.rules.isEmpty);
      final smartPlaylist = _buildSmartPlaylistFromCurrentParams();
      if (widget._onSearchCompleter != null) {
        widget._onSearchCompleter!.complete(SmartPlaylistWrapper(smartPlaylist));
      } else if (widget.initialSmartPlaylistWrapper != null) {
        await SmartPlaylistsController.inst.edit(widget.initialSmartPlaylistWrapper!.value, smartPlaylist);
      } else {
        await SmartPlaylistsController.inst.create(smartPlaylist);
      }
    }
  }

  void _setJoiner(SmartJoiner joiner) {
    if (_joiner == joiner) return;
    setState(() {
      _joiner = joiner;
      _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    });
  }

  void _setSorts(List<SortType> sorts, bool sortReverse) {
    setState(() {
      _sorts = sorts;
      _sortReverse = sortReverse;
    });
  }

  void _setSortReverse(bool sortReverse) {
    if (_sortReverse == sortReverse) return;
    setState(() => _sortReverse = sortReverse);
  }

  void _setLimit(SmartPlaylistLimit? limit) {
    setState(() {
      _limit = limit;
      _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    });
  }

  void _addGroup() {
    setState(() => _ruleGroups.add(SmartPlaylistRuleGroup.create()));
  }

  void _modifyGroup(int groupIndex, SmartPlaylistRuleGroup newGroup) {
    if (_ruleGroups[groupIndex] == newGroup) return;
    setState(() {
      _ruleGroups[groupIndex] = newGroup;
      _ensureGroupHasCustomAutoSource(newGroup);
      _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    });
  }

  void _deleteGroup(int groupIndex) {
    setState(() {
      _ruleGroups.removeAt(groupIndex);
      _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    });

    if (_ruleGroups.isEmpty) {
      _addGroup();
    }
  }

  void _ensureGroupHasCustomAutoSource(SmartPlaylistRuleGroup group) {
    final requiredAutoSourcesInsertIndexReversedMap = <SmartPlaylistRuleFilterSource, int>{};
    final int length = group.rules.length;
    for (int i = length - 1; i >= 0; i--) {
      final r = group.rules[i];
      final cs = r.source.customAutoSource;
      if (cs != null) {
        requiredAutoSourcesInsertIndexReversedMap[cs] = i + 1;
      }
    }

    group.rules.removeWhere((r) => r.source.isAutoSource && !requiredAutoSourcesInsertIndexReversedMap.containsKey(r.source));

    for (final s in requiredAutoSourcesInsertIndexReversedMap.keys) {
      final alreadyExists = group.rules.any((r) => r.source == s);
      if (!alreadyExists) {
        final newRule = SmartPlaylistRuleBase.buildFrom(
          type: s.type,
          filter: s.recommendedFilter,
          source: s,
          enableCleanup: s.supportsCleanup,
          clockOnly: false,
          relativeDuration: null,
        );

        final insertionIndex = requiredAutoSourcesInsertIndexReversedMap[s] ?? group.rules.length - 1;
        group.rules.insert(insertionIndex, newRule);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _addEditRule(
            group,
            (insertionIndex, newRule),
          );
        });
      }
    }
  }

  void _addEditRule(SmartPlaylistRuleGroup group, (int i, SmartPlaylistRuleBase)? initialRule) {
    NamidaNavigator.inst.navigateDialog(
      dialog: _AddEditRuleDialog(
        group: group,
        initialRule: initialRule?.$2.copyWith(), // copy so that modifications only apply after confirming
        onAdd: (rule) {
          if (initialRule == null) {
            if (group.rules.contains(rule)) {
              snackyy(
                title: lang.note,
                isError: true,
                message: lang.ruleAlreadyExists,
              );
            } else {
              group.rules.add(rule);
            }
          } else {
            final indexOfAlreadyExistingSimilar = group.rules.indexOf(rule);
            if (indexOfAlreadyExistingSimilar < 0) {
              group.rules[initialRule.$1] = rule;
            } else {
              group.rules[initialRule.$1] = rule;
              if (indexOfAlreadyExistingSimilar != initialRule.$1) group.rules.removeAt(indexOfAlreadyExistingSimilar); // also remove old one
              snackyy(
                title: lang.note,
                isError: true,
                message: lang.ruleAlreadyExists,
              );
            }
          }
          _ensureGroupHasCustomAutoSource(group);
          _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
          setState(() {});
        },
      ),
    );
  }

  void _removeRule(SmartPlaylistRuleGroup group, int ruleIndex) {
    setState(() {
      group.rules.removeAt(ruleIndex);
      _ensureGroupHasCustomAutoSource(group);
      _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    const ruleLeftSpaceForJoiner = 28.0;
    final textStyleMedium = context.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w500);
    final textStyleSmall = context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500);
    final isForTempSearch = widget._onSearchCompleter != null;
    final dialogTitle = isForTempSearch ? lang.search : lang.smartPlaylist;
    final ruleGroupsAreValid = _ruleGroups.isValid();
    return Form(
      key: _formKey,
      child: SizedBox(
        // height: context.height * 0.7,
        child: CustomBlurryDialog(
          normalTitleStyle: true,
          icon: Broken.magicpen,
          horizontalInset: 38.0,
          title: dialogTitle,
          titleWidgetInPadding: Row(
            children: [
              const Icon(
                Broken.magicpen,
                size: 18.0,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogTitle,
                      style: context.theme.textTheme.displayLarge,
                    ),
                    if (_resolvedTracksCountForCurrentSmartPlaylist != null)
                      Text(
                        _resolvedTracksCountForCurrentSmartPlaylist!.displayTrackKeyword,
                        style: context.theme.textTheme.displaySmall,
                      ),
                  ],
                ),
              ),
              if (!isForTempSearch)
                Row(
                  children: [
                    const SizedBox(width: 8.0),
                    NamidaButton(
                      dense: true,
                      minHeight: NamidaTextButton.kDefaultMinHeight * 0.5,
                      colors: NamidaButtonColors.dimmed,
                      icon: Broken.sort,
                      text: _sorts.firstOrNull?.toText() ?? lang.auto,
                      fontSizeMultiplier: 0.95,
                      onTap: () => NamidaOnTaps.inst.onTracksSortIconTap(
                        currentSorts: _sorts,
                        currentReverse: _sortReverse,
                        onChanged: _setSorts,
                      ),
                    ),
                    NamidaIconButton(
                      horizontalPadding: 8.0,
                      icon: _sortReverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                      iconSize: 20.0,
                      onPressed: () => _setSortReverse(!_sortReverse),
                    ),
                  ],
                ),

              if (isForTempSearch && ruleGroupsAreValid)
                NamidaIconButton(
                  horizontalPadding: 8.0,
                  icon: Broken.refresh,
                  iconSize: 20.0,
                  onPressed: _resetEverything,
                ),
            ],
          ),
          actions: [
            const CancelButton(),
            NamidaButton(
              enabled: isForTempSearch || ruleGroupsAreValid,
              onTap: _createOrEdit,
              text: isForTempSearch
                  ? lang.search
                  : widget.initialSmartPlaylistWrapper != null
                  ? lang.edit
                  : lang.create,
            ),
          ],
          child: Column(
            children: [
              SizedBox(
                height: context.height * 0.5,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  children: [
                    AnimatedShow(
                      show: _ruleGroups.length > 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _JoinerRow(
                          activeJoiner: _joiner,
                          onTap: _setJoiner,
                        ),
                      ),
                    ),

                    ..._ruleGroups
                        .mapIndexed(
                          (group, groupIndex) {
                            final groupIndexWidget = DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.theme.colorScheme.secondary.withOpacityExt(0.25),
                                borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                              ),
                              child: SizedBox(
                                width: ruleLeftSpaceForJoiner,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      "${groupIndex + 1}",
                                      style: textStyleMedium,
                                    ),
                                  ),
                                ),
                              ),
                            );
                            return SizedBox(
                              width: context.width,
                              child: NamidaCoolBox(
                                extraVPadding: true,
                                hPadding: 6.0,
                                colorScheme: context.theme.colorScheme.secondary,
                                builder: (context) => Column(
                                  crossAxisAlignment: .start,
                                  mainAxisSize: .min,
                                  children: [
                                    AnimatedShow(
                                      show: group.rules.length > 1,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: _JoinerRow(
                                          activeJoiner: group.joiner,
                                          onTap: (joiner) => _modifyGroup(groupIndex, group.copyWith(joiner: joiner)),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: .start,
                                            mainAxisSize: .min,
                                            children: [
                                              ...group.rules
                                                  .mapIndexed(
                                                    (rule, ruleIndex) {
                                                      final ruleText = rule.datasDisplayText();
                                                      return Row(
                                                        mainAxisAlignment: .start,
                                                        children: [
                                                          ruleIndex == 0
                                                              ? groupIndexWidget
                                                              : SizedBox(
                                                                  width: ruleLeftSpaceForJoiner,
                                                                  child: FittedBox(
                                                                    fit: BoxFit.scaleDown,
                                                                    child: DecoratedBox(
                                                                      decoration: BoxDecoration(
                                                                        color: context.theme.cardColor,
                                                                        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                                                      ),
                                                                      child: Padding(
                                                                        padding: const EdgeInsets.all(4.0),
                                                                        child: Text(
                                                                          group.joiner.toText(),
                                                                          textHeightBehavior: const TextHeightBehavior(
                                                                            applyHeightToFirstAscent: false,
                                                                            applyHeightToLastDescent: false,
                                                                          ),
                                                                          style: textStyleSmall,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                          const SizedBox(width: 4.0),
                                                          Expanded(
                                                            child: NamidaInkWell(
                                                              borderRadius: 6.0,
                                                              bgColor: context.theme.cardColor,
                                                              padding: const EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 6.0),
                                                              onTap: () => _addEditRule(group, (ruleIndex, rule)),
                                                              child: Row(
                                                                mainAxisSize: .min,
                                                                children: [
                                                                  Icon(
                                                                    rule.type.toIcon(),
                                                                    size: 16.0,
                                                                  ),
                                                                  const SizedBox(width: 4.0),
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: .start,
                                                                      mainAxisSize: .min,
                                                                      children: [
                                                                        Text(
                                                                          rule.sourceDisplayText(),
                                                                          style: textStyleSmall,
                                                                        ),
                                                                        Text(
                                                                          [
                                                                            rule.filter.toText(),
                                                                            if (ruleText.isNotEmpty) ruleText,
                                                                          ].join(': '),
                                                                          style: textStyleSmall,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 2.0),
                                                                  if (!rule.source.isAutoSource)
                                                                    NamidaIconButton(
                                                                      horizontalPadding: 4.0,
                                                                      icon: Broken.minus_cirlce,
                                                                      iconSize: 16.0,
                                                                      onPressed: () => _removeRule(group, ruleIndex),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  )
                                                  .addSeparators(
                                                    separator: const SizedBox(height: 3.0),
                                                  ),

                                              if (group.rules.isNotEmpty) const SizedBox(height: 3.0),
                                              SizedBox(
                                                width: context.width,
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: ruleLeftSpaceForJoiner,
                                                      child: group.rules.isEmpty ? groupIndexWidget : null,
                                                    ),
                                                    const SizedBox(width: 4.0),
                                                    Expanded(
                                                      child: NamidaInkWell(
                                                        borderRadius: 6.0,
                                                        bgColor: context.theme.colorScheme.secondary.withOpacityExt(0.1),
                                                        padding: const EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 8.0),
                                                        onTap: () => _addEditRule(group, null),
                                                        child: Row(
                                                          mainAxisSize: .min,
                                                          children: [
                                                            const StackedIcon(
                                                              baseIcon: Broken.magicpen,
                                                              secondaryIcon: Broken.add_circle,
                                                              iconSize: 16.0,
                                                              secondaryIconSize: 10.0,
                                                              disableColor: true,
                                                            ),
                                                            const SizedBox(width: 8.0),
                                                            Flexible(
                                                              child: Text(
                                                                lang.addRule,
                                                                style: textStyleMedium,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 2.0),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          onPressed: () => _deleteGroup(groupIndex),
                                          icon: const Icon(
                                            Broken.trash,
                                            size: 18.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                        .addSeparators(
                          separator: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              _joiner.toText(),
                              style: textStyleSmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                    const SizedBox(height: 12.0),

                    NamidaInkWell(
                      onTap: _addGroup,
                      borderRadius: 8.0,
                      child: NamidaCoolBox(
                        colorScheme: context.theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        extraVPadding: true,
                        builder: (context) => Row(
                          mainAxisAlignment: .center,
                          mainAxisSize: .min,
                          children: [
                            const StackedIcon(
                              baseIcon: Broken.cards,
                              secondaryIcon: Broken.add_circle,
                              iconSize: 16.0,
                              secondaryIconSize: 10.0,
                              disableColor: true,
                            ),
                            const SizedBox(width: 8.0),
                            Flexible(
                              child: Text(
                                lang.addGroup,
                                style: textStyleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12.0),

                    _LimitTile(
                      limit: _limit,
                      onChanged: _setLimit,
                    ),
                  ],
                ),
              ),

              if (!isForTempSearch) ...[
                const SizedBox(height: 12.0),
                CustomTagTextField(
                  controller: _nameController,
                  hintText: lang.name,
                  labelText: lang.name,
                  validator: (value) => SmartPlaylistsController.inst.validatePlaylistName(value, oldKey: widget.initialSmartPlaylistWrapper?.value.key),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinerRow extends StatelessWidget {
  final SmartJoiner activeJoiner;
  final void Function(SmartJoiner joiner) onTap;

  const _JoinerRow({
    required this.activeJoiner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: SmartJoiner.values
          .map(
            (joiner) {
              final isSelected = joiner == activeJoiner;
              return Expanded(
                child: NamidaInkWell(
                  bgColor: isSelected ? context.theme.colorScheme.secondary.withOpacityExt(0.5) : context.theme.cardColor,
                  borderRadius: 4.0,
                  padding: const EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 6.0),
                  onTap: () => onTap(joiner),
                  child: Text(
                    joiner.toTitle(),
                    style: context.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          )
          .addSeparators(
            separator: const SizedBox(width: 8.0),
          )
          .toFixedList(),
    );
  }
}

class _AddEditRuleDialog extends StatefulWidget {
  final SmartPlaylistRuleGroup group;
  final SmartPlaylistRuleBase? initialRule;
  final void Function(SmartPlaylistRuleBase rule) onAdd;

  const _AddEditRuleDialog({
    required this.group,
    required this.initialRule,
    required this.onAdd,
  });

  @override
  State<_AddEditRuleDialog> createState() => _AddEditRuleDialogState();
}

class _AddEditRuleDialogState extends State<_AddEditRuleDialog> {
  final _formKey = GlobalKey<FormState>();

  SmartPlaylistRuleBase? _selectedRule;

  final _dataController = TextEditingController();
  final _data2Controller = TextEditingController();

  // -- used to keep previous filters while changing sources
  final _tempFilterForTypeMap = <SmartPlaylistFilterType?, SmartPlaylistRuleFilter?>{};

  @override
  void initState() {
    super.initState();
    _selectedRule = widget.initialRule;

    final selectedRule = _selectedRule;
    if (selectedRule != null) {
      if (selectedRule is! SmartPlaylistRuleText) {
        _dataController.text = selectedRule.dataToText(selectedRule.data) ?? '';
        _data2Controller.text = selectedRule.data2ToText(selectedRule.data2) ?? '';
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _selectFilterSource(),
      );
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    _data2Controller.dispose();
    super.dispose();
  }

  void _addOrEditRule() {
    if (_formKey.currentState?.validate() == true) {
      var selectedRule = _selectedRule;
      if (selectedRule == null) return;
      if (selectedRule is SmartPlaylistRuleText) {
        // -- auto add literal text if field had data
        final data = _withPendingLiteral(selectedRule.data, _dataController);
        final data2 = selectedRule.filter.requiresData2Field ? _withPendingLiteral(selectedRule.data2, _data2Controller) : null;
        selectedRule = _selectedRule = selectedRule.copyWith(datas: (data, data2));
      } else {
        selectedRule = _selectedRule = selectedRule.copyWith(
          datas: (
            selectedRule.filter.requiresDataField
                ? selectedRule.textToData(
                    _dataController.text,
                  )
                : null,
            selectedRule.filter.requiresData2Field
                ? selectedRule.textToData2(
                    _data2Controller.text,
                  )
                : null,
          ),
        );
      }
      final error = selectedRule.validate();
      if (error != null) {
        snackyy(message: error, isError: true);
        return;
      }
      widget.onAdd(selectedRule);
      NamidaNavigator.inst.closeDialog();
    }
  }

  static List<SmartPlaylistTextDataToken>? _withPendingLiteral(List<SmartPlaylistTextDataToken>? tokens, TextEditingController controller) {
    final pending = controller.text;
    if (pending.isEmpty) return tokens;
    controller.clear();
    return [...?tokens, SmartPlaylistTextDataTokenLiteral(pending)];
  }

  void _setTextTokens(List<SmartPlaylistTextDataToken>? tokens, {required bool isData2}) {
    final rule = _selectedRule;
    if (rule is! SmartPlaylistRuleText) return;
    final datas = isData2 ? (rule.data, tokens) : (tokens, rule.data2);
    setState(() => _selectedRule = rule.copyWith(datas: datas));
  }

  void _setNumberRule(SmartPlaylistRuleNumber rule) {
    setState(() => _selectedRule = rule);
    NamidaNavigator.inst.popMenu();
  }

  Iterable<Widget> _getScopeChildren() {
    final selectedRule = _selectedRule;
    if (selectedRule is! SmartPlaylistRuleNumber) return [];
    final requiresScope = selectedRule.source.requiresScope;
    final aggregateWhenLeavingTrack = selectedRule.isScoped ? selectedRule.aggregate : selectedRule.source.defaultAggregate;
    return SmartPlaylistNumberScope.values
        .where((scope) => !requiresScope || scope != SmartPlaylistNumberScope.track)
        .map(
          (scope) => _PopupChoiceItem(
            isSelected: scope == selectedRule.scope,
            icon: scope.toIcon(),
            iconText: null,
            text: scope.toText(),
            onTap: () => _setNumberRule(selectedRule.copyWith(scope: scope, aggregate: aggregateWhenLeavingTrack)),
          ),
        );
  }

  Iterable<Widget> _getAggregateChildren() {
    final selectedRule = _selectedRule;
    if (selectedRule is! SmartPlaylistRuleNumber) return [];
    return SmartPlaylistNumberAggregate.values.map(
      (aggregate) => _PopupChoiceItem(
        isSelected: aggregate == selectedRule.aggregate,
        icon: null,
        iconText: aggregate.toIconText(),
        text: aggregate.toText(),
        onTap: () => _setNumberRule(selectedRule.copyWith(aggregate: aggregate)),
      ),
    );
  }

  static Widget _buildFiltersSourceSection(
    BuildContext context,
    SmartPlaylistFilterType type, {
    Rxn<SmartPlaylistRuleFilterSource>? selectedSourceRx,
    required void Function(SmartPlaylistRuleFilterSource source) onSelect,
  }) {
    return SizedBox(
      width: context.width,
      child: NamidaCoolBox(
        extraVPadding: true,
        reducedColors: true,
        colorScheme: context.theme.colorScheme.secondary,
        builder: (context) => Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Icon(
                  type.toIcon(),
                  size: 19.0,
                ),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    type.toText(),
                    style: context.textTheme.displayMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            ObxOrNull(
              rx: selectedSourceRx,
              builder: (context, selectedFilter) => Wrap(
                alignment: WrapAlignment.start,
                runAlignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                runSpacing: 6.0,
                children: [
                  ...type.getRuleSources(withoutCustomSource: true).map(
                    (s) {
                      final isSelected = s == selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: NamidaInkWellButton(
                          borderRadius: 99.0,
                          sizeMultiplier: 0.95,
                          paddingMultiplier: 0.9,
                          icon: s.toIcon(),
                          iconSize: 18.0,
                          trailing:
                              Icon(
                                Broken.tick_circle,
                                size: 16.0,
                              ).animateEntrance(
                                showWhen: isSelected,
                                allCurves: Curves.fastLinearToSlowEaseIn,
                                durationMS: 200,
                              ),
                          text: s.toText(),
                          bgColor: isSelected ? context.theme.colorScheme.secondaryContainer.withOpacityExt(0.4) : context.theme.colorScheme.secondaryContainer.withOpacityExt(0.2),
                          onTap: () => onSelect(s),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFilterSource() async {
    final selectedSourceRx = Rxn<SmartPlaylistRuleFilterSource>(_selectedRule?.source);

    Widget buildFiltersSection(SmartPlaylistFilterType type) {
      return _buildFiltersSourceSection(
        context,
        type,
        onSelect: (s) {
          if (selectedSourceRx.value != s) {
            selectedSourceRx.value = s;
            final previousFilter = _tempFilterForTypeMap[s.type];
            setState(() {
              _selectedRule = null; // avoid subtype errors
              _selectedRule = SmartPlaylistRuleBase.buildFrom(
                type: s.type,
                filter: previousFilter ?? s.recommendedFilter,
                source: s,
                enableCleanup: s.supportsCleanup,
                clockOnly: false,
                relativeDuration: null,
              );
            });
          }

          NamidaNavigator.inst.closeDialog();
        },
      );
    }

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        selectedSourceRx.close();
      },
      dialog: CustomBlurryDialog(
        horizontalInset: 42.0,
        title: lang.source,
        actions: [
          const CancelButton(),
        ],
        child: SizedBox(
          height: context.height * 0.6,
          child: NamidaScrollbarWithController(
            showOnStart: true,
            child: (c) => SmoothSingleChildScrollView(
              controller: c,
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  const SizedBox(height: 8.0),
                  buildFiltersSection(SmartPlaylistFilterType.dateTime),
                  const NamidaContainerDivider(
                    margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  ),
                  buildFiltersSection(SmartPlaylistFilterType.number),
                  const NamidaContainerDivider(
                    margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  ),
                  buildFiltersSection(SmartPlaylistFilterType.boolean),
                  const NamidaContainerDivider(
                    margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  ),
                  buildFiltersSection(SmartPlaylistFilterType.text),
                  const SizedBox(height: 8.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _getFilterTypeChildren() {
    final selectedRule = _selectedRule;
    if (selectedRule == null) return [];
    return selectedRule.filter.type.getRuleFilters().map(
      (filter) => _PopupChoiceItem(
        isSelected: filter == selectedRule.filter,
        icon: filter.toIcon(),
        iconText: filter.toIconText(),
        text: filter.toText(),
        onTap: () {
          final isRelative = filter.isRelativeDate;
          setState(() {
            _selectedRule = selectedRule.copyWith(
              filter: filter,
              datas: isRelative ? (null, null) : null,
              relativeDuration: isRelative ? _selectedRule?.relativeDuration ?? SmartPlaylistRelativeDuration.initial() : null,
            );
          });
          _tempFilterForTypeMap[_selectedRule?.type] = filter;
          NamidaNavigator.inst.popMenu();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRule = _selectedRule;
    return Form(
      key: _formKey,
      child: CustomBlurryDialog(
        horizontalInset: 42.0,
        title: lang.rule,
        actions: [
          const CancelButton(),
          NamidaButton(
            enabled: selectedRule != null,
            onTap: _addOrEditRule,
            text: widget.initialRule != null ? lang.edit : lang.add,
          ),
        ],
        child: Column(
          crossAxisAlignment: .start,
          children: [
            CustomListTile(
              icon: Broken.main_component,
              title: lang.source,
              onTap: () => selectedRule?.source.isAutoSource == true ? null : _selectFilterSource(),
              trailing: _FilterSourceInfoRow(
                source: selectedRule?.source,
              ),
            ),
            NamidaPopupWrapper(
              children: _getFilterTypeChildren,
              child: CustomListTile(
                icon: Broken.filter_square,
                title: lang.filterType,
                trailing: NamidaPopupWrapper(
                  children: _getFilterTypeChildren,
                  child: SmartPlaylistFilterInfoRow(
                    filter: selectedRule?.filter,
                  ),
                ),
              ),
            ),
            if (selectedRule is SmartPlaylistRuleNumber && selectedRule.source.supportsScope) ...[
              NamidaPopupWrapper(
                children: _getScopeChildren,
                child: CustomListTile(
                  icon: Broken.category,
                  title: lang.per,
                  trailing: NamidaPopupWrapper(
                    children: _getScopeChildren,
                    child: _InfoRowRaw(
                      filterIcon: selectedRule.scope.toIcon(),
                      filterIconText: null,
                      filterText: selectedRule.scope.toText(),
                    ),
                  ),
                ),
              ),
              if (selectedRule.isScoped && !selectedRule.source.requiresScope)
                NamidaPopupWrapper(
                  children: _getAggregateChildren,
                  child: CustomListTile(
                    icon: Broken.calculator,
                    title: lang.calculation,
                    trailing: NamidaPopupWrapper(
                      children: _getAggregateChildren,
                      child: _InfoRowRaw(
                        filterIcon: null,
                        filterIconText: selectedRule.aggregate.toIconText(),
                        filterText: selectedRule.aggregate.toText(),
                      ),
                    ),
                  ),
                ),
            ],
            if (selectedRule != null && selectedRule.source.supportsCleanup)
              CustomSwitchListTile(
                icon: Broken.document_filter,
                title: lang.cleanup,
                value: selectedRule.enableCleanup,
                onChanged: (_) {
                  setState(() {
                    _selectedRule = selectedRule.copyWith(
                      enableCleanup: !selectedRule.enableCleanup,
                    );
                  });
                },
              ),
            if (selectedRule != null &&
                selectedRule.source.supportsClockOnly &&
                !selectedRule.filter.isRelativeDate &&
                (selectedRule.filter.requiresDataField || selectedRule.filter.requiresData2Field))
              CustomSwitchListTile(
                icon: Broken.clock,
                title: lang.clockOnly,
                value: selectedRule.clockOnly,
                onChanged: (_) {
                  _dataController.text = '';
                  _data2Controller.text = '';
                  setState(() {
                    _selectedRule = selectedRule.copyWith(
                      clockOnly: !selectedRule.clockOnly,
                    );
                  });
                },
              ),

            if (selectedRule != null && selectedRule.filter.requiresDataField) ...[
              const SizedBox(height: 12.0),
              if (selectedRule is SmartPlaylistRuleText)
                _TextDataTokensEditor(
                  rule: selectedRule,
                  tokens: selectedRule.data,
                  controller: _dataController,
                  onChanged: (tokens) => _setTextTokens(tokens, isData2: false),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CustomTagTextField(
                        controller: _dataController,
                        hintText: selectedRule.toHintText() ?? lang.value,
                        labelText: lang.value,
                        validator: selectedRule.dataValidator,
                      ),
                    ),
                    ?switch (selectedRule) {
                      SmartPlaylistRuleDateTime() => Padding(
                        padding: const EdgeInsetsGeometry.only(left: 8.0),
                        child: _CalendarPickerIconWidget(
                          clockOnly: selectedRule.clockOnly,
                          onSelect: (date) {
                            _dataController.text = selectedRule.dataToText(date) ?? '';
                          },
                        ),
                      ),
                      SmartPlaylistRuleNumber() => Padding(
                        padding: const EdgeInsetsGeometry.only(left: 8.0),
                        child: _NumberSliderWidget(
                          key: ValueKey(selectedRule.source),
                          rule: selectedRule,
                          controller: _dataController,
                        ),
                      ),
                      SmartPlaylistRuleText() => null,
                      SmartPlaylistRuleBoolean() => null,
                    },
                  ],
                ),
            ],

            if (selectedRule != null && selectedRule.filter.requiresData2Field) ...[
              const SizedBox(height: 12.0),
              if (selectedRule is SmartPlaylistRuleText)
                _TextDataTokensEditor(
                  rule: selectedRule,
                  tokens: selectedRule.data2,
                  controller: _data2Controller,
                  onChanged: (tokens) => _setTextTokens(tokens, isData2: true),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CustomTagTextField(
                        controller: _data2Controller,
                        hintText: selectedRule.toHintText() ?? lang.value,
                        labelText: lang.value,
                        validator: selectedRule.dataValidator,
                      ),
                    ),
                    ?switch (selectedRule) {
                      SmartPlaylistRuleDateTime() => Padding(
                        padding: const EdgeInsetsGeometry.only(left: 8.0),
                        child: _CalendarPickerIconWidget(
                          clockOnly: selectedRule.clockOnly,
                          onSelect: (date) {
                            _data2Controller.text = selectedRule.data2ToText(date) ?? '';
                          },
                        ),
                      ),
                      SmartPlaylistRuleNumber() => Padding(
                        padding: const EdgeInsetsGeometry.only(left: 8.0),
                        child: _NumberSliderWidget(
                          key: ValueKey(selectedRule.source),
                          rule: selectedRule,
                          controller: _data2Controller,
                        ),
                      ),
                      SmartPlaylistRuleText() => null,
                      SmartPlaylistRuleBoolean() => null,
                    },
                  ],
                ),
            ],

            if (selectedRule != null && selectedRule.filter.isRelativeDate) ...[
              const SizedBox(height: 12.0),
              _RelativeDurationPicker(
                key: ValueKey(selectedRule.source),
                relativeDuration: selectedRule.relativeDuration ?? const SmartPlaylistRelativeDuration.initial(),
                onChanged: (relDur) {
                  setState(() {
                    _selectedRule = selectedRule.copyWith(relativeDuration: relDur);
                  });
                },
                onUnitChanged: (relDur) {
                  setState(() {
                    _selectedRule = selectedRule.copyWith(relativeDuration: relDur);
                  });
                },
                validator: selectedRule.dataValidator,
              ),
            ],

            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}

class SmartPlaylistFilterInfoRow extends StatelessWidget {
  final SmartPlaylistRuleFilter? filter;
  const SmartPlaylistFilterInfoRow({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    return _InfoRowRaw(
      filterIcon: filter?.toIcon(),
      filterIconText: filter?.toIconText(),
      filterText: filter?.toText(),
    );
  }
}

class _FilterSourceInfoRow extends StatelessWidget {
  final SmartPlaylistRuleFilterSource? source;
  const _FilterSourceInfoRow({required this.source});

  @override
  Widget build(BuildContext context) {
    return _InfoRowRaw(
      filterIcon: source?.toIcon(),
      filterIconText: null,
      filterText: source?.toText(),
    );
  }
}

class _InfoRowRaw extends StatelessWidget {
  final IconData? filterIcon;
  final String? filterIconText;
  final String? filterText;

  const _InfoRowRaw({
    required this.filterIcon,
    required this.filterIconText,
    required this.filterText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
            color: context.theme.cardColor,
          ),
          child: SizedBox(
            width: 24.0,
            height: 24.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: FittedBox(
                fit: .scaleDown,
                child: filterIcon != null
                    ? Icon(
                        filterIcon,
                        size: 16.0,
                      )
                    : filterIconText != null
                    ? Text(
                        filterIconText!,
                        style: context.textTheme.displaySmall?.copyWith(fontSize: 22.0),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6.0),
        Flexible(
          child: Text(
            filterText ?? '?',
            style: context.textTheme.displayMedium,
          ),
        ),
      ],
    );
  }
}

class _PopupChoiceItem extends StatelessWidget {
  final bool isSelected;
  final IconData? icon;
  final String? iconText;
  final String text;
  final VoidCallback onTap;

  const _PopupChoiceItem({
    required this.isSelected,
    required this.icon,
    required this.iconText,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
      child: NamidaInkWell(
        borderRadius: 8.0,
        padding: const .symmetric(vertical: 8.0, horizontal: 4.0),
        bgColor: isSelected ? context.theme.colorScheme.secondary.withOpacityExt(0.1) : null,
        onTap: onTap,
        child: _InfoRowRaw(
          filterIcon: icon,
          filterIconText: iconText,
          filterText: text,
        ),
      ),
    );
  }
}

class _ChoiceChipsWrap<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) toText;
  final void Function(T value) onSelect;

  const _ChoiceChipsWrap({
    required this.values,
    required this.selected,
    required this.toText,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Wrap(
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      runSpacing: 4.0,
      children: values.map((value) {
        final isSelected = value == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: NamidaInkWellButton(
            icon: null,
            borderRadius: 99.0,
            trailing:
                Icon(
                  Broken.tick_circle,
                  size: 15.0,
                ).animateEntrance(
                  showWhen: isSelected,
                  allCurves: Curves.fastLinearToSlowEaseIn,
                  durationMS: 200,
                ),
            text: toText(value),
            bgColor: isSelected ? colorScheme.secondaryContainer.withOpacityExt(0.4) : colorScheme.secondaryContainer.withOpacityExt(0.2),
            onTap: () => onSelect(value),
          ),
        );
      }).toFixedList(),
    );
  }
}

class _CalendarPickerIconWidget extends StatelessWidget {
  final bool clockOnly;
  final void Function(DateTime date) onSelect;
  const _CalendarPickerIconWidget({required this.clockOnly, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      icon: clockOnly ? Broken.clock : Broken.calendar,
      onPressed: () async {
        if (clockOnly) {
          final res = await showTimePicker(
            context: context,
            useRootNavigator: true,
            initialTime: TimeOfDay.now(),
            initialEntryMode: .dial,
          );
          if (res != null) {
            onSelect(DateTime(0, 1, 1, res.hour, res.minute));
          }
        } else {
          showCalendarDialog(
            title: lang.date,
            buttonText: lang.confirm,
            useHistoryDates: false,
            calendarType: NamidaCalendarDatePickerType.single,
            onGenerate: (dates) {
              if (dates.isNotEmpty) {
                onSelect(dates.first);
              }
              NamidaNavigator.inst.closeDialog();
            },
          );
        }
      },
    );
  }
}

class _NumberSliderWidget extends StatefulWidget {
  final SmartPlaylistRuleNumber rule;
  final TextEditingController controller;
  const _NumberSliderWidget({super.key, required this.rule, required this.controller});

  @override
  State<_NumberSliderWidget> createState() => _NumberSliderWidgetState();
}

class _NumberSliderWidgetState extends State<_NumberSliderWidget> {
  late final config = widget.rule.source.buildSliderConfig();
  late final _syncer = _TextSliderSyncController(
    textController: widget.controller,
    textToSlider: (text) {
      final value = int.tryParse(text) ?? config.min;
      return switch (widget.rule.source) {
        SmartPlaylistRuleFilterNumberSource.sizeB => (value / (1024 * 1024)).round().clamp(config.min, config.max),
        _ => value.clamp(config.min, config.max),
      };
    },
    sliderToDisplayText: config.formatter,
    sliderToRawText: (sliderVal) => switch (widget.rule.source) {
      SmartPlaylistRuleFilterNumberSource.sizeB => (sliderVal * 1024 * 1024).toString(),
      _ => sliderVal.toString(),
    },
    onChanged: (_) {
      // -- controller already updates
    },
  );

  @override
  void dispose() {
    _syncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.width * 0.3),
      child: _SyncedWheelSlider(
        syncer: _syncer,
        min: config.min,
        max: config.max,
        stepper: config.stepper,
      ),
    );
  }
}

class _RelativeDurationPicker extends StatefulWidget {
  final SmartPlaylistRelativeDuration relativeDuration;
  final String? Function(String? value)? validator;
  final void Function(SmartPlaylistRelativeDuration relDur) onChanged;
  final void Function(SmartPlaylistRelativeDuration relDur) onUnitChanged;

  const _RelativeDurationPicker({
    super.key,
    required this.relativeDuration,
    required this.validator,
    required this.onChanged,
    required this.onUnitChanged,
  });

  @override
  State<_RelativeDurationPicker> createState() => _RelativeDurationPickerState();
}

class _RelativeDurationPickerState extends State<_RelativeDurationPicker> {
  final _controller = TextEditingController();
  late final _syncer = _TextSliderSyncController(
    textController: _controller,
    textToSlider: (text) => int.tryParse(text)?.clamp(1, 999) ?? 1,
    sliderToDisplayText: (v) => '$v',
    sliderToRawText: (v) => '$v',
    onChanged: _onAmountChanged,
  );

  @override
  void initState() {
    super.initState();
    _controller.text = widget.relativeDuration.amount.toString();
  }

  @override
  void dispose() {
    _syncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RelativeDurationPicker oldWidget) {
    // -- uncomment if u put unit in slider text again
    // if (oldWidget.relativeDuration.unit != widget.relativeDuration.unit) {
    //   _syncer.refreshDisplayText();
    // }
    super.didUpdateWidget(oldWidget);
  }

  void _onAmountChanged(int amount) {
    widget.onChanged(
      SmartPlaylistRelativeDuration(
        amount: amount,
        unit: widget.relativeDuration.unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTagTextField(
                controller: _controller,
                hintText: '1, 2, 7...',
                labelText: "${lang.value} (${widget.relativeDuration.unit.toText()})",
                validator: widget.validator,
                onChanged: (v) {
                  final amount = int.tryParse(v);
                  _onAmountChanged(amount ?? 0);
                },
              ),
            ),
            const SizedBox(width: 8.0),
            KeyedSubtree(
              child: _SyncedWheelSlider(
                syncer: _syncer,
                min: 1,
                max: 999,
                stepper: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        _ChoiceChipsWrap(
          values: SmartPlaylistRelativeUnit.values,
          selected: widget.relativeDuration.unit,
          toText: (unit) => unit.toText(),
          onSelect: (unit) => widget.onUnitChanged(
            SmartPlaylistRelativeDuration(
              amount: widget.relativeDuration.amount,
              unit: unit,
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncedWheelSlider extends StatelessWidget {
  final _TextSliderSyncController syncer;
  final int min;
  final int max;
  final int stepper;

  const _SyncedWheelSlider({
    required this.syncer,
    required this.min,
    required this.max,
    required this.stepper,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: syncer.sliderValue,
      builder: (context, value, _) => ValueListenableBuilder(
        valueListenable: syncer.sliderText,
        builder: (context, text, _) => NamidaWheelSlider(
          key: ValueKey(value),
          min: min,
          max: max,
          stepper: stepper,
          initValue: value,
          text: text,
          onValueChanged: syncer.onSliderChanged,
        ),
      ),
    );
  }
}

class _TextSliderSyncController {
  final TextEditingController textController;
  final int Function(String text) textToSlider;
  final String Function(int sliderVal) sliderToDisplayText;
  final String Function(int sliderVal) sliderToRawText;
  final void Function(int sliderVal) onChanged;

  bool _isSliderChanging = false;
  late final ValueNotifier<int> sliderValue;
  late final ValueNotifier<String> sliderText;

  _TextSliderSyncController({
    required this.textController,
    required this.textToSlider,
    required this.sliderToDisplayText,
    required this.sliderToRawText,
    required this.onChanged,
  }) {
    final initVal = textToSlider(textController.text);
    sliderValue = ValueNotifier(initVal);
    sliderText = ValueNotifier(sliderToDisplayText(initVal));
    textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_isSliderChanging) return;
    final newVal = textToSlider(textController.text);
    if (newVal != sliderValue.value) {
      sliderValue.value = newVal;
      sliderText.value = sliderToDisplayText(newVal);
    }
  }

  void refreshDisplayText() {
    sliderText.value = sliderToDisplayText(sliderValue.value);
  }

  void onSliderChanged(int sliderVal) {
    _isSliderChanging = true;
    textController.text = sliderToRawText(sliderVal);
    sliderText.value = sliderToDisplayText(sliderVal);
    onChanged(sliderVal);
    _isSliderChanging = false;
  }

  void dispose() {
    textController.removeListener(_onTextChanged);
    sliderValue.dispose();
    sliderText.dispose();
  }
}

class _TextDataTokensEditor extends StatefulWidget {
  final SmartPlaylistRuleText rule;
  final List<SmartPlaylistTextDataToken>? tokens;
  final TextEditingController controller;
  final void Function(List<SmartPlaylistTextDataToken>? tokens) onChanged;

  const _TextDataTokensEditor({
    required this.rule,
    required this.tokens,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_TextDataTokensEditor> createState() => _TextDataTokensEditorState();
}

class _TextDataTokensEditorState extends State<_TextDataTokensEditor> {
  late final _tokensCopy = List<SmartPlaylistTextDataToken>.from(widget.tokens ?? <SmartPlaylistTextDataToken>[]);
  final _suggestionsProvider = TextSuggestionsProvider();

  Set<String>? _buildAlreadyAddedLiterals() {
    Set<String>? literals;
    for (final token in _tokensCopy) {
      if (token is SmartPlaylistTextDataTokenLiteral) (literals ??= <String>{}).add(token.text.toLowerCase());
    }
    return literals;
  }

  void _refreshTokens() {
    widget.onChanged(_tokensCopy.isEmpty ? null : _tokensCopy);
  }

  void _addLiteralFromField() {
    final text = widget.controller.text;
    if (text.isEmpty) return;
    _tokensCopy.add(SmartPlaylistTextDataTokenLiteral(text));
    _refreshTokens();
    widget.controller.clear();
  }

  void _addLiteralFromSuggestion(String text) {
    widget.controller.text = text;
    _addLiteralFromField();
  }

  void _removeAt(int index) {
    _tokensCopy.removeAt(index);
    _refreshTokens();
  }

  void _editLiteral(int index, SmartPlaylistTextDataTokenLiteral token) {
    widget.controller.text = token.text;
    // _removeAt(index);
  }

  Future<void> _pickSource({int? replaceIndex}) async {
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        horizontalInset: 42.0,
        title: lang.source,
        actions: [const CancelButton()],
        child: SizedBox(
          height: context.height * 0.55,
          width: context.width,
          child: NamidaScrollbarWithController(
            showOnStart: true,
            child: (c) => SmoothSingleChildScrollView(
              controller: c,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  runSpacing: 6.0,
                  children: [
                    _AddEditRuleDialogState._buildFiltersSourceSection(
                      context,
                      SmartPlaylistFilterType.text,
                      onSelect: (source) {
                        source as SmartPlaylistRuleFilterTextSource;
                        final tokenSource = SmartPlaylistTextDataTokenSource(source);
                        if (replaceIndex != null) {
                          _tokensCopy[replaceIndex] = tokenSource;
                        } else {
                          _tokensCopy.add(tokenSource);
                        }
                        _refreshTokens();

                        NamidaNavigator.inst.closeDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokensCopy;
    final filter = widget.rule.filter;
    final isRegex = filter.isRegex();

    final suggestionsSource = widget.rule.source.toSuggestionsSource();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        border: Border.all(color: context.theme.dividerColor.withOpacityExt(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tokens.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                child: Text(
                  lang.emptyValue,
                  style: context.textTheme.displaySmall,
                ),
              )
            else
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: [
                  ...tokens.mapIndexed(
                    (token, index) {
                      final (IconData? icon, String label, Color bgColor, VoidCallback onTap) = switch (token) {
                        SmartPlaylistTextDataTokenSource() => (
                          token.source.toIcon(),
                          token.displayText(),
                          context.theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
                          () => _pickSource(replaceIndex: index),
                        ),
                        SmartPlaylistTextDataTokenLiteral() => (
                          null,
                          '"${token.text}"',
                          context.theme.cardColor,
                          () => _editLiteral(index, token),
                        ),
                      };
                      return NamidaInkWell(
                        borderRadius: 99.0,
                        bgColor: bgColor,
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                        onTap: onTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4.0),
                            if (icon != null) ...[
                              Icon(
                                icon,
                                size: 14.0,
                              ),
                              const SizedBox(width: 4.0),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                style: context.textTheme.displaySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2.0),
                            NamidaIconButton(
                              horizontalPadding: 4.0,
                              icon: Broken.close_circle,
                              iconSize: 14.0,
                              onPressed: () => _removeAt(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: CustomTagTextField(
                    controller: widget.controller,
                    hintText: isRegex ? '.*' : lang.value,
                    labelText: lang.value,
                    onFieldSubmitted: (_) => _addLiteralFromField(),
                  ),
                ),
                const SizedBox(width: 6.0),
                ValueListenableBuilder(
                  valueListenable: widget.controller,
                  builder: (context, value, child) {
                    final text = value.text;
                    return text.isEmpty
                        ? NamidaIconButton(
                            tooltip: () => lang.source,
                            icon: Broken.main_component,
                            onPressed: _pickSource,
                          )
                        : NamidaIconButton(
                            tooltip: () => lang.add,
                            icon: Broken.add_square,
                            onPressed: _addLiteralFromField,
                          );
                  },
                ),
              ],
            ),
            if (suggestionsSource != null)
              ValueListenableBuilder(
                valueListenable: widget.controller,
                builder: (context, value, child) {
                  final results = TextSuggestionsMatcher.filter(
                    values: _suggestionsProvider.valuesFor(suggestionsSource),
                    query: value.text,
                    excludeLowercased: _buildAlreadyAddedLiterals(),
                  );
                  if (results.isEmpty) return const SizedBox();
                  return TextSuggestionsChipsRow(
                    padding: const EdgeInsets.only(top: 8.0),
                    suggestions: results,
                    onTap: _addLiteralFromSuggestion,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final SmartPlaylistLimit? limit;
  final void Function(SmartPlaylistLimit? limit) onChanged;

  const _LimitTile({
    required this.limit,
    required this.onChanged,
  });

  void _openLimitDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: _LimitDialog(
        initialLimit: limit ?? const SmartPlaylistLimit.initial(),
        onConfirm: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final limit = this.limit;
    return NamidaInkWell(
      onTap: _openLimitDialog,
      borderRadius: 8.0,
      bgColor: theme.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(
            Broken.ranking,
            size: 18.0,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                Text(
                  lang.limit,
                  style: textTheme.displayMedium,
                ),
                Text(
                  limit?.toText() ?? lang.none,
                  style: textTheme.displaySmall,
                ),
              ],
            ),
          ),
          if (limit != null)
            NamidaIconButton(
              horizontalPadding: 4.0,
              icon: Broken.close_circle,
              iconSize: 18.0,
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}

class _LimitDialog extends StatefulWidget {
  final SmartPlaylistLimit initialLimit;
  final void Function(SmartPlaylistLimit limit) onConfirm;

  const _LimitDialog({
    required this.initialLimit,
    required this.onConfirm,
  });

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  static const _maxAmount = 9999;

  final _formKey = GlobalKey<FormState>();
  late SmartPlaylistLimit _limit = widget.initialLimit;
  late final _amountController = TextEditingController(text: widget.initialLimit.amount.toString());
  late final _syncer = _TextSliderSyncController(
    textController: _amountController,
    textToSlider: (text) => int.tryParse(text)?.clamp(1, _maxAmount) ?? 1,
    sliderToDisplayText: (v) => '$v',
    sliderToRawText: (v) => '$v',
    onChanged: (_) {
      // -- controller already updates
    },
  );

  @override
  void dispose() {
    _syncer.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _pickSorts() {
    NamidaOnTaps.inst.onTracksSortIconTap(
      currentSorts: _limit.sorts,
      currentReverse: _limit.sortReverse,
      onChanged: (sorts, reverse) {
        setState(() => _limit = _limit.copyWith(sorts: sorts, sortReverse: reverse));
      },
    );
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    final amount = int.parse(_amountController.text);
    widget.onConfirm(_limit.copyWith(amount: amount));
    NamidaNavigator.inst.closeDialog();
  }

  String? _validateAmount(String? value) {
    final amount = value == null ? null : int.tryParse(value);
    if (amount == null || amount <= 0) return '1+';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sortText = _limit.sorts.firstOrNull?.toText() ?? lang.auto;
    return Form(
      key: _formKey,
      child: CustomBlurryDialog(
        normalTitleStyle: true,
        icon: Broken.ranking,
        horizontalInset: 42.0,
        title: lang.limit,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.confirm,
            onTap: _confirm,
          ),
        ],
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: CustomTagTextField(
                    controller: _amountController,
                    hintText: '25, 50, 100...',
                    labelText: '${lang.value} (${_limit.unit.toText()})',
                    isNumeric: true,
                    validator: _validateAmount,
                  ),
                ),
                const SizedBox(width: 8.0),
                _SyncedWheelSlider(
                  syncer: _syncer,
                  min: 1,
                  max: _maxAmount,
                  stepper: 1,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _ChoiceChipsWrap(
              values: SmartPlaylistLimitUnit.values,
              selected: _limit.unit,
              toText: (unit) => unit.toText(),
              onSelect: (unit) => setState(() => _limit = _limit.copyWith(unit: unit)),
            ),
            const SizedBox(height: 8.0),
            CustomListTile(
              icon: Broken.sort,
              title: lang.selectedBy,
              onTap: _pickSorts,
              trailing: Row(
                mainAxisSize: .min,
                children: [
                  Text(
                    sortText,
                    style: context.textTheme.displayMedium,
                  ),
                  const SizedBox(width: 4.0),
                  Icon(
                    _limit.sortReverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                    size: 18.0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
