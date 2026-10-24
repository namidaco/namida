import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/pages/sync_manager_page.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

class BackupAndRestore extends SettingSubpageProvider {
  const BackupAndRestore({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.backupRestore;

  @override
  List<List<SettingEntry>> get sections => _sections;

  static final restoreBackup = SettingCustom(
    title: () => lang.restoreBackup,
    tile: (args) => _RestoreBackupTile(
      bgColor: args.bgColor,
    ),
  );

  static final defaultBackupLocation = SettingCustom(
    title: () => lang.defaultBackupLocation,
    keys: [settings.defaultBackupLocation],
    tile: (args) => _DefaultBackupLocationTile(
      bgColor: args.bgColor,
    ),
  );

  static final _sections = <List<SettingEntry>>[
    [
      SettingCustom(
        title: () => lang.createBackup,
        keys: [settings.backupItemslist],
        tile: (args) => _CreateBackupTile(
          bgColor: args.bgColor,
        ),
      ),
      restoreBackup,
      defaultBackupLocation,
      SettingWheel(
        settings.autoBackupIntervalDays,
        icon: Broken.timer,
        title: () => lang.autoBackupInterval,
        max: 14,
        valueToText: _autoBackupIntervalToText,
      ),
    ],
    [
      SettingCustom(
        title: () => lang.sync,
        aliases: () => [
          lang.syncAppDataBetweenYourDevices,
          lang.deviceName,
          '${lang.auto} ${lang.reconnect}',
          lang.autoSyncInterval,
          lang.dataToSendAndReceive,
        ],
        tile: (args) => _SyncTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingCustom(
        title: () => lang.importData,
        aliases: () => [
          ..._importSources.map(JsonToHistoryParser.getImportTitle),
          ...DataImportType.values.map((e) => e.toText()),
        ],
        tile: (args) => _ImportDataTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
  ];

  static const _importSources = [TrackSource.youtube, TrackSource.lastfm, TrackSource.spotify, TrackSource.listenbrainz];

  static List<DataImportType> _importTypesOf(TrackSource source) => switch (source) {
    TrackSource.youtube || TrackSource.youtubeMusic => const [DataImportType.history, DataImportType.favourites, DataImportType.playlists, DataImportType.subscriptions],
    TrackSource.spotify || TrackSource.listenbrainz => const [DataImportType.history, DataImportType.favourites],
    TrackSource.lastfm => const [DataImportType.history],
    TrackSource.local => const [],
  };

  static Map<DataImportType, Rx<bool>> _createImportTypesRx(TrackSource source) {
    return {for (final e in _importTypesOf(source)) e: true.obs};
  }

  static Set<DataImportType> _selectedImportTypes(Map<DataImportType, Rx<bool>> typesRx) {
    return typesRx.entries.where((e) => e.value.value).map((e) => e.key).toSet();
  }

  static String _autoBackupIntervalToText(int days) {
    if (days == 0) return lang.none;
    final unitText = days == 1 ? lang.day : lang.days;
    return "$days $unitText";
  }

  static bool _canDoImport({required bool isYT}) {
    if (JsonToHistoryParser.inst.isParsing.value ||
        BackupController.inst.isCreatingBackup.value ||
        BackupController.inst.isRestoringBackup.value ||
        HistoryController.inst.isLoadingHistory ||
        (isYT && YoutubeHistoryController.inst.isLoadingHistory)) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return false;
    }
    return true;
  }

  static bool _canCreateRestoreBackup() {
    if (JsonToHistoryParser.inst.isParsing.value || HistoryController.inst.isLoadingHistory || YoutubeHistoryController.inst.isLoadingHistory) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return false;
    }
    return true;
  }

  static void _promptRestoreBackup() {
    if (!_canCreateRestoreBackup()) return;

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.restoreBackup,
        child: SmoothSingleChildScrollView(
          child: Column(
            children: [
              CustomListTile(
                title: lang.automaticBackup,
                subtitle: lang.automaticBackupSubtitle,
                icon: Broken.autobrightness,
                maxSubtitleLines: 22,
                onTap: () async {
                  if (!await requestManageStoragePermission()) return;

                  NamidaNavigator.inst.closeDialog();
                  BackupController.inst.restoreBackupOnTap(true);
                },
              ),
              CustomListTile(
                title: lang.manualBackup,
                subtitle: lang.manualBackupSubtitle,
                maxSubtitleLines: 22,
                icon: Broken.hashtag,
                onTap: () {
                  NamidaNavigator.inst.closeDialog();
                  BackupController.inst.restoreBackupOnTap(false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // void _openNamidaSync() async {
  //   final backupFolder = settings.defaultBackupLocation.value ?? AppDirs.BACKUPS;
  //   final musicFolders = settings.directoriesToScan.value;

  //   final musicFoldersJoined = musicFolders.where((e) => e.sourceRaw.isNotEmpty).map((e) => e).join(',');

  //   bool requiresDownload = false;
  //   try {
  //     if (Platform.isAndroid) {
  //       final didOpen = await NamidaChannel.inst.openNamidaSync(backupFolder, musicFoldersJoined);
  //       if (!didOpen) requiresDownload = true;
  //     } else if (Platform.isWindows) {
  //       File? exeFile = File(r'C:\Program Files\namida_sync\namida_sync.exe');
  //       if (!await exeFile.exists()) {
  //         exeFile = await NamidaFileBrowser.pickFile(note: "${lang.pickFromStorage}: namida_sync.exe", allowedExtensions: NamidaFileExtensionsWrapper.exe);
  //       }
  //       if (exeFile == null || !await exeFile.exists()) {
  //         requiresDownload = true;
  //       } else {
  //         final args = ['--backupPath="$backupFolder"', '--musicFolders="$musicFoldersJoined"'];
  //         await Process.run(exeFile.path, args);
  //       }
  //     } else if (Platform.isLinux) {
  //       File? exeFile;
  //       final commonPaths = [
  //         '/usr/local/bin/namida_sync',
  //         '/usr/bin/namida_sync',
  //         '${NamidaPlatformBuilder.unixUserHome ?? '~'}/.local/bin/namida_sync',
  //       ];

  //       for (final path in commonPaths) {
  //         final file = File(path);
  //         if (await file.exists()) {
  //           exeFile = file;
  //           break;
  //         }
  //       }
  //       exeFile ??= await NamidaFileBrowser.pickFile(
  //         note: "${lang.pickFromStorage}: namida_sync",
  //         allowedExtensions: null,
  //       );

  //       if (exeFile == null || !await exeFile.exists()) {
  //         requiresDownload = true;
  //       } else {
  //         final args = ['--backupPath="$backupFolder"', '--musicFolders="$musicFoldersJoined"'];
  //         await Process.run(exeFile.path, args);
  //       }
  //     } else {
  //       final uri = Uri(
  //         scheme: 'namidasync',
  //         host: 'config',
  //         queryParameters: {
  //           'backupPath': backupFolder,
  //           'musicFolders': musicFoldersJoined,
  //         },
  //       );
  //       final url = uri.toString();
  //       final didOpen = await NamidaLinkUtils.openLink(url);
  //       if (!didOpen) requiresDownload = true;
  //     }
  //   } catch (e) {
  //     snackyy(message: e.toString(), isError: true);
  //   }

  //   if (requiresDownload) {
  //     try {
  //       await NamidaLinkUtils.openLink(AppSocial.NAMIDA_SYNC_GITHUB_RELEASE);
  //     } catch (e) {
  //       snackyy(message: e.toString(), isError: true);
  //     }
  //   }
  // }

  static void _ensureNewBackupItemsIncluded(List<AppPathsBackupEnum> items) {
    int includedCount = 0;
    final settingItems = settings.backupItemslist.value;
    for (final item in items) {
      final isIncluded = settingItems.contains(item);
      if (isIncluded) includedCount++;
    }
    if (includedCount > 0 && includedCount < items.length) {
      // -- if a new item was added in an update while old
      // -- settings still apply, this should fix it
      settings.backupItemslist.update((list) => list.addAllNoDuplicates(items));
    }
  }

  static void _promptCreateBackup() {
    if (!_canCreateRestoreBackup()) return;

    final sizesMap = <AppPathsBackupEnum, int>{}.obs;

    void fillAllItemsSize() async {
      await AppPathsBackupEnum.values.loopConcurrent((item) async {
        if (item.isDir) {
          sizesMap[item] = await Directory(item.resolve()).getTotalSize() ?? 0;
        } else {
          sizesMap[item] = await File(item.resolve()).fileSize() ?? 0;
        }
      }, concurrency: 8);
    }

    fillAllItemsSize();

    final itemTiles = [
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.database,
        icon: Broken.box_1,
        items: AppPathsBackupEnumCategories.database,
        youtubeAvailable: true,
        youtubeItems: AppPathsBackupEnumCategories.database_yt,
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.playlists,
        icon: Broken.music_library_2,
        items: AppPathsBackupEnumCategories.playlists,
        youtubeAvailable: true,
        youtubeItems: AppPathsBackupEnumCategories.playlists_yt,
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.history,
        icon: Broken.refresh,
        items: AppPathsBackupEnumCategories.history,
        youtubeAvailable: true,
        youtubeItems: AppPathsBackupEnumCategories.history_yt,
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.settings,
        icon: Broken.setting,
        items: AppPathsBackupEnumCategories.settings,
        youtubeAvailable: false,
        youtubeItems: const [],
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.lyrics,
        icon: Broken.document,
        items: AppPathsBackupEnumCategories.lyrics,
        youtubeAvailable: false,
        youtubeItems: const [],
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.queues,
        icon: Broken.driver,
        items: AppPathsBackupEnumCategories.queues,
        youtubeAvailable: false,
        youtubeItems: const [],
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.colorPalettes,
        icon: Broken.colorfilter,
        items: AppPathsBackupEnumCategories.palette,
        youtubeAvailable: true,
        youtubeForceFollowItems: false,
        youtubeItems: AppPathsBackupEnumCategories.palette_yt,
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.videoCache,
        icon: Broken.video,
        items: AppPathsBackupEnumCategories.videos_cache,
        youtubeAvailable: false,
        youtubeForceFollowItems: true,
        youtubeItems: const [],
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.audioCache,
        icon: Broken.audio_square,
        items: AppPathsBackupEnumCategories.audios_cache,
        youtubeAvailable: false,
        youtubeForceFollowItems: true,
        youtubeItems: const [],
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.artworks,
        icon: Broken.image,
        items: AppPathsBackupEnumCategories.artworks,
        youtubeAvailable: false,
        youtubeItems: const [],
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.thumbnails,
        icon: Broken.image,
        items: AppPathsBackupEnumCategories.thumbnails,
        youtubeAvailable: true,
        youtubeItems: AppPathsBackupEnumCategories.thumbnails_yt,
      ),
      _BackupItemsTile(
        sizesMap: sizesMap,
        title: lang.metadataCache,
        icon: Broken.message_text,
        items: AppPathsBackupEnumCategories.youtipie_cache,
        youtubeAvailable: true,
        youtubeForceFollowItems: true,
        youtubeItems: const [],
      ),
    ];
    for (final tile in itemTiles) {
      _ensureNewBackupItemsIncluded(tile.items);
      _ensureNewBackupItemsIncluded(tile.youtubeItems);
    }
    final itemsChildren = itemTiles
        .addSeparators(
          separator: const SizedBox(
            height: 8.0,
          ),
        )
        .toFixedList();

    NamidaNavigator.inst.navigateDialog(
      onDisposing: sizesMap.close,
      dialog: CustomBlurryDialog(
        title: lang.createBackup,
        actions: [
          const CancelButton(),
          ObxO(
            rx: settings.backupItemslist,
            builder: (context, backupItemslist) {
              return NamidaButton(
                enabled: backupItemslist.isNotEmpty,
                text: lang.createBackup,
                onTap: () {
                  final items = settings.backupItemslist.value;
                  if (items.isNotEmpty) {
                    NamidaNavigator.inst.closeDialog();
                    final rawPaths = items.map((e) => e.resolve()).toList();
                    BackupController.inst.createBackupFile(rawPaths);
                  }
                },
              );
            },
          ),
        ],
        child: SizedBox(
          height: namida.height / 2,
          child: SmoothSingleChildScrollView(
            child: Column(
              children: itemsChildren,
            ),
          ),
        ),
      ),
    );
  }

  static void _importFrom(TrackSource source) {
    switch (source) {
      case TrackSource.youtube || TrackSource.youtubeMusic:
        _importYoutubeData();
      case TrackSource.lastfm:
        _importGeneralNonYTSource(
          source: source,
          guideWithLink: lang.importLastFmHistoryGuide(lastfmCsvLink: 'https://benjaminbenben.com/lastfm-to-csv'),
          allowedExtensions: NamidaFileExtensionsWrapper.csv,
        );
      case TrackSource.spotify:
        _importGeneralNonYTSource(
          source: source,
          guideWithLink: lang.importSpotifyHistoryGuide(link: 'https://www.spotify.com/account/privacy'),
          allowedExtensions: NamidaFileExtensionsWrapper.jsonAndZip,
        );
      case TrackSource.listenbrainz:
        _importGeneralNonYTSource(
          source: source,
          guideWithLink: lang.importListenBrainzHistoryGuide(link: 'https://listenbrainz.org/settings/export'),
          allowedExtensions: NamidaFileExtensionsWrapper.jsonlAndZip,
        );
      case TrackSource.local:
        break;
    }
  }

  static void _importGeneralNonYTSource({
    required TrackSource source,
    required String guideWithLink,
    required NamidaFileExtensionsWrapper allowedExtensions,
  }) {
    if (!_canDoImport(isYT: false)) return;

    final title = JsonToHistoryParser.getImportTitle(source);
    const divider = NamidaContainerDivider(
      margin: EdgeInsets.symmetric(vertical: 8.0),
    );

    void onConfirm(bool pickDirectory) async {
      var selectedFiles = <File>[];
      Directory? mainDirectory;
      if (pickDirectory) {
        mainDirectory = await NamidaFileBrowser.pickDirectory(note: title);
      } else {
        selectedFiles = await NamidaFileBrowser.pickFiles(note: title, allowedExtensions: allowedExtensions);
      }

      if (selectedFiles.isNotEmpty || mainDirectory != null) {
        final typesRx = _createImportTypesRx(source);
        final oldestDate = Rxn<DateTime>();
        DateTime? newestDate;
        final matchAll = false.obs;
        final backupHistoryFirst = true.obs;
        NamidaNavigator.inst.navigateDialog(
          onDisposing: () {
            for (final rx in typesRx.values) {
              rx.close();
            }
            oldestDate.close();
            matchAll.close();
            backupHistoryFirst.close();
          },
          dialog: CustomBlurryDialog(
            horizontalInset: 38.0,
            verticalInset: 38.0,
            title: lang.configure,
            actions: [
              const CancelButton(),
              Obx(
                (context) => NamidaButton(
                  enabled: typesRx.values.any((e) => e.valueR),
                  text: oldestDate.valueR != null ? lang.importTimeRange : lang.importAll,
                  onTap: () async {
                    NamidaNavigator.inst.closeDialog();
                    await JsonToHistoryParser.inst.importSourceFiles(
                      files: selectedFiles,
                      mainDirectory: mainDirectory,
                      source: source,
                      types: _selectedImportTypes(typesRx),
                      oldestDate: oldestDate.value,
                      newestDate: newestDate,
                      matchAll: matchAll.value,
                      backupFirst: backupHistoryFirst.value,
                    );
                  },
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (typesRx.length > 1) ...[
                  _ImportTypesCards(
                    typesRx: typesRx,
                  ),
                  divider,
                ],
                _BackupHistoryBeforeImportTile(
                  activeRx: backupHistoryFirst,
                ),
                const SizedBox(
                  height: 8.0,
                ),
                Obx(
                  (context) => _MatchAllTracksTile(
                    active: matchAll.valueR,
                    onTap: matchAll.toggle,
                    displayPerfWarning: true,
                  ),
                ),
                const SizedBox(
                  height: 8.0,
                ),
                BetweenDatesTextButton(
                  useHistoryDates: false,
                  maxToday: true,
                  onConfirm: (dates) {
                    NamidaNavigator.inst.closeDialog();
                    oldestDate.value = dates.firstOrNull;
                    newestDate = dates.lastOrNull;
                  },
                ),
              ],
            ),
          ),
        );
      }
    }

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.guide,
        actions: [
          NamidaButton(
            text: lang.folder,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              onConfirm(true);
            },
          ),
          const SizedBox(
            width: 2.0,
          ),
          NamidaButton(
            text: lang.confirm,
            onTap: () async {
              NamidaNavigator.inst.closeDialog();
              onConfirm(false);
            },
          ),
        ],
        child: NamidaSelectableAutoLinkText(
          text: guideWithLink,
        ),
      ),
    );
  }

  static void _importYoutubeData() {
    if (!_canDoImport(isYT: true)) return;

    final title = JsonToHistoryParser.getImportTitle(TrackSource.youtube);
    const divider = NamidaContainerDivider(
      margin: EdgeInsets.symmetric(vertical: 8.0),
    );

    void onConfirm(bool pickDirectory) async {
      var jsonfiles = <File>[];
      Directory? mainDirectory;
      if (pickDirectory) {
        mainDirectory = await NamidaFileBrowser.pickDirectory(note: title);
      } else {
        jsonfiles = await NamidaFileBrowser.pickFiles(note: title, allowedExtensions: NamidaFileExtensionsWrapper.jsonHtmlAndZip);
      }
      if (jsonfiles.isNotEmpty || mainDirectory != null) {
        final typesRx = _createImportTypesRx(TrackSource.youtube);
        final isMatchingTypeLink = true.obs;
        final isMatchingTypeTitleAndArtist = false.obs;
        final matchYT = true.obs;
        final matchYTMusic = true.obs;
        final matchAll = false.obs;
        final oldestDate = Rxn<DateTime>();
        DateTime? newestDate;
        final backupHistoryFirst = true.obs;
        NamidaNavigator.inst.navigateDialog(
          onDisposing: () {
            for (final rx in typesRx.values) {
              rx.close();
            }
            isMatchingTypeLink.close();
            isMatchingTypeTitleAndArtist.close();
            matchYT.close();
            matchYTMusic.close();
            matchAll.close();
            oldestDate.close();
            backupHistoryFirst.close();
          },
          dialog: CustomBlurryDialog(
            title: lang.configure,
            actions: [
              Obx(
                (context) {
                  final hasMatchingType = isMatchingTypeLink.valueR || isMatchingTypeTitleAndArtist.valueR;
                  final isHistoryEnabled = typesRx[DataImportType.history]?.valueR == true;
                  final hasAnyType = typesRx.values.any((e) => e.valueR);
                  return NamidaButton(
                    enabled: hasAnyType && (hasMatchingType || !isHistoryEnabled),
                    text: oldestDate.valueR != null ? lang.importTimeRange : lang.importAll,
                    onTap: () async {
                      NamidaNavigator.inst.closeDialog();
                      await JsonToHistoryParser.inst.importSourceFiles(
                        files: jsonfiles,
                        mainDirectory: mainDirectory,
                        source: TrackSource.youtube,
                        types: _selectedImportTypes(typesRx),
                        ytIsMatchingTypeLink: isMatchingTypeLink.value,
                        isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist.value,
                        ytMatchYT: matchYT.value,
                        ytMatchYTMusic: matchYTMusic.value,
                        oldestDate: oldestDate.value,
                        newestDate: newestDate,
                        matchAll: matchAll.value,
                        backupFirst: backupHistoryFirst.value,
                      );
                    },
                  );
                },
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImportTypesCards(
                  typesRx: typesRx,
                ),
                const SizedBox(
                  height: 12.0,
                ),
                _ImportDialogTitle(
                  text: lang.source,
                ),
                _ImportOptionCardsRow(
                  cards: [
                    _ImportOptionCard(
                      activeRx: matchYT,
                      icon: Broken.video_square,
                      title: lang.youtube,
                    ),
                    _ImportOptionCard(
                      activeRx: matchYTMusic,
                      icon: Broken.music_square,
                      title: lang.youtubeMusic,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12.0,
                ),
                _ImportDialogTitle(
                  text: lang.matchingType,
                ),
                _ImportOptionCardsRow(
                  cards: [
                    _ImportOptionCard(
                      activeRx: isMatchingTypeLink,
                      icon: Broken.link,
                      title: lang.link,
                    ),
                    _ImportOptionCard(
                      activeRx: isMatchingTypeTitleAndArtist,
                      icon: Broken.text,
                      title: [lang.title, lang.artist].join(' & '),
                    ),
                  ],
                ),
                divider,
                _BackupHistoryBeforeImportTile(
                  activeRx: backupHistoryFirst,
                ),
                const SizedBox(
                  height: 8.0,
                ),
                Obx(
                  (context) => _MatchAllTracksTile(
                    active: matchAll.valueR,
                    onTap: matchAll.toggle,
                    displayPerfWarning: isMatchingTypeTitleAndArtist.valueR, // link matching wont result in perf issue
                  ),
                ),
                const SizedBox(
                  height: 8.0,
                ),
                BetweenDatesTextButton(
                  useHistoryDates: false,
                  maxToday: true,
                  onConfirm: (dates) {
                    oldestDate.value = dates.firstOrNull;
                    newestDate = dates.lastOrNull;
                    NamidaNavigator.inst.closeDialog();
                  },
                ),
              ],
            ),
          ),
        );
      }
    }

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.guide,
        actions: [
          NamidaButton(
            text: lang.folder,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              onConfirm(true);
            },
          ),
          const SizedBox(
            width: 2.0,
          ),
          NamidaButton(
            text: lang.confirm,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              onConfirm(false);
            },
          ),
        ],
        child: NamidaSelectableAutoLinkText(
          text: lang.importYoutubeHistoryGuide(takeoutLink: AppSocial.YOUTUBE_TAKEOUT),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.backupAndRestore,
      subtitle: lang.backupAndRestoreSubtitle,
      icon: Broken.refresh_circle,
      child: SettingSectionsColumn(
        page: this,
      ),
    );
  }
}

class _CreateBackupTile extends StatelessWidget {
  final Color? bgColor;

  const _CreateBackupTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      title: lang.createBackup,
      icon: Broken.box_add,
      trailingRaw: ObxShow(
        showIf: BackupController.inst.isCreatingBackup,
        child: const LoadingIndicator(),
      ),
      onTap: BackupAndRestore._promptCreateBackup,
    );
  }
}

class _RestoreBackupTile extends StatelessWidget {
  final Color? bgColor;

  const _RestoreBackupTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      title: lang.restoreBackup,
      icon: Broken.back_square,
      trailingRaw: ObxShow(
        showIf: BackupController.inst.isRestoringBackup,
        child: const LoadingIndicator(),
      ),
      onTap: BackupAndRestore._promptRestoreBackup,
    );
  }
}

class _DefaultBackupLocationTile extends StatelessWidget {
  final Color? bgColor;

  const _DefaultBackupLocationTile({required this.bgColor});

  Future<void> _pickLocation() async {
    final path = await NamidaFileBrowser.getDirectory(note: lang.defaultBackupLocation);
    if (path != null) settings.defaultBackupLocation.save(path);
  }

  void _openInFileExplorer() {
    final path = settings.defaultBackupLocation.value ?? AppDirs.BACKUPS;
    NamidaChannel.inst.openFileInExplorer(path, isDirectory: true);
  }

  @override
  Widget build(BuildContext context) {
    final openInFileExplorerButton = NamidaChannel.inst.canOpenFileInExplorer
        ? IconButton(
            tooltip: lang.openInFileExplorer,
            onPressed: _openInFileExplorer,
            icon: const Icon(
              Broken.export_1,
              size: 20.0,
            ),
          )
        : null;
    return ObxO(
      rx: settings.defaultBackupLocation,
      builder: (context, defaultBackupLocation) => CustomListTile(
        bgColor: bgColor,
        title: lang.defaultBackupLocation,
        icon: Broken.direct_inbox,
        subtitle: defaultBackupLocation ?? AppDirs.BACKUPS,
        onTap: _pickLocation,
        trailingRaw: openInFileExplorerButton,
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  final Color? bgColor;

  const _SyncTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      title: lang.sync,
      subtitle: lang.syncAppDataBetweenYourDevices,
      icon: Broken.cloud_change,
      onTap: const NamidaSyncManagerPage().navigate,
    );
  }
}

class _ImportDataTile extends StatelessWidget {
  final Color? bgColor;

  const _ImportDataTile({
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final typesText = DataImportType.values.map((e) => e.toText()).join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomListTile(
            title: lang.importData,
            subtitle: typesText,
            icon: Broken.import_2,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 8.0),
            child: Row(
              children: BackupAndRestore._importSources
                  .map(
                    (e) => Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _ImportSourceCard._kMaxWidth),
                        child: SizedBox(
                          width: double.infinity,
                          child: _ImportSourceCard(
                            source: e,
                          ),
                        ),
                      ),
                    ),
                  )
                  .addSeparators(
                    separator: const SizedBox(
                      width: 6.0,
                    ),
                  )
                  .toFixedList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportSourceCard extends StatelessWidget {
  static const _kMaxWidth = 148.0;

  final TrackSource source;

  const _ImportSourceCard({
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final sourceText = source.toText();
    return Stack(
      fit: StackFit.passthrough,
      children: [
        NamidaInkWell(
          borderRadius: 10.0,
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
          bgColor: NColors.cardTheme,
          onTap: () => BackupAndRestore._importFrom(source),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BorderRadiusClip(
                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                child: Image.asset(
                  'assets/icons/${source.name}.png',
                  width: 24.0,
                  height: 24.0,
                ),
              ),
              const SizedBox(
                height: 6.0,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: NamidaText(
                  sourceText,
                  style: const NText(.small, size: .s12),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 2.0,
          right: 2.0,
          child: ParsingJsonPercentage(
            size: 26.0,
            source: source,
            forceDisplay: false,
          ),
        ),
      ],
    );
  }
}

class _BackupItemsTile extends StatelessWidget {
  final RxMap<AppPathsBackupEnum, int> sizesMap;
  final String title;
  final IconData icon;
  final List<AppPathsBackupEnum> items;
  final bool youtubeAvailable;
  final bool youtubeForceFollowItems;
  final List<AppPathsBackupEnum> youtubeItems;

  const _BackupItemsTile({
    required this.sizesMap,
    required this.title,
    required this.icon,
    required this.items,
    required this.youtubeAvailable,
    this.youtubeForceFollowItems = false,
    required this.youtubeItems,
  });

  static (int, bool) _getItemsSize(List<AppPathsBackupEnum> items, Map<AppPathsBackupEnum, int> map) {
    int s = 0;
    bool hasUnknown = false;
    for (final e in items) {
      final size = map[e];
      if (size == null) {
        hasUnknown = true;
      } else {
        s += size;
      }
    }
    return (s, hasUnknown);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final sizes = sizesMap.valueR;
        final localRes = _getItemsSize(items, sizes);
        final ytRes = _getItemsSize(youtubeItems, sizes);
        final localSize = localRes.$1;
        final ytSize = ytRes.$1;
        final localUnknown = localRes.$2;
        final ytUnknown = ytRes.$2;
        return ObxO(
          rx: settings.backupItemslist,
          builder: (context, backupItemslist) {
            bool isActive(List<AppPathsBackupEnum> items) => items.any((element) => backupItemslist.contains(element));

            void onItemTap(List<AppPathsBackupEnum> items) {
              if (isActive(items)) {
                settings.backupItemslist.update((list) => list.removeWhere(items.contains));
              } else {
                settings.backupItemslist.update((list) => list.addAllNoDuplicates(items));
              }
            }

            final isLocalIconChecked = isActive(items);
            final isYoutubeIconChecked = youtubeForceFollowItems
                ? isActive(items)
                : !youtubeAvailable
                ? false
                : youtubeItems.isEmpty
                ? false
                : isActive(youtubeItems);
            return Row(
              children: [
                Expanded(
                  child: ListTileWithCheckMark(
                    active: isLocalIconChecked,
                    titleWidget: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NamidaText(
                          title,
                          style: NText.medium,
                        ),
                        FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isLocalIconChecked ? 1.0 : 0.5,
                                child: NamidaText(
                                  "(${localSize.fileSizeFormatted})${localUnknown ? '?' : ''}",
                                  style: NText.small,
                                ),
                              ),
                              if (ytSize > 0 || ytUnknown)
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isYoutubeIconChecked ? 1.0 : 0.5,
                                  child: NamidaText(
                                    " + (${ytSize.fileSizeFormatted})${ytUnknown ? '?' : ''}",
                                    style: NText.small,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    icon: icon,
                    onTap: () => onItemTap(items),
                  ),
                ),
                const SizedBox(
                  width: 8.0,
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: youtubeAvailable ? 1.0 : 0.1,
                  child: NamidaIconButton(
                    tooltip: () => lang.youtube,
                    horizontalPadding: 0.0,
                    icon: null,
                    onPressed: () {
                      if (youtubeAvailable) {
                        onItemTap(youtubeForceFollowItems ? items : youtubeItems);
                      }
                    },
                    child: StackedIcon(
                      iconSize: 28.0,
                      baseIcon: Broken.video_square,
                      smallChild: NamidaCheckMark(
                        size: 12.0,
                        active: isYoutubeIconChecked,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8.0,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ImportTypesCards extends StatelessWidget {
  final Map<DataImportType, Rx<bool>> typesRx;

  const _ImportTypesCards({
    required this.typesRx,
  });

  @override
  Widget build(BuildContext context) {
    return _ImportOptionCardsRow(
      cards: typesRx.entries
          .map(
            (e) => _ImportOptionCard(
              activeRx: e.value,
              icon: e.key.toIcon(),
              title: e.key.toText(),
            ),
          )
          .toFixedList(),
    );
  }
}

class _ImportOptionCardsRow extends StatelessWidget {
  final List<_ImportOptionCard> cards;

  const _ImportOptionCardsRow({
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards
            .map(
              (e) => Expanded(
                child: e,
              ),
            )
            .addSeparators(
              separator: const SizedBox(
                width: 6.0,
              ),
            )
            .toFixedList(),
      ),
    );
  }
}

class _ImportOptionCard extends StatelessWidget {
  final Rx<bool> activeRx;
  final IconData icon;
  final String title;

  const _ImportOptionCard({
    required this.activeRx,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: activeRx,
      builder: (context, active) => NamidaToggleCard(
        icon: icon,
        title: title,
        showTitle: true,
        active: active,
        onTap: activeRx.toggle,
      ),
    );
  }
}

class _BackupHistoryBeforeImportTile extends StatelessWidget {
  final Rx<bool> activeRx;

  const _BackupHistoryBeforeImportTile({
    required this.activeRx,
  });

  @override
  Widget build(BuildContext context) {
    return ListTileWithCheckMark(
      activeRx: activeRx,
      icon: Broken.shield_tick,
      title: lang.backupHistoryBeforeImporting,
      onTap: activeRx.toggle,
    );
  }
}

class _MatchAllTracksTile extends StatelessWidget {
  final bool active;
  final void Function() onTap;
  final bool displayPerfWarning;

  const _MatchAllTracksTile({
    required this.active,
    required this.onTap,
    required this.displayPerfWarning,
  });

  @override
  Widget build(BuildContext context) {
    return ListTileWithCheckMark(
      title: lang.matchAllTracks,
      subtitle: displayPerfWarning ? '${lang.note}: ${lang.matchAllTracksNote}' : '',
      active: active,
      onTap: onTap,
    );
  }
}

class _ImportDialogTitle extends StatelessWidget {
  final String text;

  const _ImportDialogTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 10.0),
      child: NamidaText(
        "- $text",
        style: NText.large,
      ),
    );
  }
}
