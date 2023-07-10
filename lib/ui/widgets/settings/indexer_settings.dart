import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class IndexerSettings extends StatelessWidget {
  const IndexerSettings({super.key});

  SettingsController get stg => SettingsController.inst;

  Future<void> _showRefreshPromptDialog() async {
    final currentFiles = await Indexer.inst.getAudioFiles();
    final newPathsLength = Indexer.inst.getNewFoundPaths(currentFiles).length;
    final deletedPathLength = Indexer.inst.getDeletedPaths(currentFiles).length;
    if (newPathsLength == 0 && deletedPathLength == 0) {
      Get.snackbar(Language.inst.NOTE, Language.inst.NO_CHANGES_FOUND);
      return;
    }
    NamidaNavigator.inst.navigateDialog(
      CustomBlurryDialog(
        title: Language.inst.NOTE,
        bodyText: Language.inst.PROMPT_INDEXING_REFRESH.replaceFirst('_NEW_FILES_', newPathsLength.toString()).replaceFirst(
              '_DELETED_FILES_',
              deletedPathLength.toString(),
            ),
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              await Future.delayed(const Duration(milliseconds: 300));
              await Indexer.inst.refreshLibraryAndCheckForDiff(currentFiles: currentFiles);
            },
            child: Text(Language.inst.REFRESH),
          ),
        ],
      ),
    );
  }

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
      child: Column(
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
                      value: allTracksInLibrary.length.toString(),
                      total: Indexer.inst.allAudioFiles.isEmpty ? null : Indexer.inst.allAudioFiles.length.toString(),
                    ),
                  ),
                  Obx(
                    () => StatsContainer(
                      icon: Broken.image,
                      title: '${Language.inst.ARTWORKS} :',
                      value: Indexer.inst.artworksInStorage.value.toString(),
                      total: Indexer.inst.allAudioFiles.isEmpty ? null : Indexer.inst.allAudioFiles.length.toString(),
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
              style: context.textTheme.displaySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Obx(
              () => Text(
                '${Language.inst.DUPLICATED_TRACKS}: ${Indexer.inst.duplicatedTracksLength.value}\n${Language.inst.TRACKS_EXCLUDED_BY_NOMEDIA}: ${Indexer.inst.tracksExcludedByNoMedia.value}\n${Language.inst.FILTERED_BY_SIZE_AND_DURATION}: ${Indexer.inst.filteredForSizeDurationTracks.value}',
                style: context.textTheme.displaySmall,
              ),
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.copy,
              title: Language.inst.PREVENT_DUPLICATED_TRACKS,
              subtitle: "${Language.inst.PREVENT_DUPLICATED_TRACKS_SUBTITLE}. ${Language.inst.INDEX_REFRESH_REQUIRED}",
              onChanged: (isTrue) => stg.save(preventDuplicatedTracks: !isTrue),
              value: stg.preventDuplicatedTracks.value,
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.cd,
              title: Language.inst.RESPECT_NO_MEDIA,
              subtitle: "${Language.inst.RESPECT_NO_MEDIA_SUBTITLE}. ${Language.inst.INDEX_REFRESH_REQUIRED}",
              onChanged: (isTrue) async {
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
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.microphone,
              title: Language.inst.EXTRACT_FEAT_ARTIST,
              subtitle: "${Language.inst.EXTRACT_FEAT_ARTIST_SUBTITLE} ${Language.inst.INSTANTLY_APPLIES}.",
              onChanged: (isTrue) async {
                stg.save(extractFeatArtistFromTitle: !isTrue);
                await Indexer.inst.prepareTracksFile();
              },
              value: stg.extractFeatArtistFromTitle.value,
            ),
          ),
          CustomListTile(
            icon: Broken.profile_2user,
            title: Language.inst.TRACK_ARTISTS_SEPARATOR,
            subtitle: Language.inst.INSTANTLY_APPLIES,
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
            subtitle: Language.inst.INSTANTLY_APPLIES,
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
              NamidaNavigator.inst.navigateDialog(
                CustomBlurryDialog(
                  normalTitleStyle: true,
                  isWarning: true,
                  actions: [
                    const CancelButton(),
                    ElevatedButton(
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
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
            onTap: () => _showRefreshPromptDialog(),
          ),
          Obx(
            () => NamidaExpansionTile(
              icon: Broken.folder,
              titleText: Language.inst.LIST_OF_FOLDERS,
              textColor: context.textTheme.displayLarge!.color,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AddFolderButton(
                    onPressed: () async {
                      final path = await FilePicker.platform.getDirectoryPath();
                      if (path != null) {
                        SettingsController.inst.save(directoriesToScan: [path]);
                        _showRefreshPromptDialog();
                      } else {
                        Get.snackbar(Language.inst.NOTE, Language.inst.NO_FOLDER_CHOSEN);
                      }
                    },
                  ),
                  const SizedBox(width: 8.0),
                  const Icon(Broken.arrow_down_2),
                ],
              ),
              children: [
                ...SettingsController.inst.directoriesToScan.map(
                  (e) => ListTile(
                    title: Text(
                      e,
                      style: context.textTheme.displayMedium,
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
                          NamidaNavigator.inst.navigateDialog(
                            CustomBlurryDialog(
                              normalTitleStyle: true,
                              title: Language.inst.WARNING,
                              icon: Broken.warning_2,
                              actions: [
                                const CancelButton(),
                                ElevatedButton(
                                    onPressed: () {
                                      SettingsController.inst.removeFromList(directoriesToScan1: e);
                                      NamidaNavigator.inst.closeDialog();
                                      _showRefreshPromptDialog();
                                    },
                                    child: Text(Language.inst.REMOVE)),
                              ],
                              child: Text(
                                "${Language.inst.REMOVE} \"$e\"?",
                                style: context.textTheme.displayMedium,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(Language.inst.REMOVE.toUpperCase()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => NamidaExpansionTile(
              icon: Broken.folder_minus,
              titleText: Language.inst.EXCLUDED_FODLERS,
              textColor: context.textTheme.displayLarge!.color,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AddFolderButton(
                    onPressed: () async {
                      final path = await FilePicker.platform.getDirectoryPath();
                      if (path != null) {
                        SettingsController.inst.save(directoriesToExclude: [path]);
                        _showRefreshPromptDialog();
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
                          style: context.textTheme.displayMedium,
                        ),
                      ),
                    ]
                  : [
                      ...SettingsController.inst.directoriesToExclude.map(
                        (e) => ListTile(
                          title: Text(
                            e,
                            style: context.textTheme.displayMedium,
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              SettingsController.inst.removeFromList(directoriesToExclude1: e);
                              _showRefreshPromptDialog();
                            },
                            child: Text(Language.inst.REMOVE.toUpperCase()),
                          ),
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  /// Automatically refreshes library after changing.
  /// no re-index required.
  Future<void> _showSeparatorSymbolsDialog(
    String title,
    RxList<String> itemsList, {
    bool trackArtistsSeparators = false,
    bool trackGenresSeparators = false,
    bool trackArtistsSeparatorsBlacklist = false,
    bool trackGenresSeparatorsBlacklist = false,
  }) async {
    final TextEditingController separatorsController = TextEditingController();
    final isBlackListDialog = trackArtistsSeparatorsBlacklist || trackGenresSeparatorsBlacklist;

    final RxBool updatingLibrary = false.obs;

    NamidaNavigator.inst.navigateDialog(
      durationInMs: 200,
      CustomBlurryDialog(
        title: title,
        onDismissing: isBlackListDialog
            ? null
            : () async {
                updatingLibrary.value = true;
                await Indexer.inst.prepareTracksFile();
              },
        actions: [
          if (!isBlackListDialog)
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
              child: Obx(() {
                final blLength =
                    trackArtistsSeparators ? SettingsController.inst.trackArtistsSeparatorsBlacklist.length : SettingsController.inst.trackGenresSeparatorsBlacklist.length;
                final t = blLength == 0 ? '' : ' ($blLength)';
                return Text('${Language.inst.BLACKLIST}$t');
              }),
            ),
          if (isBlackListDialog) const CancelButton(),
          Obx(
            () => updatingLibrary.value
                ? const LoadingIndicator()
                : ElevatedButton(
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
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBlackListDialog ? Language.inst.SEPARATORS_BLACKLIST_SUBTITLE : Language.inst.SEPARATORS_MESSAGE,
              style: Get.textTheme.displaySmall,
            ),
            const SizedBox(
              height: 12.0,
            ),
            Obx(
              () => Wrap(
                children: [
                  ...itemsList.map(
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
                            stg.removeFromList(trackArtistsSeparator: e);
                          }
                          if (trackGenresSeparators) {
                            stg.removeFromList(trackGenresSeparator: e);
                          }
                          if (trackArtistsSeparatorsBlacklist) {
                            stg.removeFromList(trackArtistsSeparatorsBlacklist1: e);
                          }
                          if (trackGenresSeparatorsBlacklist) {
                            stg.removeFromList(trackGenresSeparatorsBlacklist1: e);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(e),
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
                  ),
                ],
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
