import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _ExtraSettingsKeys {
  collapsedTiles,
  bottomNavBar,
  pip,
  foldersHierarchy,
  fabType,
  defaultLibraryTab,
  libraryTabs,
  filterTracksBy,
  searchCleanup,
  prioritizeEmbeddedLyrics,
  immersiveMode,
  swipeToOpenDrawer,
  enableClipboardMonitoring,
  extractAllPalettes,
}

class ExtrasSettings extends SettingSubpageProvider {
  const ExtrasSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.extra;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _ExtraSettingsKeys.collapsedTiles: [lang.USE_COLLAPSED_SETTING_TILES],
        _ExtraSettingsKeys.bottomNavBar: [lang.ENABLE_BOTTOM_NAV_BAR, lang.ENABLE_BOTTOM_NAV_BAR_SUBTITLE],
        _ExtraSettingsKeys.pip: [lang.ENABLE_PICTURE_IN_PICTURE],
        _ExtraSettingsKeys.foldersHierarchy: [lang.ENABLE_FOLDERS_HIERARCHY],
        _ExtraSettingsKeys.defaultLibraryTab: [lang.DEFAULT_LIBRARY_TAB],
        _ExtraSettingsKeys.fabType: [lang.FLOATING_ACTION_BUTTON],
        _ExtraSettingsKeys.libraryTabs: [lang.LIBRARY_TABS],
        _ExtraSettingsKeys.filterTracksBy: [lang.FILTER_TRACKS_BY],
        _ExtraSettingsKeys.searchCleanup: [lang.ENABLE_SEARCH_CLEANUP, lang.ENABLE_SEARCH_CLEANUP_SUBTITLE],
        _ExtraSettingsKeys.prioritizeEmbeddedLyrics: [lang.PRIORITIZE_EMBEDDED_LYRICS],
        _ExtraSettingsKeys.immersiveMode: [lang.IMMERSIVE_MODE, lang.IMMERSIVE_MODE_SUBTITLE],
        _ExtraSettingsKeys.swipeToOpenDrawer: [lang.SWIPE_TO_OPEN_DRAWER],
        _ExtraSettingsKeys.enableClipboardMonitoring: [lang.ENABLE_CLIPBOARD_MONITORING, lang.ENABLE_CLIPBOARD_MONITORING_SUBTITLE],
        _ExtraSettingsKeys.extractAllPalettes: [lang.EXTRACT_ALL_COLOR_PALETTES],
      };

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.EXTRAS,
      subtitle: lang.EXTRAS_SUBTITLE,
      icon: Broken.command_square,
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
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.bottomNavBar),
                icon: Broken.direct,
                title: lang.ENABLE_BOTTOM_NAV_BAR,
                subtitle: lang.ENABLE_BOTTOM_NAV_BAR_SUBTITLE,
                value: settings.enableBottomNavBar.value,
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
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.pip),
                icon: Broken.screenmirroring,
                title: lang.ENABLE_PICTURE_IN_PICTURE,
                value: settings.enablePip.value,
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
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.foldersHierarchy),
                icon: Broken.folder_open,
                title: lang.ENABLE_FOLDERS_HIERARCHY,
                value: settings.enableFoldersHierarchy.value,
                onChanged: (p0) {
                  settings.save(enableFoldersHierarchy: !p0);
                  Folders.inst.isHome.value = true;
                  Folders.inst.isInside.value = false;
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.fabType,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.fabType),
                icon: Broken.safe_home,
                title: lang.FLOATING_ACTION_BUTTON,
                trailingText: settings.floatingActionButton.value.toText(),
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.FLOATING_ACTION_BUTTON,
                      actions: [
                        NamidaButton(
                          text: lang.DONE,
                          onPressed: NamidaNavigator.inst.closeDialog,
                        ),
                      ],
                      child: SizedBox(
                        width: context.width,
                        child: Column(
                          children: FABType.values
                              .map(
                                (e) => Obx(
                                  () => Container(
                                    margin: const EdgeInsets.all(4.0),
                                    child: ListTileWithCheckMark(
                                      title: e.toText(),
                                      icon: e.toIcon(),
                                      active: settings.floatingActionButton.value == e,
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
              () => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.defaultLibraryTab),
                icon: Broken.receipt_1,
                title: lang.DEFAULT_LIBRARY_TAB,
                trailingText: settings.autoLibraryTab.value ? lang.AUTO : settings.staticLibraryTab.value.toText(),
                onTap: () => NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.DEFAULT_LIBRARY_TAB,
                    actions: [
                      NamidaButton(
                        text: lang.DONE,
                        onPressed: NamidaNavigator.inst.closeDialog,
                      ),
                    ],
                    child: SizedBox(
                      width: context.width,
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(4.0),
                            child: Obx(
                              () => ListTileWithCheckMark(
                                title: lang.AUTO,
                                icon: Broken.recovery_convert,
                                onTap: () => settings.save(autoLibraryTab: true),
                                active: settings.autoLibraryTab.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          ...settings.libraryTabs.asMap().entries.map(
                                (e) => Obx(
                                  () => Container(
                                    margin: const EdgeInsets.all(4.0),
                                    child: ListTileWithCheckMark(
                                      title: "${e.key + 1}. ${e.value.toText()}",
                                      icon: e.value.toIcon(),
                                      onTap: () {
                                        settings.save(
                                          selectedLibraryTab: e.value,
                                          staticLibraryTab: e.value,
                                          autoLibraryTab: false,
                                        );
                                      },
                                      active: settings.selectedLibraryTab.value == e.value,
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
              () => CustomListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.filterTracksBy),
                icon: Broken.filter_search,
                title: lang.FILTER_TRACKS_BY,
                trailingText: "${settings.trackSearchFilter.length}",
                onTap: () => NamidaNavigator.inst.navigateDialog(
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
                      NamidaButton(
                        text: lang.DONE,
                        onPressed: NamidaNavigator.inst.closeDialog,
                      ),
                    ],
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...TrackSearchFilter.values.map(
                            (e) => Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Obx(
                                () => ListTileWithCheckMark(
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
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.searchCleanup,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.searchCleanup),
                icon: Broken.document_filter,
                title: lang.ENABLE_SEARCH_CLEANUP,
                subtitle: lang.ENABLE_SEARCH_CLEANUP_SUBTITLE,
                value: settings.enableSearchCleanup.value,
                onChanged: (p0) => settings.save(enableSearchCleanup: !p0),
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.prioritizeEmbeddedLyrics,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.prioritizeEmbeddedLyrics),
                icon: Broken.mobile_programming,
                title: lang.PRIORITIZE_EMBEDDED_LYRICS,
                value: settings.prioritizeEmbeddedLyrics.value,
                onChanged: (p0) => settings.save(prioritizeEmbeddedLyrics: !p0),
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.immersiveMode,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.immersiveMode),
                icon: Broken.external_drive,
                title: lang.IMMERSIVE_MODE,
                subtitle: lang.IMMERSIVE_MODE_SUBTITLE,
                value: settings.hideStatusBarInExpandedMiniplayer.value,
                onChanged: (p0) => settings.save(hideStatusBarInExpandedMiniplayer: !p0),
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.swipeToOpenDrawer,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.swipeToOpenDrawer),
                icon: Broken.sidebar_right,
                title: lang.SWIPE_TO_OPEN_DRAWER,
                value: settings.swipeableDrawer.value,
                onChanged: (isTrue) {
                  settings.save(swipeableDrawer: !isTrue);
                  NamidaNavigator.inst.innerDrawerKey.currentState?.toggleCanSwipe(!isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.enableClipboardMonitoring,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_ExtraSettingsKeys.enableClipboardMonitoring),
                icon: Broken.clipboard_export,
                title: lang.ENABLE_CLIPBOARD_MONITORING,
                subtitle: lang.ENABLE_CLIPBOARD_MONITORING_SUBTITLE,
                value: settings.enableClipboardMonitoring.value,
                onChanged: (isTrue) {
                  settings.save(enableClipboardMonitoring: !isTrue);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _ExtraSettingsKeys.extractAllPalettes,
            child: CustomListTile(
              bgColor: getBgColor(_ExtraSettingsKeys.extractAllPalettes),
              icon: Broken.colorfilter,
              title: lang.EXTRACT_ALL_COLOR_PALETTES,
              trailing: Obx(
                () => Column(
                  children: [
                    Text("${Indexer.inst.colorPalettesInStorage.value}/${Indexer.inst.artworksInStorage.value}"),
                    if (CurrentColor.inst.isGeneratingAllColorPalettes.value) const LoadingIndicator(),
                  ],
                ),
              ),
              onTap: () async {
                if (CurrentColor.inst.isGeneratingAllColorPalettes.value) {
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
                          .replaceFirst('_REMAINING_COLOR_PALETTES_', '${allTracksInLibrary.length - Indexer.inst.colorPalettesInStorage.value}'),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget getLibraryTabsTile(BuildContext context) {
    return getItemWrapper(
      key: _ExtraSettingsKeys.libraryTabs,
      child: Obx(
        () => CustomListTile(
          bgColor: getBgColor(_ExtraSettingsKeys.libraryTabs),
          icon: Broken.color_swatch,
          title: lang.LIBRARY_TABS,
          trailingText: "${settings.libraryTabs.length}",
          onTap: () {
            final subList = <LibraryTab>[].obs;

            LibraryTab.values.loop((e, index) {
              if (!settings.libraryTabs.contains(e)) {
                subList.add(e);
              }
            });

            NamidaNavigator.inst.navigateDialog(
              onDisposing: () {
                subList.close();
              },
              dialog: CustomBlurryDialog(
                title: lang.LIBRARY_TABS,
                actions: [
                  NamidaButton(
                    text: lang.DONE,
                    onPressed: NamidaNavigator.inst.closeDialog,
                  ),
                ],
                child: SizedBox(
                  width: Get.width,
                  height: Get.height * 0.5,
                  child: Obx(
                    () => Column(
                      children: [
                        Text(
                          lang.LIBRARY_TABS_REORDER,
                          style: context.textTheme.displayMedium,
                        ),
                        const SizedBox(height: 12.0),
                        Expanded(
                          flex: 6,
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            proxyDecorator: (child, index, animation) => child,
                            padding: EdgeInsets.zero,
                            itemCount: settings.libraryTabs.length,
                            itemBuilder: (context, i) {
                              final tab = settings.libraryTabs[i];
                              return Container(
                                key: ValueKey(i),
                                margin: const EdgeInsets.all(4.0),
                                child: ListTileWithCheckMark(
                                  title: "${i + 1}. ${tab.toText()}",
                                  icon: tab.toIcon(),
                                  onTap: () {
                                    if (settings.libraryTabs.length > 3) {
                                      settings.removeFromList(libraryTab1: tab);
                                      settings.save(selectedLibraryTab: settings.libraryTabs[0]);
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
                              final item = settings.libraryTabs.elementAt(oldIndex);
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
                            child: ListView.builder(
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

    if (settings.trackSearchFilter.contains(type)) {
      if (canRemove) {
        settings.removeFromList(trackSearchFilter1: type);
      } else {
        showMinimumItemsSnack(1);
      }
    } else {
      settings.save(trackSearchFilter: [type]);
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
