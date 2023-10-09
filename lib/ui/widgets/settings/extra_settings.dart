import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
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

class ExtrasSettings extends StatelessWidget {
  const ExtrasSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.EXTRAS,
      subtitle: lang.EXTRAS_SUBTITLE,
      icon: Broken.command_square,
      child: Column(
        children: [
          const CollapsedSettingTileWidget(),
          Obx(
            () => CustomSwitchListTile(
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
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.screenmirroring,
              title: "${lang.ENABLE_PICTURE_IN_PICTURE} (${lang.BETA})",
              value: settings.enablePip.value,
              onChanged: (isTrue) => settings.save(enablePip: !isTrue),
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
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
          Obx(
            () => CustomListTile(
              icon: Broken.receipt_1,
              title: lang.DEFAULT_LIBRARY_TAB,
              trailingText: settings.autoLibraryTab.value ? lang.AUTO : settings.selectedLibraryTab.value.toText(),
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
                    width: Get.width,
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
          Obx(
            () {
              return CustomListTile(
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
              );
            },
          ),
          Obx(
            () => CustomListTile(
              icon: Broken.filter_search,
              title: lang.FILTER_TRACKS_BY,
              trailingText: "${settings.trackSearchFilter.length}",
              onTap: () => NamidaNavigator.inst.navigateDialog(
                dialog: Obx(
                  () {
                    return CustomBlurryDialog(
                      title: lang.FILTER_TRACKS_BY,
                      actions: [
                        IconButton(
                          icon: const Icon(Broken.refresh),
                          tooltip: lang.RESTORE_DEFAULTS,
                          onPressed: () {
                            settings.removeFromList(trackSearchFilterAll: [
                              'title',
                              'album',
                              'albumartist',
                              'artist',
                              'genre',
                              'composer',
                              'year',
                            ]);

                            settings.save(trackSearchFilter: ['title', 'artist', 'album']);
                          },
                        ),
                        NamidaButton(
                          text: lang.SAVE,
                          onPressed: NamidaNavigator.inst.closeDialog,
                        ),
                      ],
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.TITLE,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.title);
                              },
                              active: settings.trackSearchFilter.contains('title'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.ALBUM,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.album);
                              },
                              active: settings.trackSearchFilter.contains('album'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.ALBUM_ARTIST,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.albumartist);
                              },
                              active: settings.trackSearchFilter.contains('albumartist'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.ARTIST,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.artist);
                              },
                              active: settings.trackSearchFilter.contains('artist'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.GENRE,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.genre);
                              },
                              active: settings.trackSearchFilter.contains('genre'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.COMPOSER,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.composer);
                              },
                              active: settings.trackSearchFilter.contains('composer'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: lang.YEAR,
                              onTap: () => _trackFilterOnTap(TrackSearchFilter.year),
                              active: settings.trackSearchFilter.contains('year'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.document_filter,
              title: lang.ENABLE_SEARCH_CLEANUP,
              subtitle: lang.ENABLE_SEARCH_CLEANUP_SUBTITLE,
              value: settings.enableSearchCleanup.value,
              onChanged: (p0) => settings.save(enableSearchCleanup: !p0),
            ),
          ),
          CustomListTile(
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
        ],
      ),
    );
  }

  void _trackFilterOnTap(TrackSearchFilter filter) {
    String type = '';
    switch (filter) {
      case TrackSearchFilter.title:
        type = 'title';
        break;
      case TrackSearchFilter.album:
        type = 'album';
        break;
      case TrackSearchFilter.albumartist:
        type = 'albumartist';
        break;
      case TrackSearchFilter.artist:
        type = 'artist';
        break;

      case TrackSearchFilter.genre:
        type = 'genre';
        break;
      case TrackSearchFilter.composer:
        type = 'composer';
        break;
      case TrackSearchFilter.year:
        type = 'year';
        break;
      default:
        null;
    }

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
