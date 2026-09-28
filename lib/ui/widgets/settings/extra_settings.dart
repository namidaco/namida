import 'dart:io';

import 'package:flutter/material.dart';

import 'package:modern_titlebar_buttons/modern_titlebar_buttons.dart' as mtb;

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
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
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _ExtraSettingsKeys with SettingKeysBase {
  collapsedTiles,
  bottomNavBar,
  pip(NamidaFeaturesAvailablity.android),
  fabType,
  defaultLibraryTab,
  libraryTabs,
  filterTracksBy,
  ignoreCommonPrefixesFor,
  searchCleanup,
  lyrics,
  lyricsSource,
  prioritizeEmbeddedLyrics,
  romanization,
  stretchLyricsDuration,
  simpleLyricsLine,
  lyricsSaveLocation,
  lyricsFolders,
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
    _ExtraSettingsKeys.collapsedTiles: [lang.useCollapsedSettingTiles],
    _ExtraSettingsKeys.bottomNavBar: [lang.enableBottomNavBar, lang.enableBottomNavBarSubtitle],
    _ExtraSettingsKeys.pip: [lang.enablePictureInPicture],
    _ExtraSettingsKeys.defaultLibraryTab: [lang.defaultLibraryTab],
    _ExtraSettingsKeys.fabType: [lang.floatingActionButton],
    _ExtraSettingsKeys.libraryTabs: [lang.libraryTabs],
    _ExtraSettingsKeys.filterTracksBy: [lang.filterTracksBy],
    _ExtraSettingsKeys.ignoreCommonPrefixesFor: [lang.ignoreCommonPrefixesWhileSorting],
    _ExtraSettingsKeys.searchCleanup: [lang.enableSearchCleanup, lang.enableSearchCleanupSubtitle],
    _ExtraSettingsKeys.lyrics: [lang.lyrics],
    _ExtraSettingsKeys.prioritizeEmbeddedLyrics: [lang.prioritizeEmbeddedLyrics],
    _ExtraSettingsKeys.lyricsSource: [lang.lyricsSource],
    _ExtraSettingsKeys.romanization: [lang.romanization, lang.dictionary],
    _ExtraSettingsKeys.stretchLyricsDuration: [lang.stretchLyricsDuration],
    _ExtraSettingsKeys.simpleLyricsLine: [lang.simpleLyricsLine, lang.simpleLyricsLineSubtitle],
    _ExtraSettingsKeys.lyricsSaveLocation: [lang.lyricsSaveLocation, lang.lyricsSaveLocationSubtitle, lang.lyricsDeleteWithTrack],
    _ExtraSettingsKeys.lyricsFolders: [lang.lyricsFolders, lang.lyricsFoldersSubtitle],
    _ExtraSettingsKeys.imageSource: [lang.imageSource, lang.album, lang.albums],
    _ExtraSettingsKeys.imageSourceAlbum: [lang.imageSource, lang.album, lang.albums],
    _ExtraSettingsKeys.imageSourceArtist: [lang.imageSource, lang.artist, lang.artists],
    _ExtraSettingsKeys.immersiveMode: [lang.immersiveMode, lang.immersiveModeSubtitle],
    _ExtraSettingsKeys.swipeToOpenDrawer: [lang.swipeToOpenDrawer],
    _ExtraSettingsKeys.alwaysExpandedSearchbar: [lang.alwaysExpandedSearchbar],
    _ExtraSettingsKeys.enableClipboardMonitoring: [lang.enableClipboardMonitoring, lang.enableClipboardMonitoringSubtitle],
    _ExtraSettingsKeys.vibrationType: [lang.vibrationType, lang.vibration, lang.hapticFeedback],
    _ExtraSettingsKeys.extractAllPalettes: [lang.extractAllColorPalettes],
  };

  Widget _getImageSourceTile({
    required _ExtraSettingsKeys key,
    required String title,
    required IconData icon,
    required RxBaseCore<List<LibraryImageSource>> settingsKey,
    required Function(LibraryImageSource sources) onAdd,
    required Function(LibraryImageSource sources) onRemove,
  }) => getItemWrapper(
    key: key,
    child: ObxO(
      rx: settingsKey,
      builder: (context, sources) => CustomListTile(
        bgColor: getBgColor(key),
        title: title,
        icon: icon,
        borderR: 16.0,
        subtitle: LibraryImageSource.values.where((element) => sources.contains(element)).map((e) => e.toText()).join(', '), // to be sorted
        extraDense: true,
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
                        padding: const EdgeInsets.all(3.0),
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
        title: lang.configure,
        normalTitleStyle: true,
        horizontalInset: 32.0,
        actions: [
          NamidaButton(
            text: lang.done,
            onTap: NamidaNavigator.inst.closeDialog,
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
      title: lang.extras,
      subtitle: lang.extrasSubtitle,
      icon: Broken.command_square,
      trailing: NamidaIconButton(
        icon: Broken.flag,
        tooltip: () => lang.refreshLibrary,
        iconColor: context.defaultIconColor(),
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
                title: lang.enableBottomNavBar,
                subtitle: lang.enableBottomNavBarSubtitle,
                value: settings.enableBottomNavBar.valueR,
                onChanged: (p0) {
                  settings.enableBottomNavBar.save(!p0);
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
                title: lang.enablePictureInPicture,
                value: settings.enablePip.valueR,
                onChanged: (isTrue) {
                  settings.enablePip.save(!isTrue);
                  NamidaChannel.inst.setCanEnterPip(!isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.fabType,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.fabType),
                icon: Broken.safe_home,
                title: lang.floatingActionButton,
                trailingText: settings.floatingActionButton.valueR.toText(),
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.floatingActionButton,
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
                                  builder: (context, floatingActionButton) => Padding(
                                    padding: const EdgeInsets.all(3.0),
                                    child: ListTileWithCheckMark(
                                      title: e.toText(),
                                      icon: e.toIcon(),
                                      active: floatingActionButton == e,
                                      onTap: () => settings.floatingActionButton.save(e),
                                    ),
                                  ),
                                ),
                              )
                              .toFixedList(),
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
                title: lang.defaultLibraryTab,
                trailingText: settings.extra.autoLibraryTab.valueR ? lang.auto : settings.extra.staticLibraryTab.valueR.toText(),
                onTap: () => NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.defaultLibraryTab,
                    actions: const [
                      DoneButton(),
                    ],
                    child: SizedBox(
                      width: context.width,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: Obx(
                              (context) => ListTileWithCheckMark(
                                title: lang.auto,
                                icon: Broken.recovery_convert,
                                onTap: () => settings.extra.autoLibraryTab.save(!settings.extra.autoLibraryTab.value),
                                active: settings.extra.autoLibraryTab.valueR,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          ...settings.libraryTabs.value.mapIndexed(
                            (tab, index) => Obx(
                              (context) => Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: ListTileWithCheckMark(
                                  title: "${index + 1}. ${tab.toText()}",
                                  icon: tab.toIcon(),
                                  onTap: () {
                                    settings.extra.transaction(() {
                                      settings.extra.setSelectedLibraryTab(tab);
                                      settings.extra.staticLibraryTab.save(tab);
                                      settings.extra.autoLibraryTab.save(false);
                                    });
                                  },
                                  active: !settings.extra.autoLibraryTab.valueR && settings.extra.selectedLibraryTab.valueR == tab,
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
                title: lang.filterTracksBy,
                trailingText: "${settings.trackSearchFilter.valueR.length}",
                onTap: () {
                  final original = List<TrackSearchFilter>.from(settings.trackSearchFilter.value);

                  void refreshNecessary() {
                    final didChange = settings.trackSearchFilter.value.didChangeFrom(original);
                    if (didChange) {
                      SearchSortController.inst.disposeMediaResources(MediaType.track);
                    }
                  }

                  NamidaNavigator.inst.navigateDialog(
                    onDismissing: refreshNecessary,
                    dialog: CustomBlurryDialog(
                      title: lang.filterTracksBy,
                      actions: [
                        IconButton(
                          icon: const Icon(Broken.refresh),
                          tooltip: lang.restoreDefaults,
                          onPressed: () {
                            settings.trackSearchFilter.reset();
                          },
                        ),
                        DoneButton(
                          additional: refreshNecessary,
                        ),
                      ],
                      child: SizedBox(
                        width: context.width,
                        height: context.height * 0.6,
                        child: SmoothSingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...TrackSearchFilter.values.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: Obx(
                                    (context) => ListTileWithCheckMark(
                                      title: e.toText(),
                                      subtitle: e.canAffectPerformance ? lang.performanceNote : '',
                                      onTap: () => _trackFilterOnTap(e),
                                      active: settings.trackSearchFilter.valueR.contains(e),
                                    ),
                                  ),
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
          ),

          getItemWrapper(
            key: _ExtraSettingsKeys.ignoreCommonPrefixesFor,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.ignoreCommonPrefixesFor),
                icon: Broken.message_remove,
                title: lang.ignoreCommonPrefixesWhileSorting,
                subtitle: settings.commonPrefixes.valueR.map((e) => e.addDQuotation()).join(', '),
                trailingText: "${settings.ignoreCommonPrefixForTypes.valueR.length}",
                onTap: () {
                  final original = List<TrackSearchFilter>.from(settings.ignoreCommonPrefixForTypes.value);

                  final list = List<TrackSearchFilter>.from(TrackSearchFilter.values);
                  list.remove(TrackSearchFilter.comment);
                  list.remove(TrackSearchFilter.description);
                  list.remove(TrackSearchFilter.year);
                  list.remove(TrackSearchFilter.moods);
                  list.remove(TrackSearchFilter.tags);
                  list.remove(TrackSearchFilter.lyrics);

                  void resortIfNecessary() {
                    final didChange = settings.ignoreCommonPrefixForTypes.value.didChangeFrom(original);
                    if (didChange) {
                      Indexer.inst.resortAllAfterIgnoreCommonPrefixChange();
                      SearchSortController.inst.disposeMediaResources(MediaType.track);
                    }
                  }

                  NamidaNavigator.inst.navigateDialog(
                    onDismissing: resortIfNecessary,
                    dialog: CustomBlurryDialog(
                      title: lang.ignoreCommonPrefixesWhileSorting,
                      actions: [
                        IconButton(
                          icon: const Icon(Broken.refresh),
                          tooltip: lang.restoreDefaults,
                          onPressed: () {
                            settings.ignoreCommonPrefixForTypes.reset();
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
                                          if (settings.commonPrefixes.value.length <= 1) return showMinimumItemsSnack(1);

                                          settings.commonPrefixes.update((prefixes) => prefixes.remove(e));
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(e),
                                            const SizedBox(width: 6.0),
                                            const Icon(
                                              Broken.close_circle,
                                              size: 18.0,
                                            ),
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
                                      color: theme.cardTheme.color?.withOpacityExt(1.0),
                                      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        final controller = TextEditingController();
                                        void onAdd(String value) {
                                          settings.commonPrefixes.update((list) => list.addNoDuplicates(value.toLowerCase()));
                                          NamidaNavigator.inst.closeDialog();
                                        }

                                        NamidaNavigator.inst.navigateDialog(
                                          onDisposing: () {
                                            controller.dispose();
                                          },
                                          dialog: CustomBlurryDialog(
                                            title: lang.add,
                                            actions: [
                                              IconButton(
                                                tooltip: lang.restoreDefaults,
                                                onPressed: () {
                                                  settings.commonPrefixes.reset();
                                                  NamidaNavigator.inst.closeDialog();
                                                },
                                                icon: const Icon(Broken.refresh),
                                              ),
                                              const CancelButton(),
                                              NamidaButton(
                                                text: lang.save,
                                                onTap: () => onAdd(controller.text),
                                              ),
                                            ],
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 14.0),
                                              child: CustomTagTextField(
                                                controller: controller,
                                                onFieldSubmitted: onAdd,
                                                hintText: '',
                                                labelText: lang.value,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(lang.add),
                                          const SizedBox(width: 6.0),
                                          const Icon(
                                            Broken.add_circle,
                                            size: 18.0,
                                          ),
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
                                padding: const EdgeInsets.all(3.0),
                                child: Obx(
                                  (context) => ListTileWithCheckMark(
                                    title: e.toText(),
                                    onTap: () => _ignoreCommonPrefixForTypeFilterOnTap(e),
                                    active: settings.ignoreCommonPrefixForTypes.valueR.contains(e),
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
                title: lang.enableSearchCleanup,
                subtitle: lang.enableSearchCleanupSubtitle,
                value: settings.enableSearchCleanup.valueR,
                onChanged: (p0) {
                  settings.enableSearchCleanup.save(!p0);
                  SearchSortController.inst.disposeResources();
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.lyrics,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_ExtraSettingsKeys.lyrics),
              bigahh: true,
              normalRightPadding: true,
              initiallyExpanded: true,
              // initiallyExpanded: const [
              //   _ExtraSettingsKeys.lyrics,
              //   _ExtraSettingsKeys.lyricsSource,
              //   _ExtraSettingsKeys.prioritizeEmbeddedLyrics,
              //   _ExtraSettingsKeys.romanization,
              // ].contains(initialItem),
              leading: const StackedIcon(
                baseIcon: Broken.document,
                secondaryIcon: Broken.cpu,
                secondaryIconSize: 13.0,
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              iconColor: context.defaultIconColor(),
              titleText: lang.lyrics,
              children: [
                getItemWrapper(
                  key: _ExtraSettingsKeys.lyricsSource,
                  child: Obx(
                    (context) => CustomListTile(
                      bgColor: getBgColor(_ExtraSettingsKeys.lyricsSource),
                      title: lang.lyricsSource,
                      leading: const StackedIcon(
                        baseIcon: Broken.mobile_programming,
                        secondaryIcon: Broken.cpu_setting,
                      ),
                      trailingText: settings.lyricsSource.valueR.toText(),
                      onTap: () {
                        void tileOnTap(LyricsSource val) => settings.lyricsSource.save(val);
                        NamidaNavigator.inst.navigateDialog(
                          dialog: CustomBlurryDialog(
                            title: lang.lyricsSource,
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
                                      title: lang.lyrics,
                                      value: enableLyrics,
                                      onChanged: (isTrue) {
                                        settings.enableLyrics.save(!isTrue);
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
                                      padding: const EdgeInsets.all(3.0),
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
                  key: _ExtraSettingsKeys.romanization,
                  child: CustomListTile(
                    bgColor: getBgColor(_ExtraSettingsKeys.romanization),
                    icon: Broken.translate,
                    title: lang.romanization,
                    trailing: const Icon(
                      Broken.arrow_right_3,
                      size: 16.0,
                    ),
                    onTap: () {
                      final wasRomanizingSorting = settings.romanizeSorting.value;
                      final wasDictionaryInstalled = Romanizer.inst.isDictionaryInstalled.value;

                      void resortIfNecessary() {
                        final isRomanizingSorting = settings.romanizeSorting.value;
                        final didChange =
                            wasRomanizingSorting != isRomanizingSorting || (isRomanizingSorting && wasDictionaryInstalled != Romanizer.inst.isDictionaryInstalled.value);
                        if (didChange) {
                          Indexer.inst.resortAllAfterIgnoreCommonPrefixChange();
                          SearchSortController.inst.disposeMediaResources(MediaType.track);
                        }
                      }

                      NamidaNavigator.inst.navigateDialog(
                        onDismissing: resortIfNecessary,
                        dialog: CustomBlurryDialog(
                          title: lang.romanization,
                          actions: const [
                            DoneButton(),
                          ],
                          child: SuperSmoothListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              ObxO(
                                rx: settings.romanizeLyrics,
                                builder: (context, romanizeLyrics) => CustomSwitchListTile(
                                  icon: Broken.document,
                                  title: '${lang.romanization}: ${lang.lyrics}',
                                  value: romanizeLyrics,
                                  onChanged: (isTrue) => Romanizer.inst.setLyricsEnabled(!isTrue),
                                ),
                              ),
                              ObxO(
                                rx: settings.romanizeSorting,
                                builder: (context, romanizeSorting) => CustomSwitchListTile(
                                  icon: Broken.sort,
                                  title: '${lang.romanization}: ${lang.sortBy}',
                                  value: romanizeSorting,
                                  onChanged: (isTrue) => Romanizer.inst.setSortingEnabled(!isTrue),
                                ),
                              ),
                              const NamidaContainerDivider(
                                margin: EdgeInsets.symmetric(vertical: 4.0),
                              ),
                              ObxO(
                                rx: Romanizer.inst.isDictionaryInstalled,
                                builder: (context, isDictionaryInstalled) => ObxO(
                                  rx: Romanizer.inst.downloadProgress,
                                  builder: (context, downloadProgress) => CustomListTile(
                                    icon: Broken.book,
                                    title: lang.dictionary,
                                    subtitle: '日本語 (漢字) • 中文',
                                    trailingText: downloadProgress != null
                                        ? '${(downloadProgress * 100).round()}%'
                                        : isDictionaryInstalled
                                        ? lang.delete
                                        : lang.download,
                                    onTap: () {
                                      if (downloadProgress != null) {
                                        Romanizer.inst.cancelDownload();
                                      } else if (isDictionaryInstalled) {
                                        Romanizer.inst.deleteDictionary();
                                      } else {
                                        Romanizer.inst.downloadDictionary(enableLyrics: true);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                getItemWrapper(
                  key: _ExtraSettingsKeys.prioritizeEmbeddedLyrics,
                  child: Obx(
                    (context) => CustomSwitchListTile(
                      bgColor: getBgColor(_ExtraSettingsKeys.prioritizeEmbeddedLyrics),
                      icon: Broken.mobile_programming,
                      title: lang.prioritizeEmbeddedLyrics,
                      value: settings.prioritizeEmbeddedLyrics.valueR,
                      onChanged: (p0) => settings.prioritizeEmbeddedLyrics.save(!p0),
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
                      title: lang.stretchLyricsDuration,
                      subtitle: 'spedup/slowed/nightcore',
                      value: stretch,
                      onChanged: (val) => settings.stretchLyricsDuration.save(!val),
                    ),
                  ),
                ),
                getItemWrapper(
                  key: _ExtraSettingsKeys.simpleLyricsLine,
                  child: ObxO(
                    rx: settings.enableSimpleLyricsLine,
                    builder: (context, enableSimpleLyricsLine) => CustomSwitchListTile(
                      bgColor: getBgColor(_ExtraSettingsKeys.simpleLyricsLine),
                      icon: Broken.text,
                      title: lang.simpleLyricsLine,
                      subtitle: lang.simpleLyricsLineSubtitle,
                      value: enableSimpleLyricsLine,
                      onChanged: (isTrue) {
                        settings.enableSimpleLyricsLine.save(!isTrue);
                        final currentItem = Player.inst.currentItem.value;
                        if (currentItem != null) {
                          Lyrics.inst.updateLyrics(currentItem);
                        }
                      },
                    ),
                  ),
                ),
                getItemWrapper(
                  key: _ExtraSettingsKeys.lyricsSaveLocation,
                  child: _LyricsSaveLocationTile(
                    bgColor: getBgColor(_ExtraSettingsKeys.lyricsSaveLocation),
                  ),
                ),
                getItemWrapper(
                  key: _ExtraSettingsKeys.lyricsFolders,
                  child: _LyricsFoldersTile(
                    bgColor: getBgColor(_ExtraSettingsKeys.lyricsFolders),
                    initiallyExpanded: initialItem == _ExtraSettingsKeys.lyricsFolders,
                  ),
                ),
              ],
            ),
          ),

          getItemWrapper(
            key: _ExtraSettingsKeys.imageSource,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_ExtraSettingsKeys.imageSource),
              bigahh: true,
              normalRightPadding: true,
              initiallyExpanded: false || initialItem == _ExtraSettingsKeys.imageSource,
              leading: const StackedIcon(
                baseIcon: Broken.image,
                secondaryIcon: Broken.cpu,
                secondaryIconSize: 13.0,
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              iconColor: context.defaultIconColor(),
              titleText: lang.imageSource,
              children: [
                _getImageSourceTile(
                  key: _ExtraSettingsKeys.imageSourceAlbum,
                  settingsKey: settings.imageSourceAlbum,
                  title: lang.albums,
                  icon: LibraryTab.albums.toIcon(),
                  onAdd: (s) => settings.imageSourceAlbum.update((list) => list.insertSafe(0, s)),
                  onRemove: (s) => settings.imageSourceAlbum.update((list) => list.remove(s)),
                ),
                _getImageSourceTile(
                  key: _ExtraSettingsKeys.imageSourceArtist,
                  settingsKey: settings.imageSourceArtist,
                  title: lang.artists,
                  icon: LibraryTab.artists.toIcon(),
                  onAdd: (s) => settings.imageSourceArtist.update((list) => list.insertSafe(0, s)),
                  onRemove: (s) => settings.imageSourceArtist.update((list) => list.remove(s)),
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
                title: lang.immersiveMode,
                subtitle: lang.immersiveModeSubtitle,
                value: settings.hideStatusBarInExpandedMiniplayer.valueR,
                onChanged: (isTrue) {
                  final newValue = !isTrue;
                  settings.hideStatusBarInExpandedMiniplayer.save(newValue);
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
                title: lang.swipeToOpenDrawer,
                value: settings.swipeableDrawer.valueR,
                onChanged: (isTrue) {
                  settings.swipeableDrawer.save(!isTrue);
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
                title: lang.alwaysExpandedSearchbar,
                value: settings.alwaysExpandedSearchbar.valueR,
                onChanged: (isTrue) {
                  settings.alwaysExpandedSearchbar.save(!isTrue);
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
                title: lang.enableClipboardMonitoring,
                subtitle: lang.enableClipboardMonitoringSubtitle,
                value: settings.enableClipboardMonitoring.valueR,
                onChanged: (isTrue) {
                  settings.enableClipboardMonitoring.save(!isTrue);
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
              title: lang.vibrationType,
              trailing: NamidaPopupWrapper(
                childrenDefault: () => VibrationType.values.map(
                  (e) {
                    void onTap() {
                      settings.vibrationType.save(e);
                      NamidaNavigator.inst.popMenu();
                    }

                    return NamidaPopupItem(
                      onTap: onTap,
                      icon: e.toIcon(),
                      title: e.toText(),
                      selected: e == settings.vibrationType.value,
                    );
                  },
                ),
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
                  title: lang.extractAllColorPalettes,
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
                          title: lang.note,
                          bodyText: lang.forceStopColorPaletteGeneration,
                          actions: [
                            const CancelButton(),
                            NamidaButton(
                              text: lang.stop,
                              onTap: () {
                                CurrentColor.inst.stopGeneratingColorPalettes();
                                NamidaNavigator.inst.closeDialog();
                              },
                            ),
                          ],
                        ),
                      );
                    } else {
                      final remainingCount = await CurrentColor.inst.getRemainingColorsToExtractCount(allTracksInLibrary);
                      NamidaNavigator.inst.navigateDialog(
                        dialog: CustomBlurryDialog(
                          title: lang.note,
                          bodyText: lang.extractAllColorPalettesSubtitle(number: remainingCount),
                          actions: [
                            const CancelButton(),
                            NamidaButton(
                              text: lang.extract,
                              onTap: () {
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
    return getItemWrapper(
      key: _ExtraSettingsKeys.libraryTabs,
      child: ObxO(
        rx: settings.libraryTabs,
        builder: (context, libraryTabs) => CustomListTile(
          bgColor: getBgColor(_ExtraSettingsKeys.libraryTabs),
          icon: Broken.color_swatch,
          title: lang.libraryTabs,
          subtitle: libraryTabs.map((e) => e.toText()).join(', '),
          trailingText: "${libraryTabs.length}",
          onTap: () => NamidaNavigator.inst.navigateDialog(
            scale: 1.0,
            dialog: CustomBlurryDialog(
              title: "${lang.libraryTabs} (${lang.reorderable})",
              actions: const [
                DoneButton(),
              ],
              child: SizedBox(
                width: namida.width,
                height: namida.height * 0.5,
                child: NamidaReorderableActiveListView(
                  enumValues: LibraryTab.values.where((e) => e.isGroupHead).toList(),
                  activeItems: libraryTabs,
                  toText: (item) => item.toText(),
                  toIcon: (item) => item.toIcon(),
                  minimumItems: 2,
                  onItemRemoved: (i, activeItems) {
                    settings.extra.setSelectedLibraryTab(settings.libraryTabs.value.first);
                  },
                  onSave: (activeItems) {
                    settings.libraryTabs.replace(activeItems);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _trackFilterOnTap(TrackSearchFilter type) {
    final canRemove = settings.trackSearchFilter.value.length > 1;

    if (settings.trackSearchFilter.value.contains(type)) {
      if (canRemove) {
        settings.trackSearchFilter.update((list) => list.remove(type));
      } else {
        showMinimumItemsSnack(1);
      }
    } else {
      settings.trackSearchFilter.update((list) => list.addNoDuplicates(type));
    }
  }

  void _ignoreCommonPrefixForTypeFilterOnTap(TrackSearchFilter type) {
    if (settings.ignoreCommonPrefixForTypes.value.contains(type)) {
      settings.ignoreCommonPrefixForTypes.update((list) => list.remove(type));
    } else {
      settings.ignoreCommonPrefixForTypes.update((list) => list.addNoDuplicates(type));
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

class _ExtrasFlagsOptions extends StatelessWidget {
  const _ExtrasFlagsOptions();

  static Iterable<Widget> _getTitlebarIconsTypeChildren() {
    final buttonWidth = 18.0;
    final buttonHeight = 18.0;
    return DesktopTitlebarIconsType.values.map(
      (e) {
        void onTap() {
          settings.desktopTitlebarType.save(e);
          NamidaNavigator.inst.popMenu();
        }

        final buttonsType = e.toThemeType();
        final row = buttonsType == null
            ? Text(
                lang.none,
                textAlign: TextAlign.center,
              )
            : buttonsType == mtb.ThemeType.auto
            ? Text(
                lang.auto,
                textAlign: TextAlign.center,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  mtb.DecoratedMinimizeButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    type: buttonsType,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 2.0),
                  mtb.DecoratedMaximizeButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    type: buttonsType,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 2.0),
                  mtb.DecoratedCloseButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    type: buttonsType,
                    onPressed: () {},
                  ),
                ],
              );
        return ObxO(
          rx: settings.desktopTitlebarType,
          builder: (context, value) => NamidaInkWell(
            margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            borderRadius: 6.0,
            bgColor: value == e ? context.theme.cardColor : null,
            onTap: onTap,
            child: row,
          ),
        );
      },
    );
  }

  static Iterable<NamidaPopupItem> _getSearchTypeChildren([void Function()? onSave]) {
    return SearchType.values.map(
      (e) => NamidaPopupItem(
        icon: Broken.cd,
        title: e.name,
        selected: e == settings.extra.preferredSearchType.value,
        onTap: () {
          settings.extra.preferredSearchType.save(e);
          onSave?.call();
        },
      ),
    );
  }

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
              ObxO(
                rx: settings.extra.tapToScroll,
                builder: (context, tapToScroll) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.cd,
                    secondaryIconSize: 12.0,
                  ),
                  value: tapToScroll ?? false,
                  onChanged: (isTrue) => settings.extra.tapToScroll.save(!isTrue),
                  title: 'tap_to_scroll'.toUpperCase(),
                  subtitle: 'tap anywhere on the scroll track to scroll',
                ),
              ),
              ObxO(
                rx: settings.extra.enhancedDragToScroll,
                builder: (context, enhancedDragToScroll) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.arrow_swap,
                    secondaryIconSize: 12.0,
                  ),
                  value: enhancedDragToScroll ?? true,
                  onChanged: (isTrue) => settings.extra.enhancedDragToScroll.save(!isTrue),
                  title: 'enhanced_drag_to_scroll'.toUpperCase(),
                  subtitle: 'drag anywhere on the scroll track to scroll',
                ),
              ),
              ObxO(
                rx: settings.extra.scrollbarThumbLabel,
                builder: (context, scrollbarThumbLabel) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.text,
                    secondaryIconSize: 12.0,
                  ),
                  value: scrollbarThumbLabel ?? false,
                  onChanged: (isTrue) => settings.extra.scrollbarThumbLabel.save(!isTrue),
                  title: 'scrollbar_thumb_label'.toUpperCase(),
                  subtitle: 'show the current letter/section next to the scrollbar while dragging it',
                ),
              ),
              if (NamidaFeaturesVisibility.smoothScrolling)
                ObxO(
                  rx: settings.extra.smoothScrolling,
                  builder: (context, smoothScrolling) => CustomSwitchListTile(
                    icon: Broken.coin,
                    rotateIcon: 2,
                    value: smoothScrolling ?? true,
                    onChanged: (isTrue) => settings.extra.smoothScrolling.save(!isTrue),
                    title: 'smooth_scrolling'.toUpperCase(),
                  ),
                ),
              if (NamidaFeaturesVisibility.floatingArtworkEffect)
                ObxO(
                  rx: settings.extra.floatingArtworkEffect,
                  builder: (context, floatingArtworkEffect) => CustomSwitchListTile(
                    icon: Broken.recovery_convert,
                    value: floatingArtworkEffect ?? false,
                    onChanged: (isTrue) => settings.extra.floatingArtworkEffect.save(!isTrue),
                    title: 'floating_artwork_effect'.toUpperCase(),
                    subtitle: "${lang.performanceNote}.\nMight affect battery usage.",
                  ),
                ),
              if (NamidaFeaturesVisibility.tiltingCardsEffect)
                ObxO(
                  rx: settings.extra.tiltingCardsEffect,
                  builder: (context, tiltingCardsEffect) => CustomSwitchListTile(
                    icon: Broken.d_rotate,
                    value: tiltingCardsEffect ?? false,
                    onChanged: (isTrue) => settings.extra.tiltingCardsEffect.save(!isTrue),
                    title: 'tilting_cards_effect'.toUpperCase(),
                    subtitle: "${lang.performanceNote}.\nMight affect battery usage.",
                  ),
                ),
              if (kAllowJellysInvasion) ...[
                ObxO(
                  rx: settings.extra.jellysInvasion,
                  builder: (context, jellysInvasion) => CustomSwitchListTile(
                    leading: const JellyMascot(height: 30.0),
                    value: jellysInvasion ?? false,
                    onChanged: (isTrue) => NamidaJellys.setInvasion(!isTrue, paletteFollows: true),
                    title: 'jellys_invasion'.toUpperCase(),
                    subtitle: 'Let jellyfishes drift around the app.\n${lang.performanceNote}.\nby ${NamidaAppIcons.jellyda.authorInfoText}',
                  ),
                ),
                ObxO(
                  rx: settings.extra.jellysPalette,
                  builder: (context, jellysPalette) => CustomSwitchListTile(
                    icon: Broken.color_swatch,
                    value: jellysPalette ?? false,
                    onChanged: (isTrue) => NamidaJellys.setPaletteHijack(!isTrue),
                    title: 'jellys_color_palette'.toUpperCase(),
                  ),
                ),
              ],
              ObxO(
                rx: settings.extra.keepVideoFrameOnSwitch,
                builder: (context, keepVideoFrameOnSwitch) => CustomSwitchListTile(
                  icon: Broken.video_play,
                  value: keepVideoFrameOnSwitch ?? false,
                  onChanged: (isTrue) => settings.extra.keepVideoFrameOnSwitch.save(!isTrue),
                  title: 'keep_video_frame_on_switch'.toUpperCase(),
                  subtitle: 'Keep the last video frame while switching to an item whose video is already downloaded, instead of flashing the artwork in between.',
                ),
              ),
              if (NamidaFeaturesVisibility.mediaWaveHaptic)
                ObxO(
                  rx: settings.extra.mediaWaveHaptic,
                  builder: (context, mediaWaveHaptic) => CustomSwitchListTile(
                    icon: Broken.watch_status,
                    value: mediaWaveHaptic ?? false,
                    onChanged: (isTrue) => settings.extra.mediaWaveHaptic.save(!isTrue),
                    title: 'media_wave_haptic'.toUpperCase(),
                    subtitle: 'Haptic feedback following the rhythm.\nMight affect battery usage.',
                  ),
                ),
              ObxO(
                rx: settings.gradientTiles,
                builder: (context, gradientTiles) => CustomSwitchListTile(
                  icon: Broken.colors_square,
                  value: gradientTiles,
                  onChanged: (isTrue) => settings.gradientTiles.save(!isTrue),
                  title: 'gradient_tiles_and_cards'.toUpperCase(),
                ),
              ),
              if (isDesktop)
                ObxO(
                  rx: settings.desktopTitlebar,
                  builder: (context, desktopTitlebar) => CustomSwitchListTile(
                    icon: Broken.card_tick_1,
                    value: desktopTitlebar,
                    onChanged: (isTrue) => settings.desktopTitlebar.save(!isTrue),
                    title: 'show_desktop_title_bar'.toUpperCase(),
                  ),
                ),
              if (isDesktop && !Platform.isWindows)
                NamidaPopupWrapper(
                  children: _getTitlebarIconsTypeChildren,
                  child: CustomListTile(
                    icon: Broken.close_circle,
                    title: 'desktop_title_bar_icons_type'.toUpperCase(),
                    trailing: NamidaPopupWrapper(
                      children: _getTitlebarIconsTypeChildren,
                      child: ObxO(
                        rx: settings.desktopTitlebarType,
                        builder: (context, type) => Text(
                          type.name,
                          style: context.textTheme.displayMedium,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  ),
                ),

              ObxO(
                rx: settings.extra.ytStyleButtonSwitcher,
                builder: (context, ytStyleButtonSwitcher) => CustomSwitchListTile(
                  icon: Broken.video_octagon,
                  value: ytStyleButtonSwitcher ?? false,
                  onChanged: (isTrue) => settings.extra.ytStyleButtonSwitcher.save(!isTrue),
                  title: 'yt_style_player_button_switcher'.toUpperCase(),
                  subtitle: 'shows a button to switch between local style player and youtube style player',
                ),
              ),
              ObxO(
                rx: settings.extra.recentSearchesEnabled,
                builder: (context, recentSearchesEnabled) => CustomSwitchListTile(
                  icon: Broken.search_status,
                  value: recentSearchesEnabled ?? false,
                  onChanged: (isTrue) => settings.extra.setRecentSearchesEnabled(!isTrue),
                  title: 'recent_searches'.toUpperCase(),
                  subtitle: 'saves searches and shows them in the search page',
                ),
              ),
              ObxO(
                rx: settings.extra.resumeUIEnabled,
                builder: (context, resumeUIEnabled) => CustomSwitchListTile(
                  icon: Broken.play_circle,
                  value: resumeUIEnabled,
                  onChanged: (isTrue) => settings.extra.resumeUIEnabled.save(!isTrue),
                  title: 'resume_ui'.toUpperCase(),
                  subtitle: 'shows the resume button & highlights the last played item in pages like albums & playlists',
                ),
              ),

              if (NamidaFeaturesVisibility.equalizerAvailable)
                ObxO(
                  rx: settings.customEQPackage,
                  builder: (context, package) => CustomListTile(
                    icon: Broken.chart_3,
                    title: 'custom_eq_package'.toUpperCase(),
                    trailingText: package ?? '',
                    onTap: () {
                      final controller = TextEditingController(text: package);
                      NamidaNavigator.inst.navigateDialog(
                        onDisposing: () {
                          controller.dispose();
                        },
                        dialog: CustomBlurryDialog(
                          title: 'custom_eq_package'.toUpperCase(),
                          actions: [
                            IconButton(
                              tooltip: lang.restoreDefaults,
                              onPressed: () {
                                settings.customEQPackage.reset();
                                NamidaNavigator.inst.closeDialog();
                              },
                              icon: const Icon(Broken.refresh),
                            ),
                            const CancelButton(),
                            NamidaButton(
                              text: lang.save,
                              onTap: () {
                                settings.customEQPackage.save(controller.text);
                                NamidaNavigator.inst.closeDialog();
                              },
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14.0),
                            child: CustomTagTextField(
                              controller: controller,
                              hintText: 'com.example.equalizer',
                              labelText: lang.value,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ObxO(
                rx: settings.visualDelayMS,
                builder: (context, visualDelayMS) => CustomListTile(
                  icon: Broken.clock,
                  title: 'visual_to_audio_delay'.toUpperCase(),
                  subtitle: 'delay certain ui animations (ex. lyrics) to match with bluetooth audio delay',
                  trailing: NamidaWheelSlider(
                    initValue: visualDelayMS ~/ 10,
                    max: 200,
                    onValueChanged: (val) {
                      final ms = val * 10;
                      settings.visualDelayMS.save(ms);
                    },
                    text: '$visualDelayMS ms',
                  ),
                ),
              ),
              ObxO(
                rx: settings.timeCapsuleYears,
                builder: (context, timeCapsuleYears) {
                  timeCapsuleYears ??= 0;
                  final now = DateTime.now();
                  const preferredYear = 2018;

                  const int maxYears = 100 * 5;
                  const int offset = maxYears ~/ 2;
                  return CustomListTile(
                    icon: Broken.calendar,
                    title: 'time_capsule_years'.toUpperCase(),
                    subtitle:
                        "you think it's ${now.year}? $preferredYear was ${now.year - preferredYear} years ago? except that it's not. this capsule can send u back in time or far into the future, use carefully.",
                    trailing: NamidaWheelSlider(
                      initValue: timeCapsuleYears + offset,
                      max: maxYears,
                      onValueChanged: (val) {
                        final actualYears = val - offset;
                        settings.timeCapsuleYears.save(actualYears);
                      },
                      text: timeCapsuleYears > 0 ? '+$timeCapsuleYears' : '$timeCapsuleYears',
                    ),
                  );
                },
              ),
              NamidaPopupWrapper(
                childrenDefault: _getSearchTypeChildren,
                child: CustomListTile(
                  icon: Broken.search_favorite,
                  title: 'preferred_search_tab'.toUpperCase(),
                  trailing: NamidaPopupWrapper(
                    childrenDefault: _getSearchTypeChildren,
                    child: ObxO(
                      rx: settings.extra.preferredSearchType,
                      builder: (context, type) => Text(
                        type.name,
                        style: context.textTheme.displayMedium,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricsSaveLocationTile extends StatelessWidget {
  final Color? bgColor;

  const _LyricsSaveLocationTile({required this.bgColor});

  void _onLocationTap(LyricsSaveLocation location) async {
    if (location != LyricsSaveLocation.cache) {
      final hasPermission = await requestManageStoragePermission();
      if (!hasPermission) return;
    }
    final needsFolder = location == LyricsSaveLocation.customFolder && settings.lyricsFolders.value.isEmpty;
    if (needsFolder) {
      NamidaNavigator.inst.closeDialog();
      final didAdd = await _addLyricsFolder();
      if (!didAdd) return;
    }
    settings.lyricsSaveLocation.save(location);
  }

  void _openLocationsDialog() {
    final saveFolder = settings.lyricsFolders.value.firstOrNull ?? '';
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.lyricsSaveLocation,
        normalTitleStyle: true,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...LyricsSaveLocation.values.map(
              (e) => _LyricsSaveLocationOption(
                location: e,
                subtitle: e == LyricsSaveLocation.customFolder ? saveFolder : '',
                onTap: () => _onLocationTap(e),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.lyricsSaveLocation,
      builder: (context, saveLocation) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.document_download,
        title: lang.lyricsSaveLocation,
        subtitle: lang.lyricsSaveLocationSubtitle,
        trailingText: saveLocation.toText(),
        onTap: _openLocationsDialog,
      ),
    );
  }
}

class _LyricsSaveLocationOption extends StatelessWidget {
  final LyricsSaveLocation location;
  final String subtitle;
  final void Function() onTap;

  const _LyricsSaveLocationOption({
    required this.location,
    required this.subtitle,
    required this.onTap,
  });

  void _onDeleteWithTrackTap() {
    settings.lyricsDeleteWithTrackIn.update((deleteIn) {
      final wasEnabled = deleteIn.remove(location);
      if (!wasEnabled) deleteIn.add(location);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Row(
        children: [
          Expanded(
            child: ObxO(
              rx: settings.lyricsSaveLocation,
              builder: (context, saveLocation) => ListTileWithCheckMark(
                active: saveLocation == location,
                title: location.toText(),
                subtitle: subtitle,
                onTap: onTap,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          ObxO(
            rx: settings.lyricsDeleteWithTrackIn,
            builder: (context, deleteIn) {
              final isEnabled = deleteIn.contains(location);
              return NamidaIconButton(
                tooltip: () => '${lang.lyricsDeleteWithTrack}\n${lang.lyricsDeleteWithTrackSubtitle}',
                icon: Broken.trash,
                iconSize: 20.0,
                iconColor: isEnabled ? Colors.red : theme.disabledColor,
                onPressed: _onDeleteWithTrackTap,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LyricsFoldersTile extends StatelessWidget {
  final Color? bgColor;
  final bool initiallyExpanded;

  const _LyricsFoldersTile({
    required this.bgColor,
    required this.initiallyExpanded,
  });

  void _onRemoveTap(String folder) {
    settings.lyricsFolders.update((list) => list.remove(folder));
    final isSaveFolderGone = settings.lyricsFolders.value.isEmpty && settings.lyricsSaveLocation.value == LyricsSaveLocation.customFolder;
    if (isSaveFolderGone) settings.lyricsSaveLocation.save(LyricsSaveLocation.cache);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Obx(
      (context) {
        final lyricsFolders = settings.lyricsFolders.valueR;
        final isSavingInFolder = settings.lyricsSaveLocation.valueR == LyricsSaveLocation.customFolder;
        final saveFolder = isSavingInFolder ? lyricsFolders.firstOrNull : null;
        return NamidaExpansionTile(
          bgColor: bgColor,
          bigahh: false,
          compact: false,
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          initiallyExpanded: initiallyExpanded,
          icon: Broken.folder_2,
          titleText: lang.lyricsFolders,
          subtitleText: lang.lyricsFoldersSubtitle,
          textColor: textTheme.displayLarge!.color,
          trailingBuilder: (iconWidget) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NamidaButton(
                icon: Broken.folder_add,
                text: lang.add,
                opaqueBG: true,
                onTap: _addLyricsFolder,
              ),
              iconWidget,
            ],
          ),
          children: [
            ...lyricsFolders.map(
              (e) => CustomListTile(
                extraDense: true,
                icon: Broken.folder,
                title: e,
                subtitle: e == saveFolder ? lang.lyricsSaveLocation : null,
                trailingRaw: NamidaTextButton(
                  minHeight: NamidaTextButton.kDefaultMinHeight * 0.8,
                  onTap: () => _onRemoveTap(e),
                  text: lang.remove.toUpperCase(),
                  fontSizeMultiplier: 0.92,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<bool> _addLyricsFolder() async {
  final hasPermission = await requestManageStoragePermission();
  if (!hasPermission) return false;
  final path = await NamidaFileBrowser.getDirectory(note: lang.lyricsFolders);
  if (path == null) return false;
  settings.lyricsFolders.update((list) => list.addNoDuplicates(path));
  return true;
}
