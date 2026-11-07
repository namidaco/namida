import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/class/sort_chain.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/controller/text_suggestions_provider.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/text_suggestions.dart';

class CreateSmartPlaylistDialog extends StatefulWidget {
  final SmartPlaylistWrapper? initialSmartPlaylistWrapper;
  final Completer<SmartPlaylistWrapper?>? _onSearchCompleter;
  final SmartPlaylist? _prefillSmartPlaylist;

  const CreateSmartPlaylistDialog({super.key, this.initialSmartPlaylistWrapper}) : _onSearchCompleter = null, _prefillSmartPlaylist = null;

  const CreateSmartPlaylistDialog.forTempSmartSearch({
    super.key,
    this.initialSmartPlaylistWrapper,
    required Completer<SmartPlaylistWrapper?> completer,
  }) : _onSearchCompleter = completer,
       _prefillSmartPlaylist = null;

  const CreateSmartPlaylistDialog._prefilled({
    required SmartPlaylist prefill,
  }) : initialSmartPlaylistWrapper = null,
       _onSearchCompleter = null,
       _prefillSmartPlaylist = prefill;

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
  SortChain<SortType> _sorting = const SortChain([]);
  final _moods = <String>[];
  final _ruleGroups = <SmartPlaylistRuleGroup>[];
  SmartPlaylistLimit? _limit;

  @override
  void initState() {
    final sp = widget.initialSmartPlaylistWrapper?.value ?? widget._prefillSmartPlaylist;
    if (sp != null) {
      _nameController.text = sp.name;
      _joiner = sp.joiner;
      _sorting = sp.sorting;
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
    _sorting = const SortChain([]);
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
      sorting: _sorting,
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

  void _createSmartPlaylistFromSearch() {
    final prefill = _buildSmartPlaylistFromCurrentParams().copyWith(name: '');
    NamidaNavigator.inst.navigateDialog(
      dialog: CreateSmartPlaylistDialog._prefilled(prefill: prefill),
    );
  }

  void _setJoiner(SmartJoiner joiner) {
    if (_joiner == joiner) return;
    setState(() {
      _joiner = joiner;
      _resolvedTracksCountForCurrentSmartPlaylist = _buildResolvedTracksCount();
    });
  }

  void _setSorting(SortChain<SortType> sorting) {
    setState(() => _sorting = sorting);
  }

  void _setSortReverse(bool sortReverse) {
    if (_sorting.reverse == sortReverse) return;
    setState(() => _sorting = _sorting.copyWith(reverse: sortReverse));
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
          dateParts: SmartPlaylistDateParts.date,
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
            final isSimilarToAnotherRule = indexOfAlreadyExistingSimilar >= 0 && indexOfAlreadyExistingSimilar != initialRule.$1;
            group.rules[initialRule.$1] = rule;
            if (isSimilarToAnotherRule) {
              group.rules.removeAt(indexOfAlreadyExistingSimilar); // also remove old one
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
    final textStyleMedium = NText.medium.of(context).copyWith(fontWeight: FontWeight.w500);
    final textStyleSmall = NText.small.of(context).copyWith(fontWeight: FontWeight.w500);
    final isForTempSearch = widget._onSearchCompleter != null;
    final dialogTitle = isForTempSearch ? lang.smartSearch : lang.smartPlaylist;
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
                    NamidaText(
                      dialogTitle,
                      style: NText.large,
                    ),
                    if (_resolvedTracksCountForCurrentSmartPlaylist != null)
                      NamidaText(
                        _resolvedTracksCountForCurrentSmartPlaylist!.displayTrackKeyword,
                        style: NText.small,
                      ),
                  ],
                ),
              ),
              if (!isForTempSearch)
                Expanded(
                  child: Row(
                    mainAxisAlignment: .end,
                    children: [
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: NamidaButton(
                          dense: true,
                          minHeight: NamidaTextButton.kDefaultMinHeight * 0.5,
                          colors: NamidaButtonColors.dimmed,
                          icon: Broken.sort,
                          text: _sorting.firstType?.toText() ?? lang.auto,
                          fontSizeMultiplier: 0.95,
                          onTap: () => NamidaOnTaps.inst.onTracksSortIconTap(
                            currentSorting: _sorting,
                            onChanged: _setSorting,
                          ),
                        ),
                      ),
                      NamidaIconButton(
                        horizontalPadding: 8.0,
                        icon: _sorting.reverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                        iconSize: 20.0,
                        onPressed: () => _setSortReverse(!_sorting.reverse),
                      ),
                    ],
                  ),
                ),

              if (isForTempSearch && ruleGroupsAreValid) ...[
                NamidaIconButton(
                  horizontalPadding: 8.0,
                  icon: Broken.refresh,
                  iconSize: 20.0,
                  onPressed: _resetEverything,
                ),
                NamidaIconButton(
                  horizontalPadding: 8.0,
                  icon: Broken.add_square,
                  iconSize: 20.0,
                  tooltip: () => lang.createNewSmartPlaylist,
                  onPressed: _createSmartPlaylistFromSearch,
                ),
              ],
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
                            final groupIndexWidget = NDecoratedBox(
                              decoration: (colors) => BoxDecoration(
                                color: colors.secondary.withOpacityExt(0.25),
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
                              child: _ThemedCoolBox(
                                colorRole: .secondary,
                                extraVPadding: true,
                                hPadding: 6.0,
                                child: Column(
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
                                                                    child: NDecoratedBox(
                                                                      decoration: (colors) => BoxDecoration(
                                                                        color: colors.card,
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
                                                              bgColor: NColors.card,
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
                                                        bgColor: const NColors(.secondary, opacity: 0.1),
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
                      child: _ThemedCoolBox(
                        colorRole: .primary,
                        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        extraVPadding: true,
                        child: Row(
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
                  bgColor: isSelected ? const NColors(.secondary, opacity: 0.5) : NColors.card,
                  borderRadius: 4.0,
                  padding: const EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 6.0),
                  onTap: () => onTap(joiner),
                  child: NamidaText(
                    joiner.toTitle(),
                    style: NText.small,
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
  List<SmartPlaylistTextDataToken>? _textTokens;
  List<SmartPlaylistTextDataToken>? _textTokens2;
  SmartPlaylistRelativeDuration? _relativeDuration;
  final _datePartsNotifier = ValueNotifier(SmartPlaylistDateParts.date);
  SmartPlaylistDateValue? _dateValue;
  SmartPlaylistDateValue? _dateValue2;

  // -- used to keep previous filters while changing sources
  final _tempFilterForTypeMap = <SmartPlaylistFilterType?, SmartPlaylistRuleFilter?>{};

  @override
  void initState() {
    super.initState();
    _selectedRule = widget.initialRule;

    final selectedRule = _selectedRule;
    if (selectedRule != null) {
      _tempFilterForTypeMap[selectedRule.type] = selectedRule.filter;
      _relativeDuration = selectedRule.relativeDuration;
      if (selectedRule is SmartPlaylistRuleText) {
        _textTokens = selectedRule.data;
        _textTokens2 = selectedRule.data2;
      } else {
        _dataController.text = selectedRule.dataToText(selectedRule.data) ?? '';
        _data2Controller.text = selectedRule.data2ToText(selectedRule.data2) ?? '';
      }
      if (selectedRule is SmartPlaylistRuleDateTime) {
        _datePartsNotifier.value = selectedRule.parts;
        _dateValue = selectedRule.data;
        _dateValue2 = selectedRule.data2;
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
    _datePartsNotifier.dispose();
    super.dispose();
  }

  void _addOrEditRule() {
    if (_formKey.currentState?.validate() == true) {
      final selectedRule = _selectedRule;
      if (selectedRule == null) return;
      final SmartPlaylistRuleBase rule;
      if (selectedRule is SmartPlaylistRuleText) {
        // -- auto add literal text if field had data
        final data = _withPendingLiteral(_textTokens, _dataController.text);
        final data2 = _withPendingLiteral(_textTokens2, _data2Controller.text);
        rule = selectedRule.copyWith(datas: (data, data2));
      } else if (selectedRule is SmartPlaylistRuleDateTime) {
        final data = _dateValueOf(selectedRule, _dateValue, _dataController);
        final data2 = _dateValueOf(selectedRule, _dateValue2, _data2Controller);
        rule = selectedRule.copyWith(datas: (data, data2));
      } else {
        final data = selectedRule.textToData(_dataController.text);
        final data2 = selectedRule.textToData2(_data2Controller.text);
        rule = selectedRule.copyWith(datas: (data, data2));
      }
      final error = rule.validate();
      if (error != null) {
        snackyy(message: error, isError: true);
        return;
      }
      widget.onAdd(rule);
      NamidaNavigator.inst.closeDialog();
    }
  }

  static List<SmartPlaylistTextDataToken>? _withPendingLiteral(List<SmartPlaylistTextDataToken>? tokens, String pendingText) {
    if (pendingText.isEmpty) return tokens;
    return [...?tokens, SmartPlaylistTextDataTokenLiteral(pendingText)];
  }

  /// full dates are typed, the other parts and "now" values come from their own fields.
  static SmartPlaylistDateValue? _dateValueOf(SmartPlaylistRuleDateTime rule, SmartPlaylistDateValue? draft, TextEditingController controller) {
    if (draft is SmartPlaylistNowDate || !rule.parts.isCalendarDate) return draft;
    return rule.textToData(controller.text);
  }

  static SmartPlaylistDateValue? _nowValueOrNull(SmartPlaylistDateValue? value) => value is SmartPlaylistNowDate ? value : null;

  void _toggleDatePart(SmartPlaylistDatePart part) {
    final selectedRule = _selectedRule;
    if (selectedRule is! SmartPlaylistRuleDateTime) return;
    final previousParts = _datePartsNotifier.value;
    final parts = previousParts.toggled(part);
    if (parts == previousParts) return;
    final keepsTypedDates = previousParts.isCalendarDate && parts.isCalendarDate;
    if (!keepsTypedDates) {
      _dataController.clear();
      _data2Controller.clear();
    }
    _datePartsNotifier.value = parts;
    setState(() {
      _dateValue = _nowValueOrNull(_dateValue);
      _dateValue2 = _nowValueOrNull(_dateValue2);
      _selectedRule = selectedRule.copyWith(parts: parts);
    });
  }

  void _setRelativeDuration(SmartPlaylistRelativeDuration relativeDuration) {
    final selectedRule = _selectedRule;
    if (selectedRule == null) return;
    setState(() {
      _relativeDuration = relativeDuration;
      _selectedRule = selectedRule.copyWith(relativeDuration: relativeDuration);
    });
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
                  child: NamidaText(
                    type.toText(),
                    style: NText.medium,
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
                      final tickIcon =
                          const Icon(
                            Broken.tick_circle,
                            size: 16.0,
                          ).animateEntrance(
                            showWhen: isSelected,
                            allCurves: Curves.fastLinearToSlowEaseIn,
                            durationMS: 200,
                          );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: NBuilder(
                          selfAnimated: true,
                          builder: (context, colors) => NamidaInkWellButton(
                            borderRadius: 99.0,
                            sizeMultiplier: 0.95,
                            paddingMultiplier: 0.9,
                            icon: s.toIcon(),
                            iconSize: 18.0,
                            trailing: tickIcon,
                            text: s.toText(),
                            bgColor: isSelected ? colors.secondaryContainer.withOpacityExt(0.4) : colors.secondaryContainer.withOpacityExt(0.2),
                            onTap: () => onSelect(s),
                          ),
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
            final previousRule = _selectedRule;
            final keptDateRule = previousRule is SmartPlaylistRuleDateTime && s.type == SmartPlaylistFilterType.dateTime ? previousRule : null;
            if (keptDateRule == null) {
              _dataController.clear();
              _data2Controller.clear();
              _textTokens = null;
              _textTokens2 = null;
              _relativeDuration = null;
              _datePartsNotifier.value = SmartPlaylistDateParts.date;
              _dateValue = null;
              _dateValue2 = null;
            }
            final filter = _tempFilterForTypeMap[s.type] ?? s.recommendedFilter;
            setState(() {
              _selectedRule = null; // avoid subtype errors
              _selectedRule = SmartPlaylistRuleBase.buildFrom(
                type: s.type,
                filter: filter,
                source: s,
                enableCleanup: s.supportsCleanup,
                dateParts: _datePartsNotifier.value,
                relativeDuration: _relativeDuration,
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
        actions: const [
          CancelButton(),
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

  Iterable<Widget> _getDatePartsChildren() {
    return SmartPlaylistDatePart.values.map(
      (part) => ValueListenableBuilder(
        valueListenable: _datePartsNotifier,
        builder: (context, parts, _) => _PopupChoiceItem(
          isSelected: parts.has(part),
          icon: part.toIcon(),
          iconText: null,
          text: part.toText(),
          onTap: () => _toggleDatePart(part),
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
          final relativeDuration = _relativeDuration ?? const SmartPlaylistRelativeDuration.initial();
          final rule = selectedRule.copyWith(
            filter: filter,
            relativeDuration: relativeDuration,
          );
          final ruleWithDateParts = rule is SmartPlaylistRuleDateTime ? rule.copyWith(parts: _datePartsNotifier.value) : rule;
          setState(() => _selectedRule = ruleWithDateParts);
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
              childBuilder: (openMenu) => CustomListTile(
                icon: Broken.filter_square,
                title: lang.filterType,
                trailing: NamidaPopupWrapper(
                  children: _getFilterTypeChildren,
                  child: SmartPlaylistFilterInfoRow(
                    filter: selectedRule?.filter,
                  ),
                ),
                onTap: openMenu,
              ),
            ),
            if (selectedRule is SmartPlaylistRuleNumber && selectedRule.source.supportsScope) ...[
              NamidaPopupWrapper(
                children: _getScopeChildren,
                childBuilder: (openMenu) => CustomListTile(
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
                  onTap: openMenu,
                ),
              ),
              if (selectedRule.isScoped && !selectedRule.source.requiresScope)
                NamidaPopupWrapper(
                  children: _getAggregateChildren,
                  childBuilder: (openMenu) => CustomListTile(
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
                    onTap: openMenu,
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
            if (selectedRule is SmartPlaylistRuleDateTime && !selectedRule.filter.isRelativeDate && selectedRule.filter.requiresDataField)
              NamidaPopupWrapper(
                children: _getDatePartsChildren,
                childBuilder: (openMenu) => CustomListTile(
                  icon: Broken.calendar_search,
                  title: lang.compareBy,
                  trailing: NamidaPopupWrapper(
                    children: _getDatePartsChildren,
                    child: _InfoRowRaw(
                      filterIcon: selectedRule.parts.toIcon(),
                      filterIconText: null,
                      filterText: selectedRule.parts.toText(),
                    ),
                  ),
                  onTap: openMenu,
                ),
              ),

            if (selectedRule != null && selectedRule.filter.requiresDataField) ...[
              const SizedBox(height: 12.0),
              switch (selectedRule) {
                SmartPlaylistRuleText() => _TextDataTokensEditor(
                  rule: selectedRule,
                  tokens: _textTokens,
                  controller: _dataController,
                  onChanged: (tokens) => setState(() => _textTokens = tokens),
                ),
                SmartPlaylistRuleDateTime() => _DateValueEditor(
                  key: ValueKey((selectedRule.parts, isData2: false)),
                  rule: selectedRule,
                  textController: _dataController,
                  value: _dateValue,
                  onChanged: (value) => setState(() => _dateValue = value),
                ),
                SmartPlaylistRuleNumber() => _NumberValueField(
                  rule: selectedRule,
                  controller: _dataController,
                ),
                SmartPlaylistRuleBoolean() => const SizedBox(),
              },
            ],

            if (selectedRule != null && selectedRule.filter.requiresData2Field) ...[
              const SizedBox(height: 12.0),
              switch (selectedRule) {
                SmartPlaylistRuleText() => _TextDataTokensEditor(
                  rule: selectedRule,
                  tokens: _textTokens2,
                  controller: _data2Controller,
                  onChanged: (tokens) => setState(() => _textTokens2 = tokens),
                ),
                SmartPlaylistRuleDateTime() => _DateValueEditor(
                  key: ValueKey((selectedRule.parts, isData2: true)),
                  rule: selectedRule,
                  textController: _data2Controller,
                  value: _dateValue2,
                  onChanged: (value) => setState(() => _dateValue2 = value),
                ),
                SmartPlaylistRuleNumber() => _NumberValueField(
                  rule: selectedRule,
                  controller: _data2Controller,
                ),
                SmartPlaylistRuleBoolean() => const SizedBox(),
              },
            ],

            if (selectedRule != null && selectedRule.filter.isRelativeDate) ...[
              const SizedBox(height: 12.0),
              _RelativeDurationPicker(
                key: ValueKey(selectedRule.source),
                relativeDuration: selectedRule.relativeDuration ?? const SmartPlaylistRelativeDuration.initial(),
                onChanged: _setRelativeDuration,
                onUnitChanged: _setRelativeDuration,
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
        NDecoratedBox(
          decoration: (colors) => BoxDecoration(
            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
            color: colors.card,
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
                    ? NamidaText(
                        filterIconText!,
                        style: const NText(.small, size: .s22),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6.0),
        Flexible(
          child: NamidaText(
            filterText ?? '?',
            style: NText.medium,
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
        bgColor: isSelected ? const NColors(.secondary, opacity: 0.1) : null,
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
  final bool Function(T value) isSelected;
  final String Function(T value) toText;
  final void Function(T value) onSelect;

  const _ChoiceChipsWrap({
    required this.values,
    required this.isSelected,
    required this.toText,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      runSpacing: 4.0,
      children: values.map((value) {
        final isSelected = this.isSelected(value);
        final tickIcon =
            const Icon(
              Broken.tick_circle,
              size: 15.0,
            ).animateEntrance(
              showWhen: isSelected,
              allCurves: Curves.fastLinearToSlowEaseIn,
              durationMS: 200,
            );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: NBuilder(
            selfAnimated: true,
            builder: (context, colors) => NamidaInkWellButton(
              icon: null,
              borderRadius: 99.0,
              trailing: tickIcon,
              text: toText(value),
              bgColor: isSelected ? colors.secondaryContainer.withOpacityExt(0.4) : colors.secondaryContainer.withOpacityExt(0.2),
              onTap: () => onSelect(value),
            ),
          ),
        );
      }).toFixedList(),
    );
  }
}

class _CalendarPickerIconWidget extends StatelessWidget {
  final bool pickClock;
  final void Function(DateTime date) onSelect;
  const _CalendarPickerIconWidget({required this.pickClock, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      horizontalPadding: 4.0,
      icon: pickClock ? Broken.clock : Broken.calendar,
      onPressed: () async {
        if (pickClock) {
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

class _NumberValueField extends StatelessWidget {
  final SmartPlaylistRuleNumber rule;
  final TextEditingController controller;

  const _NumberValueField({
    required this.rule,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomTagTextField(
            controller: controller,
            hintText: rule.toHintText() ?? lang.value,
            labelText: lang.value,
            validator: rule.dataValidator,
          ),
        ),
        Padding(
          padding: const EdgeInsetsGeometry.only(left: 8.0),
          child: _NumberSliderWidget(
            key: ValueKey(rule.source),
            rule: rule,
            controller: controller,
          ),
        ),
      ],
    );
  }
}

/// a full date is typed in one field, other parts get a field each, and either can be "now" moved by an offset.
class _DateValueEditor extends StatefulWidget {
  final SmartPlaylistRuleDateTime rule;
  final TextEditingController textController;
  final SmartPlaylistDateValue? value;
  final void Function(SmartPlaylistDateValue? value) onChanged;

  const _DateValueEditor({
    super.key,
    required this.rule,
    required this.textController,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_DateValueEditor> createState() => _DateValueEditorState();
}

class _DateValueEditorState extends State<_DateValueEditor> {
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  final _weekdayController = TextEditingController();
  final _clockController = TextEditingController();
  final _offsetController = TextEditingController();
  int? _weekday;

  static const _kWeekdays = [
    DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, //
    DateTime.friday, DateTime.saturday, DateTime.sunday,
  ];

  @override
  void initState() {
    super.initState();
    final value = widget.value;
    if (value is SmartPlaylistDatePartsValue) {
      final weekday = value.weekday;
      final secondOfDay = value.secondOfDay;
      _yearController.text = value.year?.toString() ?? '';
      _monthController.text = value.month?.toString() ?? '';
      _dayController.text = value.day?.toString() ?? '';
      _weekday = weekday;
      if (weekday != null) _weekdayController.text = SmartPlaylistDatePartsValue.weekdayToText(weekday, short: true);
      if (secondOfDay != null) _clockController.text = SmartPlaylistDatePartsValue.clockToText(secondOfDay, hasSeconds: value.hasSeconds);
    } else if (value is SmartPlaylistNowDate) {
      _offsetController.text = value.offsetAmount.toString();
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _weekdayController.dispose();
    _clockController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  SmartPlaylistDatePartsValue _partsValueFromFields() {
    final clock = SmartPlaylistDatePartsValue.tryParseClock(_clockController.text);
    return SmartPlaylistDatePartsValue(
      year: int.tryParse(_yearController.text),
      month: int.tryParse(_monthController.text),
      day: int.tryParse(_dayController.text),
      weekday: _weekday,
      secondOfDay: clock?.secondOfDay,
      hasSeconds: clock?.hasSeconds ?? false,
    );
  }

  void _reportPartsValue() {
    widget.onChanged(_partsValueFromFields());
  }

  void _setWeekday(int weekday) {
    _weekday = weekday;
    _weekdayController.text = SmartPlaylistDatePartsValue.weekdayToText(weekday, short: true);
    _reportPartsValue();
  }

  void _setClock(DateTime clock) {
    final secondOfDay = SmartPlaylistDatePartsValue.secondOfDayOf(clock);
    _clockController.text = SmartPlaylistDatePartsValue.clockToText(secondOfDay, hasSeconds: false);
    _reportPartsValue();
  }

  void _setPickedDate(DateTime date) {
    final value = SmartPlaylistDate(date, .day);
    widget.textController.text = widget.rule.dataToText(value) ?? '';
  }

  void _toggleNow() {
    if (widget.value is SmartPlaylistNowDate) {
      final fixedValue = widget.rule.parts.isCalendarDate ? null : _partsValueFromFields();
      widget.onChanged(fixedValue);
      return;
    }
    _offsetController.text = '0';
    widget.onChanged(const SmartPlaylistNowDate(offsetAmount: 0, offsetUnit: .days));
  }

  void _setNowOffset({int? amount, SmartPlaylistRelativeUnit? unit}) {
    final value = widget.value;
    if (value is! SmartPlaylistNowDate) return;
    final nowValue = SmartPlaylistNowDate(
      offsetAmount: amount ?? value.offsetAmount,
      offsetUnit: unit ?? value.offsetUnit,
    );
    widget.onChanged(nowValue);
  }

  List<NamidaPopupItem> _weekdayItems() {
    return _kWeekdays
        .map(
          (weekday) => NamidaPopupItem(
            icon: Broken.calendar_tick,
            title: SmartPlaylistDatePartsValue.weekdayToText(weekday),
            selected: weekday == _weekday,
            onTap: () => _setWeekday(weekday),
          ),
        )
        .toFixedList();
  }

  List<NamidaPopupItem> _offsetUnitItems() {
    final value = widget.value;
    final selectedUnit = value is SmartPlaylistNowDate ? value.offsetUnit : null;
    return SmartPlaylistRelativeUnit.values
        .map(
          (unit) => NamidaPopupItem(
            icon: Broken.timer_1,
            title: unit.toText(),
            selected: unit == selectedUnit,
            onTap: () => _setNowOffset(unit: unit),
          ),
        )
        .toFixedList();
  }

  static String? Function(String? text) _intValidator(int min, int max) {
    return (text) {
      final value = int.tryParse(text ?? '');
      if (value == null) return lang.emptyValue;
      if (value < min || value > max) return '$min - $max';
      return null;
    };
  }

  static String? _requiredValidator(String? text) {
    if (text == null || text.isEmpty) return lang.emptyValue;
    return null;
  }

  static String? _clockValidator(String? text) {
    final clock = SmartPlaylistDatePartsValue.tryParseClock(text ?? '');
    if (clock == null) return lang.nameContainsBadCharacter;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final rule = widget.rule;
    final parts = rule.parts;
    final nowToggle = NamidaToggleCard(
      icon: Broken.timer_1,
      title: lang.now,
      active: value is SmartPlaylistNowDate,
      padding: const EdgeInsets.all(12.0),
      onTap: _toggleNow,
    );

    final rows = <Widget>[];
    if (value is SmartPlaylistNowDate) {
      rows.add(
        CustomTagTextField(
          controller: _offsetController,
          hintText: '-1, 0, 2...',
          labelText: '${lang.now} ±',
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          validator: _intValidator(-9999, 9999),
          onChanged: (text) {
            final amount = int.tryParse(text);
            if (amount != null) _setNowOffset(amount: amount);
          },
          suffixIcon: NamidaPopupWrapper(
            childrenDefault: _offsetUnitItems,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisSize: .min,
                children: [
                  NamidaText(
                    value.offsetUnit.toText(),
                    style: NText.small,
                  ),
                  const SizedBox(width: 4.0),
                  const Icon(
                    Broken.arrow_down_2,
                    size: 14.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (parts.isCalendarDate) {
      rows.add(
        CustomTagTextField(
          controller: widget.textController,
          hintText: rule.toHintText() ?? lang.value,
          labelText: lang.value,
          validator: rule.dataValidator,
          suffixIcon: _CalendarPickerIconWidget(
            pickClock: false,
            onSelect: _setPickedDate,
          ),
        ),
      );
    } else {
      final fields = [
        if (parts.has(.year))
          CustomTagTextField(
            controller: _yearController,
            hintText: 'YYYY',
            labelText: lang.year,
            showChangedMark: false,
            isNumeric: true,
            validator: _intValidator(1, 9999),
            onChanged: (_) => _reportPartsValue(),
          ),
        if (parts.has(.month))
          CustomTagTextField(
            controller: _monthController,
            hintText: '1-12',
            labelText: lang.month,
            showChangedMark: false,
            isNumeric: true,
            validator: _intValidator(1, 12),
            onChanged: (_) => _reportPartsValue(),
          ),
        if (parts.has(.day))
          CustomTagTextField(
            controller: _dayController,
            hintText: '1-31',
            labelText: lang.day,
            showChangedMark: false,
            isNumeric: true,
            validator: _intValidator(1, 31),
            onChanged: (_) => _reportPartsValue(),
          ),
        if (parts.has(.weekday))
          NamidaPopupWrapper(
            childrenDefault: _weekdayItems,
            childBuilder: (openMenu) => CustomTagTextField(
              controller: _weekdayController,
              hintText: '',
              labelText: lang.weekday,
              showChangedMark: false,
              readOnly: true,
              validator: _requiredValidator,
              onTap: openMenu,
              suffixIcon: const Icon(
                Broken.arrow_down_2,
                size: 16.0,
              ),
            ),
          ),
      ];
      // -- two per row, more get too narrow
      for (int i = 0; i < fields.length; i += 2) {
        final hasPair = i + 1 < fields.length;
        rows.add(
          Row(
            children: [
              Expanded(child: fields[i]),
              if (hasPair) ...[
                const SizedBox(width: 8.0),
                Expanded(child: fields[i + 1]),
              ],
            ],
          ),
        );
      }
      if (parts.has(.time)) {
        rows.add(
          CustomTagTextField(
            controller: _clockController,
            hintText: 'HH:mm',
            labelText: lang.clock,
            showChangedMark: false,
            validator: _clockValidator,
            onChanged: (_) => _reportPartsValue(),
            suffixIcon: _CalendarPickerIconWidget(
              pickClock: true,
              onSelect: _setClock,
            ),
          ),
        );
      }
    }

    return _ValueBox(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: rows
                  .addSeparators(
                    separator: const SizedBox(height: 8.0),
                  )
                  .toFixedList(),
            ),
          ),
          const SizedBox(width: 8.0),
          nowToggle,
        ],
      ),
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
          isSelected: (unit) => unit == widget.relativeDuration.unit,
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
  final _suggestionsProvider = TextSuggestionsProvider();

  Set<String>? _buildAlreadyAddedLiterals() {
    final tokens = widget.tokens;
    if (tokens == null) return null;
    Set<String>? literals;
    for (final token in tokens) {
      if (token is SmartPlaylistTextDataTokenLiteral) (literals ??= <String>{}).add(token.text.toLowerCase());
    }
    return literals;
  }

  void _setTokens(List<SmartPlaylistTextDataToken> tokens) {
    widget.onChanged(tokens.isEmpty ? null : tokens);
  }

  void _addLiteralFromField() {
    final text = widget.controller.text;
    if (text.isEmpty) return;
    _setTokens([...?widget.tokens, SmartPlaylistTextDataTokenLiteral(text)]);
    widget.controller.clear();
  }

  void _addLiteralFromSuggestion(String text) {
    widget.controller.text = text;
    _addLiteralFromField();
  }

  void _removeAt(int index) {
    final tokens = [...?widget.tokens];
    tokens.removeAt(index);
    _setTokens(tokens);
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
        actions: const [CancelButton()],
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
                        final tokens = [...?widget.tokens];
                        if (replaceIndex != null) {
                          tokens[replaceIndex] = tokenSource;
                        } else {
                          tokens.add(tokenSource);
                        }
                        _setTokens(tokens);

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
    final tokens = widget.tokens ?? const <SmartPlaylistTextDataToken>[];
    final filter = widget.rule.filter;
    final isRegex = filter.isRegex();

    final suggestionsSource = widget.rule.source.toSuggestionsSource();

    return _ValueBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tokens.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
              child: NamidaText(
                lang.emptyValue,
                style: NText.small,
              ),
            )
          else
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: [
                ...tokens.mapIndexed(
                  (token, index) {
                    final (IconData? icon, String label, NColors bgColor, VoidCallback onTap) = switch (token) {
                      SmartPlaylistTextDataTokenSource() => (
                        token.source.toIcon(),
                        token.displayText(),
                        const NColors(.secondaryContainer, opacity: 0.4),
                        () => _pickSource(replaceIndex: index),
                      ),
                      SmartPlaylistTextDataTokenLiteral() => (
                        null,
                        '"${token.text}"',
                        NColors.card,
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
                            child: NamidaText(
                              label,
                              style: NText.small,
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
                final values = _suggestionsProvider.valuesFor(suggestionsSource);
                final results = TextSuggestionsMatcher.filter(
                  values: values,
                  query: value.text,
                  excludeLowercased: _buildAlreadyAddedLiterals(),
                );
                if (results.isEmpty) return const SizedBox();
                return TextSuggestionsChipsRow(
                  padding: const EdgeInsets.only(top: 8.0),
                  values: values,
                  indices: results,
                  onTap: _addLiteralFromSuggestion,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _ValueBox({
    this.padding = const EdgeInsets.all(8.0),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NDecoratedBox(
      decoration: (colors) => BoxDecoration(
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        border: Border.all(color: colors.divider.withOpacityExt(0.4)),
      ),
      child: Padding(
        padding: padding,
        child: child,
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
    final limit = this.limit;
    return NamidaInkWell(
      onTap: _openLimitDialog,
      borderRadius: 8.0,
      bgColor: NColors.card,
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
                NamidaText(
                  lang.limit,
                  style: NText.medium,
                ),
                NamidaText(
                  limit?.toText() ?? lang.none,
                  style: NText.small,
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
  static const _maxScopeAmount = 99;
  static final _fromScopes = SmartPlaylistNumberScope.values.where((e) => e != SmartPlaylistNumberScope.track).toFixedList();

  final _formKey = GlobalKey<FormState>();
  late SmartPlaylistLimit _limit = widget.initialLimit;
  late SmartPlaylistNumberScope? _fromScope = widget.initialLimit.fromScope?.scope;
  late final _scopeAmountController = TextEditingController(text: '${widget.initialLimit.fromScope?.amount ?? 1}');
  late final _scopeSyncer = _TextSliderSyncController(
    textController: _scopeAmountController,
    textToSlider: (text) => int.tryParse(text)?.clamp(1, _maxScopeAmount) ?? 1,
    sliderToDisplayText: (v) => '$v',
    sliderToRawText: (v) => '$v',
    onChanged: (_) {},
  );
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
    _scopeSyncer.dispose();
    _scopeAmountController.dispose();
    super.dispose();
  }

  List<NamidaPopupItem> _unitItems() => SmartPlaylistLimitUnit.values
      .map(
        (unit) => NamidaPopupItem(
          icon: unit.toIcon(),
          title: unit.toText(),
          selected: unit == _limit.unit,
          onTap: () => setState(() => _limit = _limit.copyWith(unit: unit)),
        ),
      )
      .toFixedList();

  List<NamidaPopupItem> _scopeItems() => [
    NamidaPopupItem(
      icon: Broken.close_circle,
      title: lang.none,
      selected: _fromScope == null,
      onTap: () => setState(() => _fromScope = null),
    ),
    ..._fromScopes.map(
      (scope) => NamidaPopupItem(
        icon: scope.toIcon(),
        title: scope.toPluralText(),
        selected: scope == _fromScope,
        onTap: () => setState(() => _fromScope = scope),
      ),
    ),
  ];

  void _pickSorts() {
    NamidaOnTaps.inst.onTracksSortIconTap(
      currentSorting: _limit.sorting,
      onChanged: (sorting) {
        setState(() => _limit = _limit.copyWith(sorting: sorting));
      },
    );
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    final amount = int.parse(_amountController.text);
    final fromScope = _fromScope;
    SmartPlaylistLimitScope? limitScope;
    if (fromScope != null) {
      final scopeAmount = int.parse(_scopeAmountController.text);
      limitScope = SmartPlaylistLimitScope(scope: fromScope, amount: scopeAmount);
    }
    final limit = SmartPlaylistLimit(
      amount: amount,
      unit: _limit.unit,
      sorting: _limit.sorting,
      fromScope: limitScope,
    );
    widget.onConfirm(limit);
    NamidaNavigator.inst.closeDialog();
  }

  String? _validateAmount(String? value) {
    final amount = value == null ? null : int.tryParse(value);
    if (amount == null || amount <= 0) return '1+';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sortText = _limit.sorting.firstType?.toText() ?? lang.auto;
    final fromScope = _fromScope;
    final Widget scopeWidget = fromScope == null
        ? NamidaPopupWrapper(
            childrenDefault: _scopeItems,
            childBuilder: (openMenu) => CustomListTile(
              icon: Broken.category,
              title: lang.maximum,
              onTap: openMenu,
              trailing: Row(
                mainAxisSize: .min,
                children: [
                  NamidaText(
                    lang.none,
                    style: NText.medium,
                  ),
                  const SizedBox(width: 4.0),
                  const Icon(
                    Broken.arrow_down_2,
                    size: 18.0,
                  ),
                ],
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: CustomTagTextField(
                    controller: _scopeAmountController,
                    hintText: '1, 2, 3...',
                    labelText: lang.maximum,
                    isNumeric: true,
                    validator: _validateAmount,
                    suffixIcon: _PopupSuffix(
                      text: fromScope.toPluralText(),
                      items: _scopeItems,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                _SyncedWheelSlider(
                  syncer: _scopeSyncer,
                  min: 1,
                  max: _maxScopeAmount,
                  stepper: 1,
                ),
              ],
            ),
          );
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
                    labelText: lang.value,
                    isNumeric: true,
                    validator: _validateAmount,
                    suffixIcon: _PopupSuffix(
                      text: _limit.unit.toText(),
                      items: _unitItems,
                    ),
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
            CustomListTile(
              icon: Broken.sort,
              title: lang.selectedBy,
              onTap: _pickSorts,
              trailing: Row(
                mainAxisSize: .min,
                children: [
                  NamidaText(
                    sortText,
                    style: NText.medium,
                  ),
                  const SizedBox(width: 4.0),
                  Icon(
                    _limit.sorting.reverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                    size: 18.0,
                  ),
                ],
              ),
            ),
            scopeWidget,
          ],
        ),
      ),
    );
  }
}

class _PopupSuffix extends StatelessWidget {
  final String text;
  final List<NamidaPopupItem> Function() items;

  const _PopupSuffix({
    required this.text,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisSize: .min,
          children: [
            NamidaText(
              text,
              style: NText.small,
            ),
            const SizedBox(width: 4.0),
            const Icon(
              Broken.arrow_down_2,
              size: 14.0,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemedCoolBox extends StatelessWidget {
  final NColorRole colorRole;
  final bool extraVPadding;
  final double hPadding;
  final BorderRadius? borderRadius;
  final Widget child;

  const _ThemedCoolBox({
    required this.colorRole,
    this.extraVPadding = false,
    this.hPadding = 12.0,
    this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    return NamidaCoolBox(
      colorScheme: colors.get(colorRole),
      extraVPadding: extraVPadding,
      hPadding: hPadding,
      borderRadius: borderRadius,
      builder: (_) => child,
    );
  }
}
