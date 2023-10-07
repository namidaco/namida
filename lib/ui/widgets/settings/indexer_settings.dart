import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class IndexerSettings extends StatelessWidget {
  const IndexerSettings({super.key});

  Future<void> _showRefreshPromptDialog(bool didModifyFolder) async {
    _RefreshLibraryIcon.controller.repeat();
    final currentFiles = await Indexer.inst.getAudioFiles(forceReCheckDirs: didModifyFolder);
    final newPathsLength = Indexer.inst.getNewFoundPaths(currentFiles).length;
    final deletedPathLength = Indexer.inst.getDeletedPaths(currentFiles).length;
    if (newPathsLength == 0 && deletedPathLength == 0) {
      snackyy(title: lang.NOTE, message: lang.NO_CHANGES_FOUND);
    } else {
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          title: lang.NOTE,
          bodyText: lang.PROMPT_INDEXING_REFRESH
              .replaceFirst(
                '_NEW_FILES_',
                newPathsLength.toString(),
              )
              .replaceFirst(
                '_DELETED_FILES_',
                deletedPathLength.toString(),
              ),
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.REFRESH,
              onPressed: () async {
                NamidaNavigator.inst.closeDialog();
                await Future.delayed(const Duration(milliseconds: 300));
                await Indexer.inst.refreshLibraryAndCheckForDiff(currentFiles: currentFiles);
              },
            ),
          ],
        ),
      );
    }

    await _RefreshLibraryIcon.controller.fling(velocity: 0.6);
    _RefreshLibraryIcon.controller.stop();
  }

  Widget addFolderButton(void Function(String dirPath) onSuccessChoose) {
    return NamidaButton(
      icon: Broken.folder_add,
      text: lang.ADD,
      onPressed: () async {
        final path = await FilePicker.platform.getDirectoryPath();
        if (path == null) {
          snackyy(title: lang.NOTE, message: lang.NO_FOLDER_CHOSEN);
          return;
        }

        onSuccessChoose(path);
        _showRefreshPromptDialog(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.INDEXER,
      subtitle: lang.INDEXER_SUBTITLE,
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
                      title: '${lang.TRACKS_INFO} :',
                      value: allTracksInLibrary.length.formatDecimal(),
                      total: Indexer.inst.allAudioFiles.isEmpty ? null : Indexer.inst.allAudioFiles.length.formatDecimal(),
                    ),
                  ),
                  Obx(
                    () => StatsContainer(
                      icon: Broken.image,
                      title: '${lang.ARTWORKS} :',
                      value: Indexer.inst.artworksInStorage.value.formatDecimal(),
                      total: Indexer.inst.allAudioFiles.isEmpty ? null : Indexer.inst.allAudioFiles.length.formatDecimal(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              lang.INDEXER_NOTE,
              style: context.textTheme.displaySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Obx(
              () => Text(
                '${lang.DUPLICATED_TRACKS}: ${Indexer.inst.duplicatedTracksLength.value}\n${lang.TRACKS_EXCLUDED_BY_NOMEDIA}: ${Indexer.inst.tracksExcludedByNoMedia.value}\n${lang.FILTERED_BY_SIZE_AND_DURATION}: ${Indexer.inst.filteredForSizeDurationTracks.value}',
                style: context.textTheme.displaySmall,
              ),
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.copy,
              title: lang.PREVENT_DUPLICATED_TRACKS,
              subtitle: "${lang.PREVENT_DUPLICATED_TRACKS_SUBTITLE}. ${lang.INDEX_REFRESH_REQUIRED}",
              onChanged: (isTrue) => settings.save(preventDuplicatedTracks: !isTrue),
              value: settings.preventDuplicatedTracks.value,
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.cd,
              title: lang.RESPECT_NO_MEDIA,
              subtitle: "${lang.RESPECT_NO_MEDIA_SUBTITLE}. ${lang.INDEX_REFRESH_REQUIRED}",
              onChanged: (isTrue) => settings.save(respectNoMedia: !isTrue),
              value: settings.respectNoMedia.value,
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.microphone,
              title: lang.EXTRACT_FEAT_ARTIST,
              subtitle: "${lang.EXTRACT_FEAT_ARTIST_SUBTITLE} ${lang.INSTANTLY_APPLIES}.",
              onChanged: (isTrue) async {
                settings.save(extractFeatArtistFromTitle: !isTrue);
                await Indexer.inst.prepareTracksFile();
              },
              value: settings.extractFeatArtistFromTitle.value,
            ),
          ),
          CustomListTile(
            icon: Broken.profile_2user,
            title: lang.TRACK_ARTISTS_SEPARATOR,
            subtitle: lang.INSTANTLY_APPLIES,
            trailingText: "${settings.trackArtistsSeparators.length}",
            onTap: () async {
              await _showSeparatorSymbolsDialog(
                lang.TRACK_ARTISTS_SEPARATOR,
                settings.trackArtistsSeparators,
                trackArtistsSeparators: true,
              );
            },
          ),
          CustomListTile(
            icon: Broken.smileys,
            title: lang.TRACK_GENRES_SEPARATOR,
            subtitle: lang.INSTANTLY_APPLIES,
            trailingText: "${settings.trackGenresSeparators.length}",
            onTap: () async {
              await _showSeparatorSymbolsDialog(
                lang.TRACK_GENRES_SEPARATOR,
                settings.trackGenresSeparators,
                trackGenresSeparators: true,
              );
            },
          ),
          Obx(
            () => CustomListTile(
              icon: Broken.unlimited,
              title: lang.MIN_FILE_SIZE,
              subtitle: lang.INDEX_REFRESH_REQUIRED,
              trailing: NamidaWheelSlider(
                width: 100.0,
                totalCount: 1024,
                squeeze: 0.2,
                initValue: settings.indexMinFileSizeInB.value.toInt() / 1024 ~/ 10,
                itemSize: 1,
                onValueChanged: (val) {
                  final d = (val as int);
                  settings.save(indexMinFileSizeInB: d * 1024 * 10);
                },
                text: settings.indexMinFileSizeInB.value.fileSizeFormatted,
              ),
            ),
          ),
          Obx(
            () => CustomListTile(
              icon: Broken.timer_1,
              title: lang.MIN_FILE_DURATION,
              subtitle: lang.INDEX_REFRESH_REQUIRED,
              trailing: NamidaWheelSlider(
                width: 100.0,
                totalCount: 180,
                initValue: settings.indexMinDurationInSec.value,
                itemSize: 5,
                onValueChanged: (val) {
                  final d = (val as int);
                  settings.save(indexMinDurationInSec: d);
                },
                text: "${settings.indexMinDurationInSec.value} s",
              ),
            ),
          ),
          Obx(
            () => CustomListTile(
              icon: Broken.arrow_square,
              title: lang.ALBUM_IDENTIFIERS,
              trailingText: settings.albumIdentifiers.length.toString(),
              onTap: () {
                final tempList = List<AlbumIdentifier>.from(settings.albumIdentifiers).obs;
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.ALBUM_IDENTIFIERS,
                    actions: [
                      const CancelButton(),
                      const SizedBox(width: 8.0),
                      NamidaButton(
                        text: lang.SAVE,
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          settings.removeFromList(albumIdentifiersAll: AlbumIdentifier.values);
                          settings.save(albumIdentifiers: tempList);

                          await Indexer.inst.prepareTracksFile();
                        },
                      ),
                    ],
                    child: Column(
                      children: [
                        ...AlbumIdentifier.values.map(
                          (e) {
                            final isForcelyEnabled = e == AlbumIdentifier.albumName;
                            return Opacity(
                              opacity: isForcelyEnabled ? 0.7 : 1.0,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Obx(
                                  () => ListTileWithCheckMark(
                                    title: e.toText(),
                                    active: tempList.contains(e),
                                    onTap: () {
                                      if (isForcelyEnabled) return;
                                      tempList.addOrRemove(e);
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Obx(
          //   () => CustomSwitchListTile(
          //     icon: Broken.backward_item,
          //     title: 'Group Artworks by Album',
          //     value: settings.groupArtworksByAlbum.value,
          //     onChanged: (isTrue) => settings.save(groupArtworksByAlbum: !isTrue),
          //   ),
          // ),
          CustomListTile(
            icon: Broken.refresh,
            title: lang.RE_INDEX,
            subtitle: lang.RE_INDEX_SUBTITLE,
            onTap: () async {
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  normalTitleStyle: true,
                  isWarning: true,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.RE_INDEX,
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();
                        Future.delayed(const Duration(milliseconds: 500), () {
                          Indexer.inst.refreshLibraryAndCheckForDiff(forceReIndex: true);
                        });
                      },
                    ),
                  ],
                  bodyText: lang.RE_INDEX_WARNING,
                ),
              );
            },
          ),
          CustomListTile(
            leading: const _RefreshLibraryIcon(),
            title: lang.REFRESH_LIBRARY,
            subtitle: lang.REFRESH_LIBRARY_SUBTITLE,
            onTap: () => _showRefreshPromptDialog(false),
          ),
          Obx(
            () => NamidaExpansionTile(
              icon: Broken.folder,
              titleText: lang.LIST_OF_FOLDERS,
              textColor: context.textTheme.displayLarge!.color,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  addFolderButton((dirPath) {
                    settings.save(directoriesToScan: [dirPath]);
                  }),
                  const SizedBox(width: 8.0),
                  const Icon(Broken.arrow_down_2),
                ],
              ),
              children: [
                ...settings.directoriesToScan.map(
                  (e) => ListTile(
                    title: Text(
                      e,
                      style: context.textTheme.displayMedium,
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        if (settings.directoriesToScan.length == 1) {
                          snackyy(
                            title: lang.MINIMUM_ONE_ITEM,
                            message: lang.MINIMUM_ONE_FOLDER_SUBTITLE,
                            displaySeconds: 4,
                          );
                        } else {
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              normalTitleStyle: true,
                              isWarning: true,
                              actions: [
                                const CancelButton(),
                                NamidaButton(
                                  text: lang.REMOVE,
                                  onPressed: () {
                                    settings.removeFromList(directoriesToScan1: e);
                                    NamidaNavigator.inst.closeDialog();
                                    _showRefreshPromptDialog(true);
                                  },
                                ),
                              ],
                              bodyText: "${lang.REMOVE} \"$e\"?",
                            ),
                          );
                        }
                      },
                      child: Text(lang.REMOVE.toUpperCase()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => NamidaExpansionTile(
              icon: Broken.folder_minus,
              titleText: lang.EXCLUDED_FODLERS,
              textColor: context.textTheme.displayLarge!.color,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  addFolderButton((dirPath) {
                    settings.save(directoriesToExclude: [dirPath]);
                  }),
                  const SizedBox(width: 8.0),
                  const Icon(Broken.arrow_down_2),
                ],
              ),
              children: settings.directoriesToExclude.isEmpty
                  ? [
                      ListTile(
                        title: Text(
                          lang.NO_EXCLUDED_FOLDERS,
                          style: context.textTheme.displayMedium,
                        ),
                      ),
                    ]
                  : [
                      ...settings.directoriesToExclude.map(
                        (e) => ListTile(
                          title: Text(
                            e,
                            style: context.textTheme.displayMedium,
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              settings.removeFromList(directoriesToExclude1: e);
                              _showRefreshPromptDialog(true);
                            },
                            child: Text(lang.REMOVE.toUpperCase()),
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
      onDismissing: isBlackListDialog
          ? null
          : () async {
              updatingLibrary.value = true;
              await Indexer.inst.prepareTracksFile();
            },
      durationInMs: 200,
      dialog: CustomBlurryDialog(
        title: title,
        actions: [
          if (!isBlackListDialog)
            NamidaButton(
              textWidget: Obx(() {
                final blLength = trackArtistsSeparators ? settings.trackArtistsSeparatorsBlacklist.length : settings.trackGenresSeparatorsBlacklist.length;
                final t = blLength == 0 ? '' : ' ($blLength)';
                return Text('${lang.BLACKLIST}$t');
              }),
              onPressed: () {
                if (trackArtistsSeparators) {
                  _showSeparatorSymbolsDialog(
                    lang.BLACKLIST,
                    settings.trackArtistsSeparatorsBlacklist,
                    trackArtistsSeparatorsBlacklist: true,
                  );
                }
                if (trackGenresSeparators) {
                  _showSeparatorSymbolsDialog(
                    lang.BLACKLIST,
                    settings.trackGenresSeparatorsBlacklist,
                    trackGenresSeparatorsBlacklist: true,
                  );
                }
              },
            ),
          if (isBlackListDialog) const CancelButton(),
          Obx(
            () => updatingLibrary.value
                ? const LoadingIndicator()
                : NamidaButton(
                    text: lang.ADD,
                    onPressed: () {
                      if (separatorsController.text.isNotEmpty) {
                        if (trackArtistsSeparators) {
                          settings.save(trackArtistsSeparators: [separatorsController.text]);
                        }
                        if (trackGenresSeparators) {
                          settings.save(trackGenresSeparators: [separatorsController.text]);
                        }
                        if (trackArtistsSeparatorsBlacklist) {
                          settings.save(trackArtistsSeparatorsBlacklist: [separatorsController.text]);
                        }
                        if (trackGenresSeparatorsBlacklist) {
                          settings.save(trackGenresSeparatorsBlacklist: [separatorsController.text]);
                        }
                        separatorsController.clear();
                      } else {
                        snackyy(title: lang.EMPTY_VALUE, message: lang.ENTER_SYMBOL);
                      }
                    },
                  ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBlackListDialog ? lang.SEPARATORS_BLACKLIST_SUBTITLE : lang.SEPARATORS_MESSAGE,
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
                            settings.removeFromList(trackArtistsSeparator: e);
                          }
                          if (trackGenresSeparators) {
                            settings.removeFromList(trackGenresSeparator: e);
                          }
                          if (trackArtistsSeparatorsBlacklist) {
                            settings.removeFromList(trackArtistsSeparatorsBlacklist1: e);
                          }
                          if (trackGenresSeparatorsBlacklist) {
                            settings.removeFromList(trackGenresSeparatorsBlacklist1: e);
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
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: TextField(
                style: Get.textTheme.displaySmall?.copyWith(fontSize: 16.0.multipliedFontScale, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  isDense: true,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                    borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                    borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
                  ),
                  hintText: lang.VALUE,
                ),
                controller: separatorsController,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _RefreshLibraryIcon extends StatefulWidget {
  const _RefreshLibraryIcon({Key? key}) : super(key: key);
  static late AnimationController controller;

  @override
  State<_RefreshLibraryIcon> createState() => _RefreshLibraryIconState();
}

class _RefreshLibraryIconState extends State<_RefreshLibraryIcon> with TickerProviderStateMixin {
  final turnsTween = Tween<double>(begin: 0.0, end: 1.0);
  @override
  void initState() {
    super.initState();
    _RefreshLibraryIcon.controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _RefreshLibraryIcon.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turnsTween.animate(_RefreshLibraryIcon.controller),
      child: const Icon(
        Broken.refresh_2,
      ),
    );
  }
}
