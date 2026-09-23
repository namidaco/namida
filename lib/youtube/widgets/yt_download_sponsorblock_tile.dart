import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/sponsorblock.dart';

/// Toggles sponsor segments removal for a download & lets the categories be picked for this download only,
/// [categoriesOverride] stays null as long as the global pick is used.
class YTDownloadSponsorBlockTile extends StatelessWidget {
  final Rxn<List<String>> categoriesOverride;

  const YTDownloadSponsorBlockTile({super.key, required this.categoriesOverride});

  static final _removableCategories = SponsorBlockCategory.values.where((category) => category.canBeRemovedFromDownloads).toList();

  void _showCategoriesPicker(BuildContext context) {
    final selected = <String>{...categoriesOverride.value ?? settings.youtube.sponsorBlockSettings.value.downloadsRemovedCategoriesNames}.obs;
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () => selected.close(),
      dialog: CustomBlurryDialog(
        title: lang.removeSponsorSegmentsFromDownloads,
        normalTitleStyle: true,
        actions: [
          NamidaIconButton(
            tooltip: () => lang.restoreDefaults,
            icon: Broken.refresh,
            onPressed: () {
              categoriesOverride.value = null;
              NamidaNavigator.inst.closeDialog();
            },
          ),
          const DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _removableCategories
              .map(
                (category) => Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: ObxO(
                    rx: selected,
                    builder: (context, selectedNames) => ListTileWithCheckMark(
                      leading: _CategoryColorDot(
                        color: settings.youtube.sponsorBlockSettings.value.configs[category]?.color ?? category.defaultConfig.color,
                      ),
                      title: category.toText(),
                      active: selectedNames.contains(category.name),
                      onTap: () {
                        selectedNames.contains(category.name) ? selectedNames.remove(category.name) : selectedNames.add(category.name);
                        selected.refresh();
                        categoriesOverride.value = selectedNames.toList();
                      },
                    ),
                  ),
                ),
              )
              .toFixedList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: categoriesOverride,
      builder: (context, override) => Obx(
        (context) {
          final sponsorBlockSettings = settings.youtube.sponsorBlockSettings.valueR;
          final enabled = sponsorBlockSettings.removeSegmentsFromDownloads;
          final categoriesNames = override ?? sponsorBlockSettings.downloadsRemovedCategoriesNames;
          return CustomListTile(
            icon: Broken.scissor,
            title: lang.removeSponsorSegmentsFromDownloads,
            subtitle: categoriesNames.isEmpty ? lang.none : categoriesNames.map((name) => name.sponsorCategoryToText()).join(', '),
            onTap: () => settings.youtube.save(
              sponsorBlockSettings: sponsorBlockSettings.copyWith(removeSegmentsFromDownloads: !enabled),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamidaIconButton(
                  tooltip: () => lang.configure,
                  icon: Broken.edit_2,
                  iconSize: 20.0,
                  onPressed: () => _showCategoriesPicker(context),
                ),
                const SizedBox(
                  width: 4.0,
                ),
                CustomSwitch(
                  active: enabled,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryColorDot extends StatelessWidget {
  final Color color;

  const _CategoryColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24.0,
      height: 24.0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
