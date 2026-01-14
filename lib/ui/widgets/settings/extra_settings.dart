import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _ExtraSettingsKeys with SettingKeysBase {
  collapsedTiles,
  bottomNavBar,
  pip(NamidaFeaturesAvailablity.android),
  foldersHierarchy,
  fabType,
  defaultLibraryTab,
  libraryTabs,
  filterTracksBy,
  ignoreCommonPrefixesFor,
  searchCleanup,
  prioritizeEmbeddedLyrics,
  lyricsSource,
  stretchLyricsDuration,
  imageSource,
  imageSourceAlbum,
  imageSourceArtist,
  immersiveMode(NamidaFeaturesAvailablity.android),
  swipeToOpenDrawer,
  alwaysExpandedSearchbar,
  enableClipboardMonitoring,
  vibrationType(NamidaFeaturesAvailablity.android),
  extractAllPalettes,
  ;

  @override
  final NamidaFeaturesAvailablityBase? availability;
  const _ExtraSettingsKeys([this.availability]);
}

class ExtrasSettings extends SettingSubpageProvider {
  const ExtrasSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.extra;

  @override
  Map<SettingKeysBase, List<String>> get lookupMap => {
        _ExtraSettingsKeys.collapsedTiles: [lang.USE_COLLAPSED_SETTING_TILES],
        _ExtraSettingsKeys.bottomNavBar: [lang.ENABLE_BOTTOM_NAV_BAR, lang.ENABLE_BOTTOM_NAV_BAR_SUBTITLE],
        _ExtraSettingsKeys.pip: [lang.ENABLE_PICTURE_IN_PICTURE],
        _ExtraSettingsKeys.foldersHierarchy: [lang.ENABLE_FOLDERS_HIERARCHY],
        _ExtraSettingsKeys.defaultLibraryTab: [lang.DEFAULT_LIBRARY_TAB],
        _ExtraSettingsKeys.fabType: [lang.FLOATING_ACTION_BUTTON],
        _ExtraSettingsKeys.libraryTabs: [lang.LIBRARY_TABS],
        _ExtraSettingsKeys.filterTracksBy: [lang.FILTER_TRACKS_BY],
        _ExtraSettingsKeys.ignoreCommonPrefixesFor: [lang.IGNORE_COMMON_PREFIXES_WHILE_SORTING],
        _ExtraSettingsKeys.searchCleanup: [lang.ENABLE_SEARCH_CLEANUP, lang.ENABLE_SEARCH_CLEANUP_SUBTITLE],
        _ExtraSettingsKeys.prioritizeEmbeddedLyrics: [lang.PRIORITIZE_EMBEDDED_LYRICS],
        _ExtraSettingsKeys.lyricsSource: [lang.LYRICS_SOURCE],
        _ExtraSettingsKeys.stretchLyricsDuration: [lang.STRETCH_LYRICS_DURATION],
        _ExtraSettingsKeys.imageSource: [lang.IMAGE_SOURCE, lang.ALBUM, lang.ALBUMS],
        _ExtraSettingsKeys.imageSourceAlbum: [lang.IMAGE_SOURCE, lang.ALBUM, lang.ALBUMS],
        _ExtraSettingsKeys.imageSourceArtist: [lang.IMAGE_SOURCE, lang.ARTIST, lang.ARTISTS],
        _ExtraSettingsKeys.immersiveMode: [lang.IMMERSIVE_MODE, lang.IMMERSIVE_MODE_SUBTITLE],
        _ExtraSettingsKeys.swipeToOpenDrawer: [lang.SWIPE_TO_OPEN_DRAWER],
        _ExtraSettingsKeys.alwaysExpandedSearchbar: [lang.ALWAYS_EXPANDED_SEARCHBAR],
        _ExtraSettingsKeys.enableClipboardMonitoring: [lang.ENABLE_CLIPBOARD_MONITORING, lang.ENABLE_CLIPBOARD_MONITORING_SUBTITLE],
        _ExtraSettingsKeys.vibrationType: [lang.VIBRATION_TYPE, lang.VIBRATION, lang.HAPTIC_FEEDBACK],
        _ExtraSettingsKeys.extractAllPalettes: [lang.EXTRACT_ALL_COLOR_PALETTES],
      };

  Widget _getImageSourceTile({
    required _ExtraSettingsKeys key,
    required String title,
    required IconData icon,
    required RxList<LibraryImageSource> settingsKey,
    required Function(LibraryImageSource sources) onAdd,
    required Function(LibraryImageSource sources) onRemove,
  }) =>
      getItemWrapper(
        key: key,
        child: ObxO(
          rx: settingsKey,
          builder: (context, sources) => CustomListTile(
            bgColor: getBgColor(key),
            title: title,
            icon: icon,
            borderR: 16.0,
            subtitle: LibraryImageSource.values.where((element) => sources.contains(element)).map((e) => e.toText()).join(', '), // to be sorted
            visualDensity: VisualDensity(horizontal: -4.0, vertical: -4.0),
            onTap: () {
              void tileOnTap(LibraryImageSource source, {bool removeIfExists = true}) {
                final alreadyExist = settingsKey.value.contains(source);
                if (alreadyExist) {
                  if (removeIfExists) {
                    if (settingsKey.value.length <= 1) {
                      showMinimumItemsSnack(1);
                    } else {
                      onRemove(source);
                    }
                  }
                } else {
                  onAdd(source);
                }
              }

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: title,
                  actions: [
                    IconButton(
                      onPressed: () {
                        for (final s in LibraryImageSource.values) {
                          tileOnTap(s, removeIfExists: false);
                        }
                      },
                      icon: const Icon(Broken.refresh),
                    ),
                    const DoneButton(),
                  ],
                  child: ObxO(
                    rx: settingsKey,
                    builder: (context, imageSources) => SuperSmoothListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        ...LibraryImageSource.values.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ListTileWithCheckMark(
                              active: imageSources.contains(e),
                              icon: e.toIcon(),
                              title: e.toText(),
                              onTap: () => tileOnTap(e),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

  void _showExtrasFlagsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.flag,
        title: lang.CONFIGURE,
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.DONE,
            onPressed: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: const _ExtrasFlagsOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return SettingsCard(
      title: lang.EXTRAS,
      subtitle: lang.EXTRAS_SUBTITLE,
      icon: Broken.command_square,
      trailing: NamidaIconButton(
        icon: Broken.flag,
        tooltip: () => lang.REFRESH_LIBRARY,
        onPressed: _showExtrasFlagsDialog,
      ),
      child: Column(
        children: <Widget>[
          getItemWrapper(
            key: _ExtraSettingsKeys.collapsedTiles,
            child: CollapsedSettingTileWidget(
              bgColor: getBgColor(_ExtraSettingsKeys.collapsedTiles),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.bottomNavBar,
            child: Obx(
              (context) => CustomSwitchListTile(
                enabled: !Dimensions.inst.showNavigationAtSide,
                bgColor: getBgColor(_ExtraSettingsKeys.bottomNavBar),
                icon: Broken.direct,
                title: lang.ENABLE_BOTTOM_NAV_BAR,
                subtitle: lang.ENABLE_BOTTOM_NAV_BAR_SUBTITLE,
                value: settings.enableBottomNavBar.valueR,
                onChanged: (p0) {
                  settings.save(enableBottomNavBar: !p0);
                  MiniPlayerController.inst.updateBottomNavBarRelatedDimensions(!p0);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.pip,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.pip),
                icon: Broken.screenmirroring,
                title: lang.ENABLE_PICTURE_IN_PICTURE,
                value: settings.enablePip.valueR,
                onChanged: (isTrue) {
                  settings.save(enablePip: !isTrue);
                  NamidaChannel.inst.setCanEnterPip(!isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.foldersHierarchy,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.foldersHierarchy),
                icon: Broken.folder_open,
                title: lang.ENABLE_FOLDERS_HIERARCHY,
                value: settings.enableFoldersHierarchy.valueR,
                onChanged: (p0) {
                  settings.save(enableFoldersHierarchy: !p0);
                  FoldersController.tracksAndVideos.onFoldersHierarchyChanged(!p0);
                  FoldersController.tracks.onFoldersHierarchyChanged(!p0);
                  FoldersController.videos.onFoldersHierarchyChanged(!p0);
                },
              ),
            ),
          ),
          // TODO: Allow later
          // Obx(
          //   (context) => CustomSwitchListTile(
          //     icon: Broken.folder_open,
          //     title: lang.ENABLE_FOLDERS_HIERARCHY,
          //     subtitle: lang.VIDEOS,
          //     value: settings.enableFoldersHierarchyVideos.valueR,
          //     onChanged: (p0) {
          //       settings.save(enableFoldersHierarchyVideos: !p0);
          //       FoldersController.videos.onFoldersHierarchyChanged(!p0);
          //     },
          //   ),
          // ),
          getItemWrapper(
            key: _ExtraSettingsKeys.fabType,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.fabType),
                icon: Broken.safe_home,
                title: lang.FLOATING_ACTION_BUTTON,
                trailingText: settings.floatingActionButton.valueR.toText(),
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.FLOATING_ACTION_BUTTON,
                      actions: const [
                        DoneButton(),
                      ],
                      child: SizedBox(
                        width: context.width,
                        child: Column(
                          children: FABType.values
                              .map(
                                (e) => ObxO(
                                  rx: settings.floatingActionButton,
                                  builder: (context, floatingActionButton) => Container(
                                    margin: const EdgeInsets.all(4.0),
                                    child: ListTileWithCheckMark(
                                      title: e.toText(),
                                      icon: e.toIcon(),
                                      active: floatingActionButton == e,
                                      onTap: () => settings.save(floatingActionButton: e),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.defaultLibraryTab,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.defaultLibraryTab),
                icon: Broken.receipt_1,
                title: lang.DEFAULT_LIBRARY_TAB,
                trailingText: settings.extra.autoLibraryTab.valueR ? lang.AUTO : settings.extra.staticLibraryTab.valueR.toText(),
                onTap: () => NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.DEFAULT_LIBRARY_TAB,
                    actions: const [
                      DoneButton(),
                    ],
                    child: SizedBox(
                      width: context.width,
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(4.0),
                            child: Obx(
                              (context) => ListTileWithCheckMark(
                                title: lang.AUTO,
                                icon: Broken.recovery_convert,
                                onTap: () => settings.extra.save(
                                  autoLibraryTab: !settings.extra.autoLibraryTab.value,
                                ),
                                active: settings.extra.autoLibraryTab.valueR,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          ...settings.libraryTabs.value.asMap().entries.map(
                                (e) => Obx(
                                  (context) => Container(
                                    margin: const EdgeInsets.all(4.0),
                                    child: ListTileWithCheckMark(
                                      title: "${e.key + 1}. ${e.value.toText()}",
                                      icon: e.value.toIcon(),
                                      onTap: () {
                                        settings.extra.save(
                                          selectedLibraryTab: e.value,
                                          staticLibraryTab: e.value,
                                          autoLibraryTab: false,
                                        );
                                      },
                                      active: !settings.extra.autoLibraryTab.valueR && settings.extra.selectedLibraryTab.valueR == e.value,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          getLibraryTabsTile(context),
          getItemWrapper(
            key: _ExtraSettingsKeys.filterTracksBy,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.filterTracksBy),
                icon: Broken.filter_search,
                title: lang.FILTER_TRACKS_BY,
                trailingText: "${settings.trackSearchFilter.length}",
                onTap: () {
                  final original = List<TrackSearchFilter>.from(settings.trackSearchFilter.value);

                  void refreshNecessary() {
                    final didChange = !DeepCollectionEquality.unordered().equals(original, settings.trackSearchFilter.value);
                    if (didChange) {
                      SearchSortController.inst.disposeMediaResources(MediaType.track);
                    }
                  }

                  NamidaNavigator.inst.navigateDialog(
                    onDismissing: refreshNecessary,
                    dialog: CustomBlurryDialog(
                      title: lang.FILTER_TRACKS_BY,
                      actions: [
                        IconButton(
                          icon: const Icon(Broken.refresh),
                          tooltip: lang.RESTORE_DEFAULTS,
                          onPressed: () {
                            settings.removeFromList(trackSearchFilterAll: TrackSearchFilter.values);

                            settings.save(trackSearchFilter: [
                              TrackSearchFilter.filename,
                              TrackSearchFilter.title,
                              TrackSearchFilter.artist,
                              TrackSearchFilter.album,
                            ]);
                          },
                        ),
                        DoneButton(
                          additional: refreshNecessary,
                        ),
                      ],
                      child: SmoothSingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...TrackSearchFilter.values.map(
                              (e) => Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Obx(
                                  (context) => ListTileWithCheckMark(
                                    title: e.toText(),
                                    onTap: () => _trackFilterOnTap(e),
                                    active: settings.trackSearchFilter.contains(e),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          getItemWrapper(
            key: _ExtraSettingsKeys.ignoreCommonPrefixesFor,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.ignoreCommonPrefixesFor),
                icon: Broken.message_remove,
                title: lang.IGNORE_COMMON_PREFIXES_WHILE_SORTING,
                subtitle: settings.commonPrefixes.valueR.map((e) => e.addDQuotation()).join(', '),
                trailingText: "${settings.ignoreCommonPrefixForTypes.length}",
                onTap: () {
                  final original = List<TrackSearchFilter>.from(settings.ignoreCommonPrefixForTypes.value);

                  final list = List<TrackSearchFilter>.from(TrackSearchFilter.values);
                  list.remove(TrackSearchFilter.comment);
                  list.remove(TrackSearchFilter.year);
                  list.remove(TrackSearchFilter.lyrics);

                  void resortIfNecessary() {
                    final didChange = !DeepCollectionEquality.unordered().equals(original, settings.ignoreCommonPrefixForTypes.value);
                    if (didChange) {
                      Indexer.inst.resortAllAfterIgnoreCommonPrefixChange();
                      SearchSortController.inst.disposeMediaResources(MediaType.track);
                    }
                  }

                  NamidaNavigator.inst.navigateDialog(
                    onDismissing: resortIfNecessary,
                    dialog: CustomBlurryDialog(
                      title: lang.IGNORE_COMMON_PREFIXES_WHILE_SORTING,
                      actions: [
                        IconButton(
                          icon: const Icon(Broken.refresh),
                          tooltip: lang.RESTORE_DEFAULTS,
                          onPressed: () {
                            settings.removeFromList(ignoreCommonPrefixForTypesAll: TrackSearchFilter.values);

                            settings.save(ignoreCommonPrefixForTypes: []);
                          },
                        ),
                        DoneButton(
                          additional: resortIfNecessary,
                        ),
                      ],
                      child: SmoothSingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ObxO(
                              rx: settings.commonPrefixes,
                              builder: (context, commonPrefixes) => Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ...commonPrefixes.map(
                                    (e) => Container(
                                      margin: const EdgeInsets.all(2.0),
                                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                                      decoration: BoxDecoration(
                                        color: theme.cardTheme.color,
                                        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          if (settings.commonPrefixes.length <= 1) return showMinimumItemsSnack(1);

                                          settings.commonPrefixes.remove(e);
                                          settings.save(commonPrefixes: settings.commonPrefixes.value);
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(e),
                                            const SizedBox(width: 6.0),
                                            const Icon(
                                              Broken.close_circle,
                                              size: 18.0,
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  NamidaContainerDivider(
                                    height: 24.0,
                                    width: 1.5,
                                    margin: EdgeInsets.symmetric(horizontal: 2.0),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(2.0),
                                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                                    decoration: BoxDecoration(
                                      color: theme.cardTheme.color?.withValues(alpha: 1.0),
                                      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        final controller = TextEditingController();
                                        void onAdd(String value) {
                                          settings.save(commonPrefixes: [value.toLowerCase()]);
                                          NamidaNavigator.inst.closeDialog();
                                        }

                                        NamidaNavigator.inst.navigateDialog(
                                          onDisposing: () {
                                            controller.dispose();
                                          },
                                          dialog: CustomBlurryDialog(
                                            title: lang.ADD,
                                            actions: [
                                              IconButton(
                                                tooltip: lang.RESTORE_DEFAULTS,
                                                onPressed: () {
                                                  settings.commonPrefixes.clear();
                                                  settings.save(commonPrefixes: ['the ', 'a ', 'an ']);
                                                  NamidaNavigator.inst.closeDialog();
                                                },
                                                icon: const Icon(Broken.refresh),
                                              ),
                                              const CancelButton(),
                                              NamidaButton(
                                                text: lang.SAVE,
                                                onPressed: () => onAdd(controller.text),
                                              ),
                                            ],
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 14.0),
                                              child: CustomTagTextField(
                                                controller: controller,
                                                onFieldSubmitted: onAdd,
                                                hintText: '',
                                                labelText: lang.VALUE,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(lang.ADD),
                                          const SizedBox(width: 6.0),
                                          const Icon(
                                            Broken.add_circle,
                                            size: 18.0,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4.0),
                            NamidaContainerDivider(),
                            ...list.map(
                              (e) => Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Obx(
                                  (context) => ListTileWithCheckMark(
                                    title: e.toText(),
                                    onTap: () => _ignoreCommonPrefixForTypeFilterOnTap(e),
                                    active: settings.ignoreCommonPrefixForTypes.contains(e),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.searchCleanup,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.searchCleanup),
                icon: Broken.document_filter,
                title: lang.ENABLE_SEARCH_CLEANUP,
                subtitle: lang.ENABLE_SEARCH_CLEANUP_SUBTITLE,
                value: settings.enableSearchCleanup.valueR,
                onChanged: (p0) => settings.save(enableSearchCleanup: !p0),
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.prioritizeEmbeddedLyrics,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.prioritizeEmbeddedLyrics),
                icon: Broken.mobile_programming,
                title: lang.PRIORITIZE_EMBEDDED_LYRICS,
                value: settings.prioritizeEmbeddedLyrics.valueR,
                onChanged: (p0) => settings.save(prioritizeEmbeddedLyrics: !p0),
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.lyricsSource,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.lyricsSource),
                title: lang.LYRICS_SOURCE,
                leading: const StackedIcon(
                  baseIcon: Broken.mobile_programming,
                  secondaryIcon: Broken.cpu_setting,
                ),
                trailingText: settings.lyricsSource.valueR.toText(),
                onTap: () {
                  void tileOnTap(LyricsSource val) => settings.save(lyricsSource: val);
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.LYRICS_SOURCE,
                      actions: [
                        IconButton(
                          onPressed: () => tileOnTap(LyricsSource.auto),
                          icon: const Icon(Broken.refresh),
                        ),
                        const DoneButton(),
                      ],
                      child: ObxO(
                        rx: settings.lyricsSource,
                        builder: (context, lyricsSource) => SuperSmoothListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            ObxO(
                              rx: settings.enableLyrics,
                              builder: (context, enableLyrics) => CustomSwitchListTile(
                                icon: Broken.document,
                                title: lang.LYRICS,
                                value: enableLyrics,
                                onChanged: (isTrue) {
                                  settings.save(enableLyrics: !isTrue);
                                  final currentItem = Player.inst.currentItem.value;
                                  if (currentItem != null) {
                                    Lyrics.inst.updateLyrics(currentItem);
                                  }
                                },
                              ),
                            ),
                            const NamidaContainerDivider(
                              margin: EdgeInsets.symmetric(vertical: 4.0),
                            ),
                            ...LyricsSource.values.map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3.0),
                                child: ListTileWithCheckMark(
                                  active: lyricsSource == e,
                                  title: e.toText(),
                                  onTap: () => tileOnTap(e),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.stretchLyricsDuration,
            child: ObxO(
              rx: settings.stretchLyricsDuration,
              builder: (context, stretch) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.stretchLyricsDuration),
                icon: Broken.arrange_square,
                title: lang.STRETCH_LYRICS_DURATION,
                subtitle: 'spedup/slowed/nightcore',
                value: stretch,
                onChanged: (val) => settings.save(stretchLyricsDuration: !val),
              ),
            ),
          ),

          getItemWrapper(
            key: _ExtraSettingsKeys.imageSource,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_ExtraSettingsKeys.imageSource),
              bigahh: true,
              normalRightPadding: true,
              initiallyExpanded: false,
              leading: const StackedIcon(
                baseIcon: Broken.image,
                secondaryIcon: Broken.cpu,
                secondaryIconSize: 13.0,
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              iconColor: context.defaultIconColor(),
              titleText: lang.IMAGE_SOURCE,
              children: [
                _getImageSourceTile(
                  key: _ExtraSettingsKeys.imageSourceAlbum,
                  settingsKey: settings.imageSourceAlbum,
                  title: lang.ALBUMS,
                  icon: LibraryTab.albums.toIcon(),
                  onAdd: (s) => settings.insertInList(0, imageSourceAlbum1: s),
                  onRemove: (s) => settings.removeFromList(imageSourceAlbum1: s),
                ),
                _getImageSourceTile(
                  key: _ExtraSettingsKeys.imageSourceArtist,
                  settingsKey: settings.imageSourceArtist,
                  title: lang.ARTISTS,
                  icon: LibraryTab.artists.toIcon(),
                  onAdd: (s) => settings.insertInList(0, imageSourceArtist1: s),
                  onRemove: (s) => settings.removeFromList(imageSourceArtist1: s),
                ),
              ],
            ),
          ),

          getItemWrapper(
            key: _ExtraSettingsKeys.immersiveMode,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.immersiveMode),
                icon: Broken.external_drive,
                title: lang.IMMERSIVE_MODE,
                subtitle: lang.IMMERSIVE_MODE_SUBTITLE,
                value: settings.hideStatusBarInExpandedMiniplayer.valueR,
                onChanged: (isTrue) {
                  final newValue = !isTrue;
                  settings.save(hideStatusBarInExpandedMiniplayer: newValue);
                  MiniPlayerController.inst.setImmersiveMode(newValue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.swipeToOpenDrawer,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.swipeToOpenDrawer),
                icon: Broken.sidebar_right,
                title: lang.SWIPE_TO_OPEN_DRAWER,
                value: settings.swipeableDrawer.valueR,
                onChanged: (isTrue) {
                  settings.save(swipeableDrawer: !isTrue);
                  NamidaNavigator.inst.innerDrawerKey.currentState?.toggleCanSwipe(!isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.alwaysExpandedSearchbar,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.alwaysExpandedSearchbar),
                // icon: Broken.scroll,
                leading: const StackedIcon(
                  baseIcon: Broken.scroll,
                  secondaryIcon: Broken.search_normal,
                  secondaryIconSize: 12.0,
                ),
                title: lang.ALWAYS_EXPANDED_SEARCHBAR,
                value: settings.alwaysExpandedSearchbar.valueR,
                onChanged: (isTrue) {
                  settings.save(alwaysExpandedSearchbar: !isTrue);
                  ScrollSearchController.inst.searchBarKey.currentState?.setAlwaysExpanded(!isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.enableClipboardMonitoring,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.enableClipboardMonitoring),
                icon: Broken.clipboard_export,
                title: lang.ENABLE_CLIPBOARD_MONITORING,
                subtitle: lang.ENABLE_CLIPBOARD_MONITORING_SUBTITLE,
                value: settings.enableClipboardMonitoring.valueR,
                onChanged: (isTrue) {
                  settings.save(enableClipboardMonitoring: !isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.vibrationType,
            child: CustomListTile(
              bgColor: getBgColor(_ExtraSettingsKeys.vibrationType),
              leading: const StackedIcon(
                baseIcon: Broken.alarm,
                secondaryIcon: Broken.wind_2,
                secondaryIconSize: 13.0,
              ),
              title: lang.VIBRATION_TYPE,
              trailing: NamidaPopupWrapper(
                children: () => [
                  ...VibrationType.values.map(
                    (e) {
                      void onTap() {
                        settings.save(vibrationType: e);
                        NamidaNavigator.inst.popMenu();
                      }

                      return ObxO(
                        rx: settings.vibrationType,
                        builder: (context, vibrationType) => NamidaInkWell(
                          margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                          borderRadius: 6.0,
                          bgColor: vibrationType == e ? theme.cardColor : null,
                          onTap: onTap,
                          child: Row(
                            children: [
                              Icon(
                                e.toIcon(),
                                size: 16.0,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                e.toText(),
                                style: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                child: ObxO(
                  rx: settings.vibrationType,
                  builder: (context, vibrationType) => Text(
                    vibrationType.toText(),
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ),
          ),

          getItemWrapper(
            key: _ExtraSettingsKeys.extractAllPalettes,
            child: Obx(
              (context) {
                final genProgress = CurrentColor.inst.allColorPalettesGeneratingProgress.valueR;
                final genTotal = CurrentColor.inst.allColorPalettesGeneratingTotal.valueR;
                final isGenerating = genTotal > 0;
                return CustomListTile(
                  bgColor: getBgColor(_ExtraSettingsKeys.extractAllPalettes),
                  icon: Broken.colorfilter,
                  title: lang.EXTRACT_ALL_COLOR_PALETTES,
                  trailing: isGenerating
                      ? Column(
                          children: [
                            Text("$genProgress/$genTotal"),
                            if (isGenerating) const LoadingIndicator(),
                          ],
                        )
                      : null,
                  onTap: () async {
                    if (CurrentColor.inst.allColorPalettesGeneratingTotal.value > 0) {
                      NamidaNavigator.inst.navigateDialog(
                        dialog: CustomBlurryDialog(
                          title: lang.NOTE,
                          bodyText: lang.FORCE_STOP_COLOR_PALETTE_GENERATION,
                          actions: [
                            const CancelButton(),
                            NamidaButton(
                              text: lang.STOP,
                              onPressed: () {
                                CurrentColor.inst.stopGeneratingColorPalettes();
                                NamidaNavigator.inst.closeDialog();
                              },
                            ),
                          ],
                        ),
                      );
                    } else {
                      NamidaNavigator.inst.navigateDialog(
                        dialog: CustomBlurryDialog(
                          title: lang.NOTE,
                          bodyText: lang.EXTRACT_ALL_COLOR_PALETTES_SUBTITLE
                              .replaceFirst('_REMAINING_COLOR_PALETTES_', '' /* '${allTracksInLibrary.length - Indexer.inst.colorPalettesInStorage.value}' */),
                          actions: [
                            const CancelButton(),
                            NamidaButton(
                              text: lang.EXTRACT,
                              onPressed: () {
                                CurrentColor.inst.generateAllColorPalettes();
                                NamidaNavigator.inst.closeDialog();
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget getLibraryTabsTile(BuildContext context) {
    final textTheme = context.textTheme;
    return getItemWrapper(
      key: _ExtraSettingsKeys.libraryTabs,
      child: Obx(
        (context) => CustomListTile(
          bgColor: getBgColor(_ExtraSettingsKeys.libraryTabs),
          icon: Broken.color_swatch,
          title: lang.LIBRARY_TABS,
          trailingText: "${settings.libraryTabs.length}",
          onTap: () {
            final subList = <LibraryTab>[].obs;

            LibraryTab.values.loop((e) {
              if (!settings.libraryTabs.contains(e)) {
                subList.add(e);
              }
            });

            NamidaNavigator.inst.navigateDialog(
              scale: 1.0,
              onDisposing: () {
                subList.close();
              },
              dialog: CustomBlurryDialog(
                title: lang.LIBRARY_TABS,
                actions: const [
                  DoneButton(),
                ],
                child: SizedBox(
                  width: namida.width,
                  height: namida.height * 0.5,
                  child: Obx(
                    (context) => Column(
                      children: [
                        Text(
                          lang.LIBRARY_TABS_REORDER,
                          style: textTheme.displayMedium,
                        ),
                        const SizedBox(height: 12.0),
                        Expanded(
                          flex: 6,
                          child: NamidaListView(
                            itemExtent: null,
                            listBottomPadding: 0,
                            itemCount: settings.libraryTabs.length,
                            itemBuilder: (context, i) {
                              final tab = settings.libraryTabs[i];
                              return Padding(
                                key: ValueKey(i),
                                padding: const EdgeInsets.all(4.0),
                                child: ListTileWithCheckMark(
                                  title: "${i + 1}. ${tab.toText()}",
                                  icon: tab.toIcon(),
                                  onTap: () {
                                    if (settings.libraryTabs.length > 3) {
                                      settings.removeFromList(libraryTab1: tab);
                                      settings.extra.save(selectedLibraryTab: settings.libraryTabs[0]);
                                      subList.add(tab);
                                    } else {
                                      showMinimumItemsSnack(3);
                                    }
                                  },
                                  active: settings.libraryTabs.contains(tab),
                                ),
                              );
                            },
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = settings.libraryTabs.value.elementAt(oldIndex);
                              settings.removeFromList(
                                libraryTab1: item,
                              );
                              settings.insertInList(newIndex, libraryTab1: item);
                            },
                          ),
                        ),
                        const NamidaContainerDivider(height: 4.0, margin: EdgeInsets.symmetric(vertical: 4.0)),
                        const SizedBox(height: 8.0),
                        if (subList.isNotEmpty)
                          Expanded(
                            flex: subList.length,
                            child: SuperSmoothListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: subList.length,
                              itemBuilder: (context, index) {
                                final item = subList[index];
                                return Material(
                                  type: MaterialType.transparency,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTileWithCheckMark(
                                      title: "${index + 1}. ${item.toText()}",
                                      icon: item.toIcon(),
                                      onTap: () {
                                        settings.save(libraryTabs: [item]);
                                        subList.remove(item);
                                      },
                                      active: settings.libraryTabs.contains(item),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _trackFilterOnTap(TrackSearchFilter type) {
    final canRemove = settings.trackSearchFilter.length > 1;

    if (settings.trackSearchFilter.value.contains(type)) {
      if (canRemove) {
        settings.removeFromList(trackSearchFilter1: type);
      } else {
        showMinimumItemsSnack(1);
      }
    } else {
      settings.save(trackSearchFilter: [type]);
    }
  }

  void _ignoreCommonPrefixForTypeFilterOnTap(TrackSearchFilter type) {
    if (settings.ignoreCommonPrefixForTypes.value.contains(type)) {
      settings.removeFromList(ignoreCommonPrefixForTypes1: type);
    } else {
      settings.save(ignoreCommonPrefixForTypes: [type]);
    }
  }
}

class LoadingIndicator extends StatefulWidget {
  final Color? circleColor;
  final double? width;
  final double? height;
  final double? boxWidth;
  final double? boxHeight;
  final int durationInMillisecond;

  const LoadingIndicator({
    super.key,
    this.circleColor,
    this.width = 5.0,
    this.height = 5.0,
    this.durationInMillisecond = 300,
    this.boxWidth = 20.0,
    this.boxHeight = 5.0,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final _alignmentTween = Tween<AlignmentGeometry>(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationInMillisecond),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.boxWidth,
      height: widget.boxHeight,
      child: AlignTransition(
        alignment: _alignmentTween.animate(_controller),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.circleColor ?? context.textTheme.displayMedium?.color,
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
      ),
    );
  }
}

class _ExtrasFlagsOptions extends StatefulWidget {
  const _ExtrasFlagsOptions();

  @override
  State<_ExtrasFlagsOptions> createState() => _ExtrasFlagsOptionsState();
}

class _ExtrasFlagsOptionsState extends State<_ExtrasFlagsOptions> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: NamidaScrollbarWithController(
          showOnStart: true,
          child: (c) => SuperSmoothListView(
            controller: c,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              CustomSwitchListTile(
                leading: StackedIcon(
                  baseIcon: Broken.row_vertical,
                  secondaryIcon: Broken.cd,
                  secondaryIconSize: 12.0,
                ),
                value: settings.extra.tapToScroll ?? false,
                onChanged: (isTrue) => setState(() => settings.extra.save(tapToScroll: !isTrue)),
                title: 'tap_to_scroll'.toUpperCase(),
                subtitle: 'tap anywhere on the scroll track to scroll',
              ),
              CustomSwitchListTile(
                leading: StackedIcon(
                  baseIcon: Broken.row_vertical,
                  secondaryIcon: Broken.arrow_swap,
                  secondaryIconSize: 12.0,
                ),
                value: settings.extra.enhancedDragToScroll ?? true,
                onChanged: (isTrue) => setState(() => settings.extra.save(enhancedDragToScroll: !isTrue)),
                title: 'enhanced_drag_to_scroll'.toUpperCase(),
                subtitle: 'drag anywhere on the scroll track to scroll',
              ),
              if (NamidaFeaturesVisibility.smoothScrolling)
                CustomSwitchListTile(
                  icon: Broken.coin,
                  rotateIcon: 2,
                  value: settings.extra.smoothScrolling ?? true,
                  onChanged: (isTrue) => setState(() => settings.extra.save(smoothScrolling: !isTrue)),
                  title: 'smooth_scrolling'.toUpperCase(),
                ),
              if (NamidaFeaturesVisibility.floatingArtworkEffect)
                CustomSwitchListTile(
                  icon: Broken.recovery_convert,
                  value: settings.extra.floatingArtworkEffect ?? false,
                  onChanged: (isTrue) => setState(() => settings.extra.save(floatingArtworkEffect: !isTrue)),
                  title: 'floating_artwork_effect'.toUpperCase(),
                  subtitle: "${lang.PERFORMANCE_NOTE}.\nMight affect battery usage.",
                ),
              if (NamidaFeaturesVisibility.tiltingCardsEffect)
                CustomSwitchListTile(
                  icon: Broken.d_rotate,
                  value: settings.extra.tiltingCardsEffect ?? false,
                  onChanged: (isTrue) => setState(() => settings.extra.save(tiltingCardsEffect: !isTrue)),
                  title: 'tilting_cards_effect'.toUpperCase(),
                  subtitle: "${lang.PERFORMANCE_NOTE}.\nMight affect battery usage.",
                ),
              if (NamidaFeaturesVisibility.mediaWaveHaptic)
                CustomSwitchListTile(
                  icon: Broken.watch_status,
                  value: settings.extra.mediaWaveHaptic ?? false,
                  onChanged: (isTrue) => setState(() => settings.extra.save(mediaWaveHaptic: !isTrue)),
                  title: 'media_wave_haptic'.toUpperCase(),
                  subtitle: 'Haptic feedback following the rhythm.\nMight affect battery usage.',
                ),
              CustomSwitchListTile(
                icon: Broken.colors_square,
                value: settings.gradientTiles.value,
                onChanged: (isTrue) => setState(() => settings.save(gradientTiles: !isTrue)),
                title: 'gradient_tiles_and_cards'.toUpperCase(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
