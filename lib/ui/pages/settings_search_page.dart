import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SettingsSearchPage extends StatelessWidget {
  const SettingsSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Obx(
          (context) {
            final keys = SettingsSearchController.inst.searchResults.valueR.keys;
            return SmoothCustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: _ModifiedOnlyChip(),
                ),
                ...keys.map(
                  (key) {
                    final res = SettingsSearchController.inst.searchResults[key] ?? [];
                    return SuperSliverList.builder(
                      itemCount: res.length + 1,
                      itemBuilder: (context, indexPre) {
                        if (indexPre == 0) {
                          final details = SettingsSearchController.inst.subpagesDetails[res[0].page];
                          if (details == null) return const SizedBox();
                          return NamidaInkWell(
                            borderRadius: 6.0,
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                            bgColor: NColors.card,
                            child: Row(
                              children: [
                                Icon(details.icon),
                                const SizedBox(width: 6.0),
                                NamidaText(
                                  details.title(),
                                  style: NText.large,
                                ),
                              ],
                            ),
                          );
                        }
                        final index = indexPre - 1;
                        final item = res[index];

                        final availability = item.availability;
                        final isNotAvailable = availability?.resolve() == false;

                        final title = item.titles.firstOrNull ?? '';
                        final subtitleIndex = item.matchedTitleIndex.withMinimum(1);
                        final parentTitles = item.parentTitles;
                        final subtitleParts = [
                          if (parentTitles.isNotEmpty) parentTitles.join(' › '),
                          if (item.titles.length > subtitleIndex) item.titles[subtitleIndex],
                          if (isNotAvailable) '${lang.notAvailableForYourDevice} (${availability?.text})',
                        ];
                        final subtitle = subtitleParts.isNotEmpty ? subtitleParts.join('\n') : null;
                        final trailing = isNotAvailable
                            ? null
                            : _ResultActions(
                                entry: item.key,
                              );

                        Widget tileWidget = CustomListTile(
                          enabled: true,
                          borderR: 16.0,
                          leading: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 24.0),
                            child: isNotAvailable
                                ? const Icon(
                                    Broken.slash,
                                    size: 22.0,
                                  )
                                : NDecoratedBox(
                                    decoration: (colors) => BoxDecoration(
                                      color: colors.card,
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                                      child: NamidaText(
                                        '${index + 1}',
                                        style: NText.small,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                          ),
                          title: title,
                          subtitle: subtitle,
                          trailing: trailing,
                          onTap: () {
                            SettingsSearchController.inst.onResultTap(
                              settingPage: item.page,
                              key: item.key,
                              context: context,
                            );
                          },
                        );

                        if (isNotAvailable) {
                          tileWidget = IgnorePointer(
                            child: Opacity(
                              opacity: 0.7,
                              child: tileWidget,
                            ),
                          );
                        }

                        return KeyedSubtree(
                          key: ValueKey(item.key),
                          child: tileWidget,
                        );
                      },
                    );
                  },
                ),
                kBottomPaddingWidgetSliver,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModifiedOnlyChip extends StatelessWidget {
  const _ModifiedOnlyChip();

  @override
  Widget build(BuildContext context) {
    final textStyle = NText.medium.of(context);
    final controller = SettingsSearchController.inst;
    return Obx(
      (context) {
        final isActive = controller.isModifiedOnly.valueR;
        final count = controller.modifiedCount.valueR;
        if (count == 0 && !isActive) return const SizedBox();
        final secondaryColor = NColorsData.targetOf(context).secondary;
        final style = textStyle.copyWith(color: secondaryColor.withOpacityExt(isActive ? 0.9 : 0.6));
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: NamidaInkWell(
            animationDurationMS: 200,
            bgColor: NColors.fixed(secondaryColor.withOpacityExt(isActive ? 0.18 : 0.0)),
            borderRadius: 8.0,
            onTap: controller.toggleModifiedOnly,
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: secondaryColor.withOpacityExt(isActive ? 0.7 : 0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              '${lang.changed} ($count)',
              style: style,
            ),
          ),
        );
      },
    );
  }
}

class _ResultActions extends StatelessWidget {
  final SettingEntry entry;

  const _ResultActions({required this.entry});

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final toggle = entry is SettingToggle
        ? _ResultToggle(
            entry: entry,
          )
        : null;
    return ObxO(
      rx: SettingsSearchController.inst.isModifiedOnly,
      builder: (context, isModifiedOnly) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isModifiedOnly)
            NamidaIconButton(
              icon: Broken.refresh,
              iconSize: 20.0,
              tooltip: () => lang.restoreDefaults,
              onPressed: () => SettingsSearchController.inst.resetToDefault(entry),
            ),
          ?toggle,
        ],
      ),
    );
  }
}

class _ResultToggle extends StatelessWidget {
  final SettingToggle entry;

  const _ResultToggle({required this.entry});

  @override
  Widget build(BuildContext context) {
    return TapDetector(
      onTap: () => SettingsSearchController.inst.toggle(entry),
      child: ObxO(
        rx: entry.setting,
        builder: (context, isEnabled) => CustomSwitch(
          active: isEnabled,
        ),
      ),
    );
  }
}
