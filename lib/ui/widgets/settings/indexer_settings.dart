import 'dart:async';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
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

enum _IndexerSettingsKeys {
  preventDuplicatedTracks,
  respectNoMedia,
  extractFtArtist,
  groupArtworksByAlbum,
  albumIdentifiers,
  artistSeparators,
  genreSeparators,
  minimumFileSize,
  minimumTrackDur,
  useMediaStore,
  refreshOnStartup,
  reindex,
  refreshLibrary,
  foldersToScan,
  foldersToExclude,
}

class IndexerSettings extends SettingSubpageProvider {
  const IndexerSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.indexer;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _IndexerSettingsKeys.preventDuplicatedTracks: [lang.PREVENT_DUPLICATED_TRACKS, lang.PREVENT_DUPLICATED_TRACKS_SUBTITLE],
        _IndexerSettingsKeys.respectNoMedia: [lang.RESPECT_NO_MEDIA, lang.RESPECT_NO_MEDIA_SUBTITLE],
        _IndexerSettingsKeys.extractFtArtist: [lang.EXTRACT_FEAT_ARTIST, lang.EXTRACT_FEAT_ARTIST_SUBTITLE],
        _IndexerSettingsKeys.groupArtworksByAlbum: [lang.GROUP_ARTWORKS_BY_ALBUM],
        _IndexerSettingsKeys.albumIdentifiers: [lang.ALBUM_IDENTIFIERS],
        _IndexerSettingsKeys.artistSeparators: [lang.TRACK_ARTISTS_SEPARATOR],
        _IndexerSettingsKeys.genreSeparators: [lang.TRACK_GENRES_SEPARATOR],
        _IndexerSettingsKeys.minimumFileSize: [lang.MIN_FILE_SIZE],
        _IndexerSettingsKeys.minimumTrackDur: [lang.MIN_FILE_DURATION],
        _IndexerSettingsKeys.useMediaStore: [lang.USE_MEDIA_STORE, lang.USE_MEDIA_STORE_SUBTITLE],
        _IndexerSettingsKeys.refreshOnStartup: [lang.REFRESH_ON_STARTUP],
        _IndexerSettingsKeys.reindex: [lang.RE_INDEX, lang.RE_INDEX_SUBTITLE],
        _IndexerSettingsKeys.refreshLibrary: [lang.REFRESH_LIBRARY, lang.REFRESH_LIBRARY_SUBTITLE],
        _IndexerSettingsKeys.foldersToScan: [lang.LIST_OF_FOLDERS],
        _IndexerSettingsKeys.foldersToExclude: [lang.EXCLUDED_FODLERS],
      };

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
        showRefreshPromptDialog(true);
      },
    );
  }

  Widget getMediaStoreWidget() {
    return getItemWrapper(
      key: _IndexerSettingsKeys.useMediaStore,
      child: Obx(
        () => CustomSwitchListTile(
          bgColor: getBgColor(_IndexerSettingsKeys.useMediaStore),
          icon: Broken.airdrop,
          title: lang.USE_MEDIA_STORE,
          subtitle: lang.USE_MEDIA_STORE_SUBTITLE,
          value: settings.useMediaStore.value,
          onChanged: (isTrue) {
            settings.save(useMediaStore: !isTrue);
            showRefreshPromptDialog(false);
          },
        ),
      ),
    );
  }

  Widget getGroupArtworksByAlbumWidget() {
    return getItemWrapper(
      key: _IndexerSettingsKeys.groupArtworksByAlbum,
      child: Obx(
        () => CustomSwitchListTile(
          bgColor: getBgColor(_IndexerSettingsKeys.groupArtworksByAlbum),
          icon: Broken.backward_item,
          title: lang.GROUP_ARTWORKS_BY_ALBUM,
          subtitle: lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING,
          value: settings.groupArtworksByAlbum.value,
          onChanged: (isTrue) {
            settings.save(groupArtworksByAlbum: !isTrue);
            _showReindexingPrompt(title: lang.GROUP_ARTWORKS_BY_ALBUM, body: lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING);
          },
        ),
      ),
    );
  }

  Widget getFoldersToScanWidget({
    required BuildContext context,
    bool initiallyExpanded = false,
  }) {
    return getItemWrapper(
      key: _IndexerSettingsKeys.foldersToScan,
      child: Obx(
        () => AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: settings.useMediaStore.value ? 0.5 : 1.0,
          child: NamidaExpansionTile(
            bgColor: getBgColor(_IndexerSettingsKeys.foldersToScan),
            initiallyExpanded: initiallyExpanded,
            icon: Broken.folder,
            titleText: lang.LIST_OF_FOLDERS,
            textColor: context.textTheme.displayLarge!.color,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  ignoring: settings.useMediaStore.value,
                  child: addFolderButton((dirPath) {
                    settings.save(directoriesToScan: [dirPath]);
                  }),
                ),
                const SizedBox(width: 8.0),
                const Icon(Broken.arrow_down_2),
              ],
            ),
            children: [
              ...settings.directoriesToScan.map(
                (e) => IgnorePointer(
                  ignoring: settings.useMediaStore.value,
                  child: ListTile(
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
                                    showRefreshPromptDialog(true);
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getFoldersToExcludeWidget({
    required BuildContext context,
    bool initiallyExpanded = false,
  }) {
    return getItemWrapper(
      key: _IndexerSettingsKeys.foldersToExclude,
      child: Obx(
        () => NamidaExpansionTile(
          bgColor: getBgColor(_IndexerSettingsKeys.foldersToExclude),
          initiallyExpanded: initiallyExpanded,
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
                          showRefreshPromptDialog(true);
                        },
                        child: Text(lang.REMOVE.toUpperCase()),
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  void _showReindexingPrompt({
    required String title,
    required String body,
  }) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: title,
        actions: [
          const CancelButton(),
          const SizedBox(width: 8.0),
          NamidaButton(
            text: [lang.CLEAR, lang.RE_INDEX].join(' & '),
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              await Indexer.inst.clearImageCache();
              await Indexer.inst.refreshLibraryAndCheckForDiff(forceReIndex: true);
            },
          ),
        ],
        bodyText: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const refreshIconKey1 = 'kurukuru';
    const refreshIconKey2 = 'kururin';
    return SettingsCard(
      title: lang.INDEXER,
      subtitle: lang.INDEXER_SUBTITLE,
      icon: Broken.component,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NamidaIconButton(
            icon: Broken.refresh_2,
            tooltip: lang.REFRESH_LIBRARY,
            onPressed: () => showRefreshPromptDialog(false),
            child: const _RefreshLibraryIcon(widgetKey: refreshIconKey2),
          ),
          const SizedBox(
            height: 48.0,
            child: IndexingPercentage(),
          ),
        ],
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Obx(
              () => Text(
                '${lang.DUPLICATED_TRACKS}: ${Indexer.inst.duplicatedTracksLength.value}\n${lang.TRACKS_EXCLUDED_BY_NOMEDIA}: ${Indexer.inst.tracksExcludedByNoMedia.value}\n${lang.FILTERED_BY_SIZE_AND_DURATION}: ${Indexer.inst.filteredForSizeDurationTracks.value}',
                style: context.textTheme.displaySmall,
              ),
            ),
          ),
          Obx(
            () {
              final p = Indexer.inst.currentTrackPathBeingExtracted.value;
              return p == ''
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                      child: Text(
                        p,
                        style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0.multipliedFontScale),
                      ),
                    );
            },
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.preventDuplicatedTracks,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.preventDuplicatedTracks),
                icon: Broken.copy,
                title: lang.PREVENT_DUPLICATED_TRACKS,
                subtitle: "${lang.PREVENT_DUPLICATED_TRACKS_SUBTITLE}. ${lang.INDEX_REFRESH_REQUIRED}",
                onChanged: (isTrue) => settings.save(preventDuplicatedTracks: !isTrue),
                value: settings.preventDuplicatedTracks.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.respectNoMedia,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.respectNoMedia),
                enabled: !settings.useMediaStore.value,
                icon: Broken.cd,
                title: lang.RESPECT_NO_MEDIA,
                subtitle: "${lang.RESPECT_NO_MEDIA_SUBTITLE}. ${lang.INDEX_REFRESH_REQUIRED}",
                onChanged: (isTrue) => settings.save(respectNoMedia: !isTrue),
                value: settings.useMediaStore.value ? false : settings.respectNoMedia.value,
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.extractFtArtist,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.extractFtArtist),
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
          ),
          getGroupArtworksByAlbumWidget(),
          getItemWrapper(
            key: _IndexerSettingsKeys.albumIdentifiers,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.albumIdentifiers),
                icon: Broken.arrow_square,
                title: lang.ALBUM_IDENTIFIERS,
                trailingText: settings.albumIdentifiers.length.toString(),
                onTap: () {
                  final tempList = List<AlbumIdentifier>.from(settings.albumIdentifiers).obs;
                  NamidaNavigator.inst.navigateDialog(
                    onDisposing: () {
                      tempList.close();
                    },
                    dialog: CustomBlurryDialog(
                      title: lang.ALBUM_IDENTIFIERS,
                      actions: [
                        const CancelButton(),
                        const SizedBox(width: 8.0),
                        Obx(
                          () {
                            return NamidaButton(
                              enabled: settings.albumIdentifiers.any((element) => !tempList.contains(element)) ||
                                  tempList.any((element) => !settings.albumIdentifiers.contains(element)), // isEqualTo wont work cuz order shouldnt matter
                              text: lang.SAVE,
                              onPressed: () async {
                                NamidaNavigator.inst.closeDialog();
                                settings.removeFromList(albumIdentifiersAll: AlbumIdentifier.values);
                                settings.save(albumIdentifiers: tempList);

                                Indexer.inst.prepareTracksFile();

                                _showReindexingPrompt(title: lang.ALBUM_IDENTIFIERS, body: lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING);
                              },
                            );
                          },
                        ),
                      ],
                      child: Column(
                        children: [
                          ...AlbumIdentifier.values.map(
                            (e) {
                              final isForcelyEnabled = e == AlbumIdentifier.albumName;
                              return NamidaOpacity(
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
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.artistSeparators,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.artistSeparators),
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
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.genreSeparators,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.genreSeparators),
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
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.minimumFileSize,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.minimumFileSize),
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
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.minimumTrackDur,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.minimumTrackDur),
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
          ),
          getMediaStoreWidget(),
          getItemWrapper(
            key: _IndexerSettingsKeys.refreshOnStartup,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.refreshOnStartup),
                icon: Broken.d_rotate,
                title: lang.REFRESH_ON_STARTUP,
                value: settings.refreshOnStartup.value,
                onChanged: (isTrue) => settings.save(refreshOnStartup: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.reindex,
            child: CustomListTile(
              bgColor: getBgColor(_IndexerSettingsKeys.reindex),
              icon: Broken.refresh,
              title: lang.RE_INDEX,
              subtitle: lang.RE_INDEX_SUBTITLE,
              onTap: () async {
                final clearArtworks = false.obs;
                await NamidaNavigator.inst.navigateDialog(
                  onDisposing: () {
                    clearArtworks.close();
                  },
                  dialog: CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.RE_INDEX,
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          Future.delayed(const Duration(milliseconds: 500), () async {
                            if (clearArtworks.value) {
                              await Indexer.inst.clearImageCache();
                            }
                            Indexer.inst.refreshLibraryAndCheckForDiff(forceReIndex: true);
                          });
                        },
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Text(
                            lang.RE_INDEX_WARNING,
                            style: context.textTheme.displayMedium,
                          ),
                          const SizedBox(height: 16.0),
                          Obx(
                            () => ListTileWithCheckMark(
                              dense: true,
                              icon: Broken.trash,
                              title: lang.CLEAR_IMAGE_CACHE,
                              subtitle: Indexer.inst.artworksSizeInStorage.value.fileSizeFormatted,
                              active: clearArtworks.value,
                              onTap: () => clearArtworks.value = !clearArtworks.value,
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
          getItemWrapper(
            key: _IndexerSettingsKeys.refreshLibrary,
            child: CustomListTile(
              bgColor: getBgColor(_IndexerSettingsKeys.refreshLibrary),
              leading: const _RefreshLibraryIcon(widgetKey: refreshIconKey1),
              title: lang.REFRESH_LIBRARY,
              subtitle: lang.REFRESH_LIBRARY_SUBTITLE,
              onTap: () => showRefreshPromptDialog(false),
            ),
          ),
          getFoldersToScanWidget(context: context),
          getFoldersToExcludeWidget(context: context),
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
      onDisposing: () {
        updatingLibrary.close();
        separatorsController.dispose();
      },
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

Future<void> showRefreshPromptDialog(bool didModifyFolder) async {
  // [didModifyFolder] was mainly used to force recheck libraries, now it will always recheck.
  RefreshLibraryIconController.repeat();
  final currentFiles = await Indexer.inst.getAudioFiles();
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
              VideoController.inst.scanLocalVideos(forceReScan: true, fillPathsOnly: true);
              await Indexer.inst.refreshLibraryAndCheckForDiff(currentFiles: currentFiles);
            },
          ),
        ],
      ),
    );
  }

  await RefreshLibraryIconController.fling();
  RefreshLibraryIconController.stop();
}

class RefreshLibraryIconController {
  static final _controllers = <String, AnimationController>{};

  static AnimationController getController(String key, TickerProvider vsync) => _controllers[key] ?? init(key, vsync);

  static AnimationController init(String key, TickerProvider vsync) {
    _controllers[key]?.dispose();
    final c = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: vsync,
    );
    _controllers[key] = c;
    return c;
  }

  static void dispose(String key) {
    final c = _controllers.remove(key);
    c?.dispose();
  }

  static void repeat() {
    _loopControllers((c) => c?.repeat());
  }

  static Future<void> fling() async {
    int controllersFlinging = _controllers.length;
    final completer = Completer<void>();
    _loopControllers(
      (c) => c?.fling(velocity: 0.6).then((value) {
        controllersFlinging--;
        if (controllersFlinging == 0) completer.completeIfWasnt();
      }),
    );
    await completer.future;
  }

  static void stop() {
    _loopControllers((c) => c?.stop());
  }

  static void _loopControllers(void Function(AnimationController? c) execute) {
    for (final k in _controllers.keys) {
      final controller = _controllers[k];
      execute(controller);
    }
  }
}

class _RefreshLibraryIcon extends StatefulWidget {
  final String widgetKey;
  const _RefreshLibraryIcon({required this.widgetKey});

  @override
  State<_RefreshLibraryIcon> createState() => _RefreshLibraryIconState();
}

class _RefreshLibraryIconState extends State<_RefreshLibraryIcon> with TickerProviderStateMixin {
  final turnsTween = Tween<double>(begin: 0.0, end: 1.0);
  @override
  void initState() {
    super.initState();
    RefreshLibraryIconController.init(widget.widgetKey, this);
  }

  @override
  void dispose() {
    RefreshLibraryIconController.dispose(widget.widgetKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turnsTween.animate(RefreshLibraryIconController.getController(widget.widgetKey, this)),
      child: Icon(
        Broken.refresh_2,
        color: context.defaultIconColor(),
      ),
    );
  }
}
