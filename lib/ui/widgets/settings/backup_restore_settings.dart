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
        aliases: () => [lang.syncAppDataBetweenYourDevices],
        tile: (args) => _SyncTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingCustom(
        title: () => lang.importYoutubeHistory,
        tile: (args) => _ImportHistoryTile(
          bgColor: args.bgColor,
          source: TrackSource.youtube,
          title: lang.importYoutubeHistory,
          onTap: _importYoutubeHistory,
        ),
      ),
      SettingCustom(
        title: () => lang.importLastFmHistory,
        tile: (args) => _ImportHistoryTile(
          bgColor: args.bgColor,
          source: TrackSource.lastfm,
          title: lang.importLastFmHistory,
          onTap: _importLastFmHistory,
        ),
      ),
      SettingCustom(
        title: () => lang.importSpotifyHistory,
        tile: (args) => _ImportHistoryTile(
          bgColor: args.bgColor,
          source: TrackSource.spotify,
          title: lang.importSpotifyHistory,
          onTap: _importSpotifyHistory,
        ),
      ),
      SettingCustom(
        title: () => lang.importListenBrainzHistory,
        tile: (args) => _ImportHistoryTile(
          bgColor: args.bgColor,
          source: TrackSource.listenbrainz,
          title: lang.importListenBrainzHistory,
          onTap: _importListenBrainzHistory,
        ),
      ),
    ],
  ];

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
  //         '${NamidaPlatformBuilder.linuxUserHome ?? '~'}/.local/bin/namida_sync',
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

  static void _importLastFmHistory() {
    _importGeneralNonYTSource(
      source: TrackSource.lastfm,
      title: lang.importLastFmHistory,
      guideWithLink: lang.importLastFmHistoryGuide(lastfmCsvLink: 'https://benjaminbenben.com/lastfm-to-csv'),
      allowedExtensions: NamidaFileExtensionsWrapper.csv,
    );
  }

  static void _importSpotifyHistory() {
    _importGeneralNonYTSource(
      source: TrackSource.spotify,
      title: lang.importSpotifyHistory,
      guideWithLink: lang.importSpotifyHistoryGuide(link: 'https://www.spotify.com/account/privacy'),
      allowedExtensions: NamidaFileExtensionsWrapper.jsonAndZip,
    );
  }

  static void _importListenBrainzHistory() {
    _importGeneralNonYTSource(
      source: TrackSource.listenbrainz,
      title: lang.importListenBrainzHistory,
      guideWithLink: lang.importListenBrainzHistoryGuide(link: 'https://listenbrainz.org/settings/export'),
      allowedExtensions: NamidaFileExtensionsWrapper.jsonlAndZip,
    );
  }

  static void _importGeneralNonYTSource({
    required TrackSource source,
    required String title,
    required String guideWithLink,
    required NamidaFileExtensionsWrapper allowedExtensions,
  }) {
    if (!_canDoImport(isYT: false)) return;

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
        final oldestDate = Rxn<DateTime>();
        DateTime? newestDate;
        final matchAll = false.obs;
        final backupHistoryFirst = true.obs;
        NamidaNavigator.inst.navigateDialog(
          onDisposing: () {
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
                  text: oldestDate.valueR != null ? lang.importTimeRange : lang.importAll,
                  onTap: () async {
                    NamidaNavigator.inst.closeDialog();
                    await JsonToHistoryParser.inst.addFilesSourceToNamidaHistory(
                      files: selectedFiles,
                      mainDirectory: mainDirectory,
                      source: source,
                      oldestDate: oldestDate.value,
                      newestDate: newestDate,
                      matchAll: matchAll.value,
                      backupHistoryFirst: backupHistoryFirst.value,
                    );
                  },
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackupHistoryBeforeImportTile(
                  activeRx: backupHistoryFirst,
                ),
                divider,
                Obx(
                  (context) => _MatchAllTracksTile(
                    active: matchAll.valueR,
                    onTap: matchAll.toggle,
                    displayPerfWarning: true,
                  ),
                ),
                divider,
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

  static void _importYoutubeHistory() {
    if (!_canDoImport(isYT: true)) return;

    const divider = NamidaContainerDivider(
      margin: EdgeInsets.symmetric(vertical: 8.0),
    );

    void onConfirm(bool pickDirectory) async {
      var jsonfiles = <File>[];
      Directory? mainDirectory;
      if (pickDirectory) {
        mainDirectory = await NamidaFileBrowser.pickDirectory(note: lang.importYoutubeHistory);
      } else {
        jsonfiles = await NamidaFileBrowser.pickFiles(note: lang.importYoutubeHistory, allowedExtensions: NamidaFileExtensionsWrapper.jsonHtmlAndZip);
      }
      if (jsonfiles.isNotEmpty || mainDirectory != null) {
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
                (context) => NamidaButton(
                  enabled: isMatchingTypeLink.valueR || isMatchingTypeTitleAndArtist.valueR,
                  text: oldestDate.valueR != null ? lang.importTimeRange : lang.importAll,
                  onTap: () async {
                    NamidaNavigator.inst.closeDialog();
                    await JsonToHistoryParser.inst.addFilesSourceToNamidaHistory(
                      files: jsonfiles,
                      mainDirectory: mainDirectory,
                      source: TrackSource.youtube,
                      ytIsMatchingTypeLink: isMatchingTypeLink.value,
                      isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist.value,
                      ytMatchYT: matchYT.value,
                      ytMatchYTMusic: matchYTMusic.value,
                      oldestDate: oldestDate.value,
                      newestDate: newestDate,
                      matchAll: matchAll.value,
                      backupHistoryFirst: backupHistoryFirst.value,
                    );
                  },
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackupHistoryBeforeImportTile(
                  activeRx: backupHistoryFirst,
                ),
                divider,
                _ImportDialogTitle(
                  text: lang.source,
                ),
                ListTileWithCheckMark(
                  activeRx: matchYT,
                  title: lang.youtube,
                  onTap: matchYT.toggle,
                ),
                const SizedBox(
                  height: 8.0,
                ),
                ListTileWithCheckMark(
                  activeRx: matchYTMusic,
                  title: lang.youtubeMusic,
                  onTap: matchYTMusic.toggle,
                ),
                divider,
                _ImportDialogTitle(
                  text: lang.matchingType,
                ),
                ListTileWithCheckMark(
                  activeRx: isMatchingTypeLink,
                  title: lang.link,
                  onTap: isMatchingTypeLink.toggle,
                ),
                const SizedBox(
                  height: 8.0,
                ),
                ListTileWithCheckMark(
                  activeRx: isMatchingTypeTitleAndArtist,
                  title: [lang.title, lang.artist].join(' & '),
                  onTap: isMatchingTypeTitleAndArtist.toggle,
                ),
                divider,
                Obx(
                  (context) => _MatchAllTracksTile(
                    active: matchAll.valueR,
                    onTap: matchAll.toggle,
                    displayPerfWarning: isMatchingTypeTitleAndArtist.valueR, // link matching wont result in perf issue
                  ),
                ),
                divider,
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

class _ImportHistoryTile extends StatelessWidget {
  final Color? bgColor;
  final TrackSource source;
  final String title;
  final void Function() onTap;

  const _ImportHistoryTile({
    required this.bgColor,
    required this.source,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      title: title,
      leading: StackedIcon(
        baseIcon: Broken.import_2,
        smallChild: BorderRadiusClip(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          child: Image.asset(
            'assets/icons/${source.name}.png',
            width: 12.0,
            height: 12.0,
          ),
        ),
      ),
      trailing: SizedBox(
        height: 32.0,
        width: 32.0,
        child: ParsingJsonPercentage(
          size: 32.0,
          source: source,
          forceDisplay: false,
        ),
      ),
      onTap: onTap,
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
    final textTheme = context.textTheme;
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
                        Text(
                          title,
                          style: textTheme.displayMedium,
                        ),
                        FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isLocalIconChecked ? 1.0 : 0.5,
                                child: Text(
                                  "(${localSize.fileSizeFormatted})${localUnknown ? '?' : ''}",
                                  style: textTheme.displaySmall,
                                ),
                              ),
                              if (ytSize > 0 || ytUnknown)
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isYoutubeIconChecked ? 1.0 : 0.5,
                                  child: Text(
                                    " + (${ytSize.fileSizeFormatted})${ytUnknown ? '?' : ''}",
                                    style: textTheme.displaySmall,
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
      child: Text(
        "- $text",
        style: context.textTheme.displayLarge,
      ),
    );
  }
}
