import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/circular_percentages.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class IndexerSettings extends StatelessWidget {
  IndexerSettings({super.key});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.INDEXER,
      subtitle: Language.inst.INDEXER_SUBTITLE,
      icon: Broken.component,
      trailing: const SizedBox(
        height: 48.0,
        child: IndexingPercentage(),
      ),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 50,
              child: FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Obx(
                      () => StatsContainer(
                        icon: Broken.info_circle,
                        title: '${Language.inst.TRACKS_INFO} :',
                        value: Indexer.inst.tracksInfoList.length.toString(),
                        total: Indexer.inst.allTracksPaths.value == 0 ? null : Indexer.inst.allTracksPaths.toString(),
                      ),
                    ),
                    Obx(
                      () => StatsContainer(
                        icon: Broken.image,
                        title: '${Language.inst.ARTWORKS} :',
                        value: Indexer.inst.artworksInStorage.value.toString(),
                        total: Indexer.inst.allTracksPaths.value == 0 ? null : Indexer.inst.allTracksPaths.toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                Language.inst.INDEXER_NOTE,
                style: Get.textTheme.displaySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Obx(
                () => Text(
                  '${Language.inst.DUPLICATED_TRACKS}: ${Indexer.inst.duplicatedTracksLength.value}',
                  style: Get.textTheme.displaySmall,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Obx(
                () => Text(
                  '${Language.inst.FILTERED_BY_SIZE_AND_DURATION}: ${Indexer.inst.filteredForSizeDurationTracks.value}',
                  style: Get.textTheme.displaySmall,
                ),
              ),
            ),
            CustomSwitchListTile(
              icon: Broken.copy,
              title: Language.inst.PREVENT_DUPLICATED_TRACKS,
              subtitle: "${Language.inst.PREVENT_DUPLICATED_TRACKS_SUBTITLE}. ${Language.inst.INDEX_REFRESH_REQUIRED}",
              onChanged: (p0) {
                stg.save(preventDuplicatedTracks: !p0);
              },
              value: stg.preventDuplicatedTracks.value,
            ),
            CustomSwitchListTile(
              icon: Broken.cd,
              title: Language.inst.RESPECT_NO_MEDIA,
              subtitle: "${Language.inst.RESPECT_NO_MEDIA_SUBTITLE}. ${Language.inst.INDEX_REFRESH_REQUIRED}",
              onChanged: (p0) async {
                if (!stg.respectNoMedia.value) {
                  if (await requestManageStoragePermission()) {
                    stg.save(respectNoMedia: true);
                  }
                } else {
                  stg.save(respectNoMedia: false);
                }
              },
              value: stg.respectNoMedia.value,
            ),
            CustomListTile(
              icon: Broken.profile_2user,
              title: Language.inst.TRACK_ARTISTS_SEPARATOR,
              subtitle: Language.inst.RE_INDEXING_REQUIRED,
              trailingText: "${stg.trackArtistsSeparators.length}",
              onTap: () async {
                await _showSeparatorSymbolsDialog(
                  Language.inst.TRACK_ARTISTS_SEPARATOR,
                  stg.trackArtistsSeparators,
                  trackArtistsSeparators: true,
                );
              },
            ),
            CustomListTile(
              icon: Broken.smileys,
              title: Language.inst.TRACK_GENRES_SEPARATOR,
              subtitle: Language.inst.RE_INDEXING_REQUIRED,
              trailingText: "${stg.trackGenresSeparators.length}",
              onTap: () async {
                await _showSeparatorSymbolsDialog(
                  Language.inst.TRACK_GENRES_SEPARATOR,
                  stg.trackGenresSeparators,
                  trackGenresSeparators: true,
                );
              },
            ),
            Obx(
              () => CustomListTile(
                icon: Broken.unlimited,
                title: Language.inst.MIN_FILE_SIZE,
                subtitle: Language.inst.INDEX_REFRESH_REQUIRED,
                trailing: NamidaWheelSlider(
                  width: 100.0,
                  totalCount: 1024,
                  squeeze: 0.2,
                  initValue: SettingsController.inst.indexMinFileSizeInB.value.toInt() / 1024 ~/ 10,
                  itemSize: 1,
                  onValueChanged: (val) {
                    final d = (val as int);
                    SettingsController.inst.save(indexMinFileSizeInB: d * 1024 * 10);
                  },
                  text: SettingsController.inst.indexMinFileSizeInB.value.fileSizeFormatted,
                ),
              ),
            ),
            Obx(
              () => CustomListTile(
                icon: Broken.timer_1,
                title: Language.inst.MIN_FILE_DURATION,
                subtitle: Language.inst.INDEX_REFRESH_REQUIRED,
                trailing: NamidaWheelSlider(
                  width: 100.0,
                  totalCount: 180,
                  initValue: SettingsController.inst.indexMinDurationInSec.value,
                  itemSize: 5,
                  onValueChanged: (val) {
                    final d = (val as int);
                    SettingsController.inst.save(indexMinDurationInSec: d);
                  },
                  text: "${SettingsController.inst.indexMinDurationInSec.value} s",
                ),
              ),
            ),
            CustomListTile(
              icon: Broken.refresh,
              title: Language.inst.RE_INDEX,
              subtitle: Language.inst.RE_INDEX_SUBTITLE,
              onTap: () async {
                await Get.dialog(
                  CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                          onPressed: () async {
                            Get.close(1);
                            Future.delayed(const Duration(milliseconds: 500), () {
                              Indexer.inst.refreshLibraryAndCheckForDiff(forceReIndex: true);
                            });
                          },
                          child: Text(Language.inst.RE_INDEX)),
                    ],
                    bodyText: Language.inst.RE_INDEX_WARNING,
                  ),
                );
              },
            ),
            CustomListTile(
              icon: Broken.refresh_2,
              title: Language.inst.REFRESH_LIBRARY,
              subtitle: Language.inst.REFRESH_LIBRARY_SUBTITLE,
              onTap: () {
                Indexer.inst.refreshLibraryAndCheckForDiff();
              },
            ),
            Obx(
              () => ExpansionTile(
                leading: const Icon(Broken.folder),
                title: Text(Language.inst.LIST_OF_FOLDERS),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AddFolderButton(
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath();
                        if (path != null) {
                          SettingsController.inst.save(directoriesToScan: [path]);
                          Indexer.inst.refreshLibraryAndCheckForDiff();
                        } else {
                          Get.snackbar(Language.inst.NOTE, Language.inst.NO_FOLDER_CHOSEN);
                        }
                      },
                    ),
                    const SizedBox(width: 8.0),
                    const Icon(Broken.arrow_down_2),
                  ],
                ),
                children: SettingsController.inst.directoriesToScan
                    .asMap()
                    .entries
                    .map((e) => ListTile(
                          title: Text(
                            e.value,
                            style: Get.textTheme.displayMedium,
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              if (SettingsController.inst.directoriesToScan.length == 1) {
                                Get.snackbar(
                                  Language.inst.MINIMUM_ONE_FOLDER,
                                  Language.inst.MINIMUM_ONE_FOLDER_SUBTITLE,
                                  duration: const Duration(seconds: 4),
                                );
                              } else {
                                Get.dialog(
                                  CustomBlurryDialog(
                                    normalTitleStyle: true,
                                    title: Language.inst.WARNING,
                                    icon: Broken.warning_2,
                                    actions: [
                                      const CancelButton(),
                                      ElevatedButton(
                                          onPressed: () {
                                            SettingsController.inst.removeFromList(directoriesToScan1: e.value);
                                            Indexer.inst.refreshLibraryAndCheckForDiff();
                                            Get.close(1);
                                          },
                                          child: Text(Language.inst.REMOVE)),
                                    ],
                                    child: Text(
                                      "${Language.inst.REMOVE} \"${e.value}\"?",
                                      style: Get.textTheme.displayMedium,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(Language.inst.REMOVE.toUpperCase()),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Obx(
              () => ExpansionTile(
                leading: const Icon(Broken.folder_minus),
                title: Text(Language.inst.EXCLUDED_FODLERS),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AddFolderButton(
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath();
                        if (path != null) {
                          SettingsController.inst.save(directoriesToExclude: [path]);
                          Indexer.inst.refreshLibraryAndCheckForDiff();
                        } else {
                          Get.snackbar(Language.inst.NOTE, Language.inst.NO_FOLDER_CHOSEN);
                        }
                      },
                    ),
                    const SizedBox(width: 8.0),
                    const Icon(Broken.arrow_down_2),
                  ],
                ),
                children: SettingsController.inst.directoriesToExclude.isEmpty
                    ? [
                        ListTile(
                            title: Text(
                          Language.inst.NO_EXCLUDED_FOLDERS,
                          style: Get.textTheme.displayMedium,
                        ))
                      ]
                    : SettingsController.inst.directoriesToExclude
                        .asMap()
                        .entries
                        .map((e) => ListTile(
                              title: Text(
                                e.value,
                                style: Get.textTheme.displayMedium,
                              ),
                              trailing: TextButton(
                                onPressed: () {
                                  SettingsController.inst.removeFromList(directoriesToExclude1: e.value);
                                  Indexer.inst.refreshLibraryAndCheckForDiff();
                                },
                                child: Text(Language.inst.REMOVE.toUpperCase()),
                              ),
                            ))
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSeparatorSymbolsDialog(
    String title,
    RxList<String> itemsList, {
    bool trackArtistsSeparators = false,
    bool trackGenresSeparators = false,
    bool trackArtistsSeparatorsBlacklist = false,
    bool trackGenresSeparatorsBlacklist = false,
  }) async {
    TextEditingController separatorsController = TextEditingController();
    await Get.dialog(
      transitionDuration: const Duration(milliseconds: 200),
      CustomBlurryDialog(
        title: title,
        actions: [
          if (!(trackArtistsSeparatorsBlacklist || trackGenresSeparatorsBlacklist))
            ElevatedButton(
              onPressed: () {
                if (trackArtistsSeparators) {
                  _showSeparatorSymbolsDialog(
                    Language.inst.BLACKLIST,
                    SettingsController.inst.trackArtistsSeparatorsBlacklist,
                    trackArtistsSeparatorsBlacklist: true,
                  );
                }
                if (trackGenresSeparators) {
                  _showSeparatorSymbolsDialog(
                    Language.inst.BLACKLIST,
                    SettingsController.inst.trackGenresSeparatorsBlacklist,
                    trackGenresSeparatorsBlacklist: true,
                  );
                }
              },
              child: Text(Language.inst.BLACKLIST),
            ),
          const CancelButton(),
          ElevatedButton(
            onPressed: () {
              if (separatorsController.text.isNotEmpty) {
                if (trackArtistsSeparators) {
                  stg.save(trackArtistsSeparators: [separatorsController.text]);
                }
                if (trackGenresSeparators) {
                  stg.save(trackGenresSeparators: [separatorsController.text]);
                }
                if (trackArtistsSeparatorsBlacklist) {
                  stg.save(trackArtistsSeparatorsBlacklist: [separatorsController.text]);
                }
                if (trackGenresSeparatorsBlacklist) {
                  stg.save(trackGenresSeparatorsBlacklist: [separatorsController.text]);
                }
                separatorsController.clear();
              } else {
                Get.snackbar(Language.inst.EMPTY_VALUE, Language.inst.ENTER_SYMBOL, forwardAnimationCurve: Curves.fastLinearToSlowEaseIn);
              }
            },
            child: Text(Language.inst.ADD),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!(trackArtistsSeparatorsBlacklist || trackGenresSeparatorsBlacklist))
              Text(
                Language.inst.SEPARATORS_MESSAGE,
                style: Get.textTheme.displaySmall,
              ),
            const SizedBox(
              height: 12.0,
            ),
            Obx(
              () => Wrap(
                children: itemsList
                    .asMap()
                    .entries
                    .map(
                      (e) => Container(
                        margin: const EdgeInsets.all(4.0),
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                        decoration: BoxDecoration(
                          color: Get.theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (trackArtistsSeparators) {
                              stg.removeFromList(trackArtistsSeparator: e.value);
                            }
                            if (trackGenresSeparators) {
                              stg.removeFromList(trackGenresSeparator: e.value);
                            }
                            if (trackArtistsSeparatorsBlacklist) {
                              stg.removeFromList(trackArtistsSeparatorsBlacklist1: e.value);
                            }
                            if (trackGenresSeparatorsBlacklist) {
                              stg.removeFromList(trackGenresSeparatorsBlacklist1: e.value);
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.value),
                              const SizedBox(
                                width: 6.0,
                              ),
                              const Icon(
                                Broken.close_circle,
                                size: 18.0,
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(
              height: 24.0,
            ),
            TextField(
              decoration: InputDecoration(
                errorMaxLines: 3,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                  borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                  borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
                ),
                hintText: Language.inst.VALUE,
              ),
              controller: separatorsController,
            )
          ],
        ),
      ),
    );
  }
}
