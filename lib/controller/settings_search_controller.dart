import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/backup_restore_settings.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';

extension _SettSearcherUtils on SettingSubpageEnum {
  CustomCollapsedListTile? toSettingSubPageDetails({Enum? initialItem}) {
    switch (this) {
      case SettingSubpageEnum.theme:
        return CustomCollapsedListTile(
          title: lang.THEME_SETTINGS,
          subtitle: lang.THEME_SETTINGS_SUBTITLE,
          icon: Broken.brush_2,
          page: ThemeSetting(initialItem: initialItem),
        );
      case SettingSubpageEnum.indexer:
        return CustomCollapsedListTile(
          title: lang.INDEXER,
          subtitle: lang.INDEXER_SUBTITLE,
          icon: Broken.component,
          page: IndexerSettings(initialItem: initialItem),
        );

      case SettingSubpageEnum.playback:
        return CustomCollapsedListTile(
          title: lang.PLAYBACK_SETTING,
          subtitle: lang.PLAYBACK_SETTING_SUBTITLE,
          icon: Broken.play_cricle,
          page: PlaybackSettings(initialItem: initialItem),
        );
      case SettingSubpageEnum.customization:
        return CustomCollapsedListTile(
          title: lang.CUSTOMIZATIONS,
          subtitle: lang.CUSTOMIZATIONS_SUBTITLE,
          icon: Broken.brush_1,
          page: CustomizationSettings(initialItem: initialItem),
        );

      case SettingSubpageEnum.youtube:
        return CustomCollapsedListTile(
          title: lang.YOUTUBE,
          subtitle: lang.YOUTUBE_SETTINGS_SUBTITLE,
          icon: Broken.video,
          page: YoutubeSettings(initialItem: initialItem),
        );

      case SettingSubpageEnum.extra:
        return CustomCollapsedListTile(
          title: lang.EXTRAS,
          subtitle: lang.EXTRAS_SUBTITLE,
          icon: Broken.command_square,
          page: ExtrasSettings(initialItem: initialItem),
        );
      case SettingSubpageEnum.backupRestore:
        return CustomCollapsedListTile(
          title: lang.BACKUP_AND_RESTORE,
          subtitle: lang.BACKUP_AND_RESTORE_SUBTITLE,
          icon: Broken.refresh_circle,
          page: BackupAndRestore(initialItem: initialItem),
        );

      case SettingSubpageEnum.advanced:
        return CustomCollapsedListTile(
          title: lang.ADVANCED_SETTINGS,
          subtitle: lang.ADVANCED_SETTINGS_SUBTITLE,
          icon: Broken.hierarchy_3,
          page: AdvancedSettings(initialItem: initialItem),
        );
      default:
        return null;
    }
  }
}

class SettingSearchResultItem {
  final SettingSubpageEnum? page;
  final Enum key;
  final List<String> titles;

  const SettingSearchResultItem({
    required this.page,
    required this.key,
    required this.titles,
  });
}

class SettingsSearchController {
  static final SettingsSearchController inst = SettingsSearchController._internal();
  SettingsSearchController._internal();

  final _map = <SettingSubpageEnum, Map<int, GlobalKey>>{};
  var _allWidgets = <(SettingSubpageProvider, Map<Enum, List<String>>)>[];
  final searchResults = <SettingSubpageEnum, List<SettingSearchResultItem>>{}.obs;
  final subpagesDetails = <SettingSubpageEnum, CustomCollapsedListTile?>{};

  bool get canShowSearch => _canShowSearch.value;
  final _canShowSearch = false.obs;

  void closeSearch() {
    _allWidgets.clear();
    searchResults.clear();
    _canShowSearch.value = false;
  }

  GlobalKey getSettingWidgetGlobalKey(SettingSubpageEnum settingPage, Enum key) {
    final keyIndex = key.index;
    final c = SettingsSearchController.inst;
    final r = settingPage;
    c._map[r] ??= {};
    c._map[r]![keyIndex] ??= GlobalKey();
    return c._map[r]![keyIndex]!;
  }

  void onSearchTap({required bool isOpen}) {
    if (isOpen) {
      const theme = ThemeSetting();
      const indexer = IndexerSettings();
      const playback = PlaybackSettings();
      const customization = CustomizationSettings();
      const youtube = YoutubeSettings();
      const extras = ExtrasSettings();
      const backupAndRestore = BackupAndRestore();
      const advanced = AdvancedSettings();
      _allWidgets = [
        (theme, theme.lookupMap),
        (indexer, indexer.lookupMap),
        (playback, playback.lookupMap),
        (customization, customization.lookupMap),
        (youtube, youtube.lookupMap),
        (extras, extras.lookupMap),
        (backupAndRestore, backupAndRestore.lookupMap),
        (advanced, advanced.lookupMap),
      ];
      for (final p in _allWidgets) {
        subpagesDetails[p.$1.settingPage] = p.$1.settingPage.toSettingSubPageDetails();
      }
      _canShowSearch.value = true;
    } else {
      closeSearch();
    }
  }

  void onSearchChanged(String val) {
    final res = <SettingSubpageEnum, List<SettingSearchResultItem>>{};
    _allWidgets.loop((widget, index) {
      for (final e in widget.$2.entries) {
        final match = e.value.any((element) => element.cleanUpForComparison.contains(val.cleanUpForComparison));
        if (match) {
          final p = widget.$1.settingPage;
          res.addForce(
            p,
            SettingSearchResultItem(
              page: p,
              key: e.key,
              titles: e.value,
            ),
          );
        }
      }
    });
    searchResults.value = res;
  }

  Future<void> onResultTap({
    required SettingSubpageEnum? settingPage,
    required Enum key,
    required BuildContext context,
  }) async {
    onSearchTap(isOpen: false);

    final details = subpagesDetails[settingPage];
    final page = settingPage?.toSettingSubPageDetails(initialItem: key)?.page;
    if (NamidaNavigator.inst.currentRoute?.route == RouteType.SETTINGS_subpage) {
      // -- navigate back if inside subpage.
      // -- we can skip and just jump, but we
      // -- need the blink animation & bgColor to update.
      await NamidaNavigator.inst.popPage(waitForAnimation: true);
    }
    if (page != null) {
      NamidaNavigator.inst.navigateTo(
        SettingsSubPage(
          title: details?.title ?? '',
          child: page,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final c = _map[settingPage]?[key.index]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.3);
    });
  }
}
