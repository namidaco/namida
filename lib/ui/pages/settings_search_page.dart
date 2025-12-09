import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SettingsSearchPage extends StatelessWidget {
  const SettingsSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return BackgroundWrapper(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Obx(
          (context) {
            final keys = SettingsSearchController.inst.searchResults.keys.toList();
            return CustomScrollView(
              slivers: [
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
                            bgColor: context.theme.cardColor,
                            child: Row(
                              children: [
                                Icon(details.icon),
                                const SizedBox(width: 6.0),
                                Text(
                                  details.title,
                                  style: textTheme.displayLarge,
                                ),
                              ],
                            ),
                          );
                        }
                        final index = indexPre - 1;
                        final item = res[index];

                        final availability = (item.key as SettingKeysBase).availability;
                        final isNotAvailable = availability?.resolve() == false;

                        final title = item.titles.firstOrNull ?? '';
                        final subtitleParts = [
                          if (item.titles.length >= 2) item.titles[1],
                          if (isNotAvailable) '${lang.NOT_AVAILABLE_FOR_YOUR_DEVICE} (${availability?.text})',
                        ];
                        final subtitle = subtitleParts.isNotEmpty ? subtitleParts.join('\n') : null;

                        Widget tileWidget = CustomListTile(
                          enabled: true,
                          borderR: 16.0,
                          visualDensity: VisualDensity.compact,
                          leading: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 24.0),
                            child: isNotAvailable
                                ? const Icon(
                                    Broken.slash,
                                    size: 22.0,
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: context.theme.cardColor,
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                                      child: Text(
                                        '${index + 1}',
                                        style: textTheme.displaySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                          ),
                          title: title,
                          subtitle: subtitle,
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

                        return tileWidget;
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
