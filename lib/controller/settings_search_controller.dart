import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
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
  CustomCollapsedListTile? toSettingSubPageDetails({SettingEntry? initialItem}) {
    switch (this) {
      case SettingSubpageEnum.theme:
        return CustomCollapsedListTile(
          title: () => lang.themeSettings,
          subtitle: lang.themeSettingsSubtitle,
          icon: Broken.brush_2,
          page: () => ThemeSetting(initialItem: initialItem),
        );
      case SettingSubpageEnum.indexer:
        return CustomCollapsedListTile(
          title: () => lang.indexer,
          subtitle: lang.indexerSubtitle,
          icon: Broken.component,
          page: () => IndexerSettings(initialItem: initialItem),
        );

      case SettingSubpageEnum.playback:
        return CustomCollapsedListTile(
          title: () => lang.playbackSetting,
          subtitle: lang.playbackSettingSubtitle,
          icon: Broken.play_cricle,
          page: () => PlaybackSettings(initialItem: initialItem),
        );
      case SettingSubpageEnum.customization:
        return CustomCollapsedListTile(
          title: () => lang.customizations,
          subtitle: lang.customizationsSubtitle,
          icon: Broken.brush_1,
          page: () => CustomizationSettings(initialItem: initialItem),
        );

      case SettingSubpageEnum.youtube:
        return CustomCollapsedListTile(
          title: () => lang.youtube,
          subtitle: lang.youtubeSettingsSubtitle,
          icon: Broken.video,
          page: () => YoutubeSettings(initialItem: initialItem),
        );

      case SettingSubpageEnum.extra:
        return CustomCollapsedListTile(
          title: () => lang.extras,
          subtitle: lang.extrasSubtitle,
          icon: Broken.command_square,
          page: () => ExtrasSettings(initialItem: initialItem),
        );
      case SettingSubpageEnum.backupRestore:
        return CustomCollapsedListTile(
          title: () => lang.backupAndRestore,
          subtitle: lang.backupAndRestoreSubtitle,
          icon: Broken.refresh_circle,
          page: () => BackupAndRestore(initialItem: initialItem),
        );

      case SettingSubpageEnum.advanced:
        return CustomCollapsedListTile(
          title: () => lang.advancedSettings,
          subtitle: lang.advancedSettingsSubtitle,
          icon: Broken.hierarchy_3,
          page: () => AdvancedSettings(initialItem: initialItem),
        );
    }
  }
}

class SettingSearchResultItem {
  final SettingSubpageEnum? page;
  final SettingEntry key;
  final List<String> titles;
  final int matchedTitleIndex;

  final List<String> parentTitles;

  /// its own, or the nearest parent's.
  final NamidaFeaturesAvailablityBase? availability;

  const SettingSearchResultItem({
    required this.page,
    required this.key,
    required this.titles,
    required this.matchedTitleIndex,
    required this.parentTitles,
    required this.availability,
  });
}

class SettingsSearchController {
  static final SettingsSearchController inst = SettingsSearchController._internal();
  SettingsSearchController._internal();

  final _targetKeys = <SettingEntry, GlobalKey>{};

  GlobalKey getTargetKey(SettingEntry key) => _targetKeys[key] ??= GlobalKey();

  final _searchIndex = <_SettingSearchIndexItem>[];
  final searchResults = <SettingSubpageEnum, List<SettingSearchResultItem>>{}.obs;
  final subpagesDetails = <SettingSubpageEnum, CustomCollapsedListTile?>{};

  RxBaseCore<bool> get canShowSearch => _canShowSearch;
  final _canShowSearch = false.obs;

  RxBaseCore<bool> get isModifiedOnly => _isModifiedOnly;
  final _isModifiedOnly = false.obs;

  RxBaseCore<int> get modifiedCount => _modifiedCount;
  final _modifiedCount = 0.obs;

  String _query = '';

  void closeSearch() {
    _searchIndex.clear();
    subpagesDetails.clear();
    searchResults.clear();
    _query = '';
    _isModifiedOnly.value = false;
    _canShowSearch.value = false;
  }

  void onSearchTap({required bool isOpen}) {
    if (isOpen) {
      _searchIndex.clear();
      final settingsWidgets = [
        ThemeSetting(),
        IndexerSettings(),
        PlaybackSettings(),
        CustomizationSettings(),
        YoutubeSettings(),
        ExtrasSettings(),
        BackupAndRestore(),
        AdvancedSettings(),
      ];
      for (final p in settingsWidgets) {
        subpagesDetails[p.settingPage] = p.settingPage.toSettingSubPageDetails();
        final page = p.settingPage;
        _addEntriesToIndex(page, p.headerEntries, const [], null);
        for (final section in p.sections) {
          _addEntriesToIndex(page, section, const [], null);
        }
      }
      _refreshModifiedCount();
      _canShowSearch.value = true;
    } else {
      closeSearch();
    }
  }

  void _addToIndex(SettingSubpageEnum page, SettingEntry key, List<String> titles, List<String> parentTitles, NamidaFeaturesAvailablityBase? availability) {
    _searchIndex.add((
      page: page,
      key: key,
      titles: titles,
      titlesCleaned: titles.map((title) => title.cleanUpForComparison).toFixedList(),
      parentTitles: parentTitles,
      availability: availability,
    ));
  }

  void _addEntriesToIndex(SettingSubpageEnum page, List<SettingEntry> entries, List<String> parentTitles, NamidaFeaturesAvailablityBase? parentAvailability) {
    for (final entry in entries) {
      final isVisible = entry.visibleWhen?.call();
      if (isVisible == false) continue;
      final titles = entry.getSearchTitles();
      final availability = entry.availability ?? parentAvailability;
      _addToIndex(page, entry, titles, parentTitles, availability);
      final children = entry.children;
      if (children.isEmpty) continue;
      final childrenParentTitles = [...parentTitles, titles.first];
      _addEntriesToIndex(page, children, childrenParentTitles, availability);
    }
  }

  void onSearchChanged(String val) {
    _query = val;
    _refreshResults();
  }

  void toggleModifiedOnly() {
    _isModifiedOnly.value = !_isModifiedOnly.value;
    _refreshResults();
  }

  void toggle(SettingToggle entry) {
    entry.toggle();
    _refreshModifiedCount();
  }

  void resetToDefault(SettingEntry entry) {
    entry.resetToDefault();
    _refreshModifiedCount();
    _refreshResults();
  }

  void _refreshModifiedCount() {
    _modifiedCount.value = _searchIndex.where((item) => item.key.isModified()).length;
  }

  void _refreshResults() {
    final isModifiedOnly = _isModifiedOnly.value;
    final query = _query;
    final res = <SettingSubpageEnum, List<SettingSearchResultItem>>{};
    if (query.isEmpty && !isModifiedOnly) {
      searchResults.value = res;
      return;
    }
    final valCleaned = query.cleanUpForComparison;
    for (final entry in _searchIndex) {
      if (isModifiedOnly && !entry.key.isModified()) continue;
      final titlesCleaned = entry.titlesCleaned;
      for (int i = 0; i < titlesCleaned.length; i++) {
        if (titlesCleaned[i].contains(valCleaned)) {
          res.addForce(
            entry.page,
            SettingSearchResultItem(
              page: entry.page,
              key: entry.key,
              titles: entry.titles,
              matchedTitleIndex: i,
              parentTitles: entry.parentTitles,
              availability: entry.availability,
            ),
          );
          break;
        }
      }
    }
    searchResults.value = res;
  }

  Future<void> onResultTap({
    required SettingSubpageEnum? settingPage,
    required SettingEntry key,
    required BuildContext context,
  }) async {
    onSearchTap(isOpen: false);

    if (NamidaNavigator.inst.currentRoute?.route == RouteType.SETTINGS_subpage) {
      // -- navigate back if inside subpage.
      // -- we can skip and just jump, but we
      // -- need the blink animation & bgColor to update.
      await NamidaNavigator.inst.popPage(waitForAnimation: true);
    }
    if (settingPage != null) openSubpage(settingPage, initialItem: key);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final c = _targetKeys[key]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.3);
    });
  }

  void openSubpage(SettingSubpageEnum settingPage, {SettingEntry? initialItem}) {
    final details = settingPage.toSettingSubPageDetails(initialItem: initialItem);
    if (details == null) return;
    final page = details.page;
    if (page == null) return;
    SettingsSubPage(
      title: details.title,
      child: page(),
    ).navigate();
  }
}

typedef _SettingSearchIndexItem = ({
  SettingSubpageEnum page,
  SettingEntry key,
  List<String> titles,
  List<String> titlesCleaned,
  List<String> parentTitles,
  NamidaFeaturesAvailablityBase? availability,
});
