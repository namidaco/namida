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
      title: Language.inst.EXTRAS,
      subtitle: Language.inst.EXTRAS_SUBTITLE,
      icon: Broken.command_square,
      child: Column(
        children: [
          const CollapsedSettingTileWidget(),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.direct,
              title: Language.inst.ENABLE_BOTTOM_NAV_BAR,
              subtitle: Language.inst.ENABLE_BOTTOM_NAV_BAR_SUBTITLE,
              value: SettingsController.inst.enableBottomNavBar.value,
              onChanged: (p0) {
                SettingsController.inst.save(enableBottomNavBar: !p0);
                MiniPlayerController.inst.updateBottomNavBarRelatedDimensions(!p0);
              },
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.video_square,
              title: Language.inst.USE_YOUTUBE_MINIPLAYER,
              value: SettingsController.inst.useYoutubeMiniplayer.value,
              onChanged: (p0) => SettingsController.inst.save(useYoutubeMiniplayer: !p0),
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.folder_open,
              title: Language.inst.ENABLE_FOLDERS_HIERARCHY,
              value: SettingsController.inst.enableFoldersHierarchy.value,
              onChanged: (p0) {
                SettingsController.inst.save(enableFoldersHierarchy: !p0);
                Folders.inst.isHome.value = true;
                Folders.inst.isInside.value = false;
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              icon: Broken.receipt_1,
              title: Language.inst.DEFAULT_LIBRARY_TAB,
              trailingText: SettingsController.inst.autoLibraryTab.value ? Language.inst.AUTO : SettingsController.inst.selectedLibraryTab.value.toText(),
              onTap: () => NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: Language.inst.DEFAULT_LIBRARY_TAB,
                  actions: [
                    NamidaButton(
                      text: Language.inst.DONE,
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
                              title: Language.inst.AUTO,
                              icon: Broken.recovery_convert,
                              onTap: () => SettingsController.inst.save(autoLibraryTab: true),
                              active: SettingsController.inst.autoLibraryTab.value,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        ...SettingsController.inst.libraryTabs.asMap().entries.map(
                              (e) => Obx(
                                () => Container(
                                  margin: const EdgeInsets.all(4.0),
                                  child: ListTileWithCheckMark(
                                    title: "${e.key + 1}. ${e.value.toText()}",
                                    icon: e.value.toIcon(),
                                    onTap: () {
                                      SettingsController.inst.save(
                                        selectedLibraryTab: e.value,
                                        staticLibraryTab: e.value,
                                        autoLibraryTab: false,
                                      );
                                    },
                                    active: SettingsController.inst.selectedLibraryTab.value == e.value,
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
                title: Language.inst.LIBRARY_TABS,
                trailingText: "${SettingsController.inst.libraryTabs.length}",
                onTap: () => NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: Language.inst.LIBRARY_TABS,
                    actions: [
                      NamidaButton(
                        text: Language.inst.DONE,
                        onPressed: NamidaNavigator.inst.closeDialog,
                      ),
                    ],
                    child: Obx(
                      () {
                        final subList = <LibraryTab>[].obs;

                        LibraryTab.values.loop((e, index) {
                          if (!SettingsController.inst.libraryTabs.contains(e)) {
                            subList.add(e);
                          }
                        });

                        return Column(
                          children: [
                            Text(
                              Language.inst.LIBRARY_TABS_REORDER,
                              style: context.textTheme.displayMedium,
                            ),
                            const SizedBox(height: 12.0),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: SettingsController.inst.libraryTabs.length,
                              itemBuilder: (context, i) {
                                final tab = SettingsController.inst.libraryTabs[i];
                                return Container(
                                  key: ValueKey(i),
                                  margin: const EdgeInsets.all(4.0),
                                  child: ListTileWithCheckMark(
                                    title: "${i + 1}. ${tab.toText()}",
                                    icon: tab.toIcon(),
                                    onTap: () {
                                      if (SettingsController.inst.libraryTabs.length > 3) {
                                        SettingsController.inst.removeFromList(libraryTab1: tab);
                                        SettingsController.inst.save(selectedLibraryTab: SettingsController.inst.libraryTabs[0]);
                                      } else {
                                        showMinimumItemsSnack(3);
                                      }
                                    },
                                    active: SettingsController.inst.libraryTabs.contains(tab),
                                  ),
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final item = SettingsController.inst.libraryTabs.elementAt(oldIndex);
                                SettingsController.inst.removeFromList(
                                  libraryTab1: item,
                                );
                                SettingsController.inst.insertInList(newIndex, libraryTab1: item);
                              },
                            ),
                            const NamidaContainerDivider(height: 4.0, margin: EdgeInsets.symmetric(vertical: 4.0)),
                            const SizedBox(height: 8.0),
                            ...subList.asMap().entries.map(
                                  (e) => Column(
                                    key: UniqueKey(),
                                    children: [
                                      ListTileWithCheckMark(
                                        title: "${e.key + 1}. ${e.value.toText()}",
                                        icon: e.value.toIcon(),
                                        onTap: () => SettingsController.inst.save(libraryTabs: [e.value]),
                                        active: SettingsController.inst.libraryTabs.contains(e.value),
                                      ),
                                      const SizedBox(height: 8.0),
                                    ],
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Obx(
            () => CustomListTile(
              icon: Broken.filter_search,
              title: Language.inst.FILTER_TRACKS_BY,
              trailingText: "${SettingsController.inst.trackSearchFilter.length}",
              onTap: () => NamidaNavigator.inst.navigateDialog(
                dialog: Obx(
                  () {
                    return CustomBlurryDialog(
                      title: Language.inst.FILTER_TRACKS_BY,
                      actions: [
                        IconButton(
                          icon: const Icon(Broken.refresh),
                          tooltip: Language.inst.RESTORE_DEFAULTS,
                          onPressed: () {
                            SettingsController.inst.removeFromList(trackSearchFilterAll: [
                              'title',
                              'album',
                              'albumartist',
                              'artist',
                              'genre',
                              'composer',
                              'year',
                            ]);

                            SettingsController.inst.save(trackSearchFilter: ['title', 'artist', 'album']);
                          },
                        ),
                        NamidaButton(
                          text: Language.inst.SAVE,
                          onPressed: NamidaNavigator.inst.closeDialog,
                        ),
                      ],
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.TITLE,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.title);
                              },
                              active: SettingsController.inst.trackSearchFilter.contains('title'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.ALBUM,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.album);
                              },
                              active: SettingsController.inst.trackSearchFilter.contains('album'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.ALBUM_ARTIST,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.albumartist);
                              },
                              active: SettingsController.inst.trackSearchFilter.contains('albumartist'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.ARTIST,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.artist);
                              },
                              active: SettingsController.inst.trackSearchFilter.contains('artist'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.GENRE,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.genre);
                              },
                              active: SettingsController.inst.trackSearchFilter.contains('genre'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.COMPOSER,
                              onTap: () {
                                _trackFilterOnTap(TrackSearchFilter.composer);
                              },
                              active: SettingsController.inst.trackSearchFilter.contains('composer'),
                            ),
                            const SizedBox(height: 12.0),
                            ListTileWithCheckMark(
                              title: Language.inst.YEAR,
                              onTap: () => _trackFilterOnTap(TrackSearchFilter.year),
                              active: SettingsController.inst.trackSearchFilter.contains('year'),
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
              title: Language.inst.ENABLE_SEARCH_CLEANUP,
              subtitle: Language.inst.ENABLE_SEARCH_CLEANUP_SUBTITLE,
              value: SettingsController.inst.enableSearchCleanup.value,
              onChanged: (p0) => SettingsController.inst.save(enableSearchCleanup: !p0),
            ),
          ),
          CustomListTile(
            icon: Broken.colorfilter,
            title: Language.inst.EXTRACT_ALL_COLOR_PALETTES,
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
                    title: Language.inst.NOTE,
                    bodyText: Language.inst.FORCE_STOP_COLOR_PALETTE_GENERATION,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: Language.inst.STOP,
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
                    title: Language.inst.NOTE,
                    bodyText: Language.inst.EXTRACT_ALL_COLOR_PALETTES_SUBTITLE
                        .replaceFirst('_REMAINING_COLOR_PALETTES_', '${allTracksInLibrary.length - Indexer.inst.colorPalettesInStorage.value}'),
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: Language.inst.EXTRACT,
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

    final canRemove = SettingsController.inst.trackSearchFilter.length > 1;

    if (SettingsController.inst.trackSearchFilter.contains(type)) {
      if (canRemove) {
        SettingsController.inst.removeFromList(trackSearchFilter1: type);
      } else {
        showMinimumItemsSnack(1);
      }
    } else {
      SettingsController.inst.save(trackSearchFilter: [type]);
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
