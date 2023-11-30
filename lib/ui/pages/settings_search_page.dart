import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SettingsSearchPage extends StatelessWidget {
  const SettingsSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Obx(
          () {
            final keys = SettingsSearchController.inst.searchResults.keys.toList();
            return CustomScrollView(
              slivers: [
                ...keys.map(
                  (key) {
                    final res = SettingsSearchController.inst.searchResults[key] ?? [];
                    return SliverList.builder(
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
                                  style: context.textTheme.displayLarge,
                                ),
                              ],
                            ),
                          );
                        }
                        final index = indexPre - 1;
                        final item = res[index];

                        final title = item.titles.firstOrNull ?? '';
                        final subtitle = item.titles.length >= 2 ? item.titles[1] : null;

                        return CustomListTile(
                          borderR: 16.0,
                          visualDensity: VisualDensity.compact,
                          title: "${index + 1}. $title",
                          subtitle: subtitle,
                          onTap: () {
                            SettingsSearchController.inst.onResultTap(
                              settingPage: item.page,
                              key: item.key,
                              context: context,
                            );
                          },
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
