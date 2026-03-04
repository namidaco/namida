import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

enum _BackupAndRestoreKeys with SettingKeysBase {
  create,
  restore,
  defaultLocation,
  autoBackupInterval,
  crossPlatformSync,
  importYT,
  importLastfm,
}

class BackupAndRestore extends SettingSubpageProvider {
  const BackupAndRestore({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.backupRestore;

  @override
  Map<SettingKeysBase, List<String>> get lookupMap => {
    _BackupAndRestoreKeys.create: [lang.createBackup],
    _BackupAndRestoreKeys.restore: [lang.restoreBackup],
    _BackupAndRestoreKeys.defaultLocation: [lang.defaultBackupLocation],
    _BackupAndRestoreKeys.autoBackupInterval: [lang.autoBackupInterval],
    _BackupAndRestoreKeys.crossPlatformSync: [lang.crossPlatformSync],
    _BackupAndRestoreKeys.importYT: [lang.importYoutubeHistory],
    _BackupAndRestoreKeys.importLastfm: [lang.importLastFmHistory],
  };

  bool _canDoImport({required bool isYT}) {
    if (JsonToHistoryParser.inst.isParsing.value || HistoryController.inst.isLoadingHistory || (isYT && YoutubeHistoryController.inst.isLoadingHistory)) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return false;
    }
    return true;
  }

  bool _canCreateRestoreBackup() {
    if (JsonToHistoryParser.inst.isParsing.value || HistoryController.inst.isLoadingHistory || YoutubeHistoryController.inst.isLoadingHistory) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return false;
    }
    return true;
  }

  Widget getDivider() => const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0));

  Widget matchAllTracksListTile({required bool active, required void Function() onTap, required bool displayPerfWarning}) {
    return ListTileWithCheckMark(
      title: lang.matchAllTracks,
      subtitle: displayPerfWarning ? '${lang.note}: ${lang.matchAllTracksNote}' : '',
      active: active,
      onTap: onTap,
    );
  }

  Widget getRestoreBackupWidget() {
    return getItemWrapper(
      key: _BackupAndRestoreKeys.restore,
      child: CustomListTile(
        bgColor: getBgColor(_BackupAndRestoreKeys.restore),
        title: lang.restoreBackup,
        icon: Broken.back_square,
        trailingRaw: ObxShow(
          showIf: BackupController.inst.isRestoringBackup,
          child: const LoadingIndicator(),
        ),
        onTap: () async {
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
        },
      ),
    );
  }

  Widget getDefaultBackupLocationWidget() {
    return getItemWrapper(
      key: _BackupAndRestoreKeys.defaultLocation,
      child: Obx(
        (context) => CustomListTile(
          bgColor: getBgColor(_BackupAndRestoreKeys.defaultLocation),
          title: lang.defaultBackupLocation,
          icon: Broken.direct_inbox,
          subtitle: settings.defaultBackupLocation.valueR ?? AppDirs.BACKUPS,
          onTap: () async {
            final path = await NamidaFileBrowser.getDirectory(note: lang.defaultBackupLocation);

            if (path != null) {
              settings.save(defaultBackupLocation: path);
            }
          },
          trailingRaw: NamidaChannel.inst.canOpenFileInExplorer
              ? IconButton(
                  tooltip: lang.openInFileExplorer,
                  onPressed: () {
                    final path = settings.defaultBackupLocation.value ?? AppDirs.BACKUPS;
                    NamidaChannel.inst.openFileInExplorer(path, isDirectory: true);
                  },
                  icon: const Icon(
                    Broken.export_1,
                    size: 20.0,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _openNamidaSync() async {
    final backupFolder = settings.defaultBackupLocation.value ?? AppDirs.BACKUPS;
    final musicFolders = settings.directoriesToScan.value;

    final musicFoldersJoined = musicFolders.where((e) => e.sourceRaw.isNotEmpty).map((e) => e).join(',');

    bool requiresDownload = false;
    try {
      if (Platform.isAndroid) {
        final didOpen = await NamidaChannel.inst.openNamidaSync(backupFolder, musicFoldersJoined);
        if (!didOpen) requiresDownload = true;
      } else if (Platform.isWindows) {
        File? exeFile = File(r'C:\Program Files\namida_sync\namida_sync.exe');
        if (!await exeFile.exists()) {
          exeFile = await NamidaFileBrowser.pickFile(note: "${lang.pickFromStorage}: namida_sync.exe", allowedExtensions: NamidaFileExtensionsWrapper.exe);
        }
        if (exeFile == null || !await exeFile.exists()) {
          requiresDownload = true;
        } else {
          final args = ['--backupPath="$backupFolder"', '--musicFolders="$musicFoldersJoined"'];
          await Process.run(exeFile.path, args);
        }
      } else if (Platform.isLinux) {
        File? exeFile;
        final commonPaths = [
          '/usr/local/bin/namida_sync',
          '/usr/bin/namida_sync',
          '${NamidaPlatformBuilder.linuxUserHome ?? '~'}/.local/bin/namida_sync',
        ];

        for (final path in commonPaths) {
          final file = File(path);
          if (await file.exists()) {
            exeFile = file;
            break;
          }
        }
        exeFile ??= await NamidaFileBrowser.pickFile(
          note: "${lang.pickFromStorage}: namida_sync",
          allowedExtensions: null,
        );

        if (exeFile == null || !await exeFile.exists()) {
          requiresDownload = true;
        } else {
          final args = ['--backupPath="$backupFolder"', '--musicFolders="$musicFoldersJoined"'];
          await Process.run(exeFile.path, args);
        }
      } else {
        final uri = Uri(
          scheme: 'namidasync',
          host: 'config',
          queryParameters: {
            'backupPath': backupFolder,
            'musicFolders': musicFoldersJoined,
          },
        );
        final url = uri.toString();
        final didOpen = await NamidaLinkUtils.openLink(url);
        if (!didOpen) requiresDownload = true;
      }
    } catch (e) {
      snackyy(message: e.toString(), isError: true);
    }

    if (requiresDownload) {
      try {
        await NamidaLinkUtils.openLink(AppSocial.NAMIDA_SYNC_GITHUB_RELEASE);
      } catch (e) {
        snackyy(message: e.toString(), isError: true);
      }
    }
  }

  void _ensureNewBackupItemsIncluded(List<AppPathsBackupEnum> items) {
    int includedCount = 0;
    final settingItems = settings.backupItemslist.value ?? AppPathsBackupEnumCategories.everything;
    for (final item in items) {
      final isIncluded = settingItems.contains(item);
      if (isIncluded) includedCount++;
    }
    if (includedCount > 0 && includedCount < items.length) {
      // -- if a new item was added in an update while old
      // -- settings still apply, this should fix it
      settings.save(backupItemslist: items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return SettingsCard(
      title: lang.backupAndRestore,
      subtitle: lang.backupAndRestoreSubtitle,
      icon: Broken.refresh_circle,
      child: Column(
        children: [
          // TODO(feat): option inside namida to move track in android.

          // -- Create Backup
          getItemWrapper(
            key: _BackupAndRestoreKeys.create,
            child: CustomListTile(
              bgColor: getBgColor(_BackupAndRestoreKeys.create),
              title: lang.createBackup,
              icon: Broken.box_add,
              trailingRaw: ObxShow(
                showIf: BackupController.inst.isCreatingBackup,
                child: const LoadingIndicator(),
              ),
              onTap: () {
                if (!_canCreateRestoreBackup()) return;

                final sizesMap = <AppPathsBackupEnum, int>{}.obs;

                void fillAllItemsSize() async {
                  for (final item in AppPathsBackupEnum.values) {
                    if (item.isDir) {
                      sizesMap[item] = await Directory(item.resolve()).getTotalSize() ?? 0;
                    } else {
                      sizesMap[item] = await File(item.resolve()).fileSize() ?? 0;
                    }
                  }
                }

                fillAllItemsSize();

                (int, bool) getItemsSize(List<AppPathsBackupEnum> items, Map<AppPathsBackupEnum, int> map) {
                  int s = 0;
                  bool hasUnknown = false;
                  items.loop((e) {
                    if (map[e] == null) {
                      hasUnknown = true;
                    } else {
                      s += map[e]!;
                    }
                  });
                  return (s, hasUnknown);
                }

                Widget getItemWidget({
                  required String title,
                  required IconData icon,
                  required List<AppPathsBackupEnum> items,
                  required bool youtubeAvailable,
                  bool youtubeForceFollowItems = false,
                  required List<AppPathsBackupEnum> youtubeItems,
                }) {
                  _ensureNewBackupItemsIncluded(items);
                  _ensureNewBackupItemsIncluded(youtubeItems);
                  return Obx(
                    (context) {
                      final localRes = getItemsSize(items, sizesMap.valueR);
                      final ytRes = getItemsSize(youtubeItems, sizesMap.valueR);
                      final localSize = localRes.$1;
                      final ytSize = ytRes.$1;
                      final localUnknown = localRes.$2;
                      final ytUnknown = ytRes.$2;
                      return ObxO(
                        rx: settings.backupItemslist,
                        builder: (context, backupItemslist) {
                          backupItemslist ??= AppPathsBackupEnumCategories.everything;

                          bool isActive(List<AppPathsBackupEnum> items) => items.any((element) => backupItemslist!.contains(element));

                          void onItemTap(List<AppPathsBackupEnum> items) {
                            if (isActive(items)) {
                              settings.removeFromList(backupItemslistAll: items);
                            } else {
                              settings.save(backupItemslist: items);
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
                              const SizedBox(width: 8.0),
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
                              const SizedBox(width: 8.0),
                            ],
                          );
                        },
                      );
                    },
                  );
                }

                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.createBackup,
                    actions: [
                      const CancelButton(),
                      ObxO(
                        rx: settings.backupItemslist,
                        builder: (context, backupItemslist) {
                          backupItemslist ??= AppPathsBackupEnumCategories.everything;
                          return AnimatedEnabled(
                            enabled: backupItemslist.isNotEmpty,
                            child: NamidaButton(
                              text: lang.createBackup,
                              onPressed: () {
                                final items = settings.backupItemslist.value ?? AppPathsBackupEnumCategories.everything;
                                if (items.isNotEmpty) {
                                  NamidaNavigator.inst.closeDialog();
                                  final rawPaths = items.map((e) => e.resolve()).toList();
                                  BackupController.inst.createBackupFile(rawPaths);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                    child: SizedBox(
                      height: namida.height / 2,
                      child: SmoothSingleChildScrollView(
                        child: Column(
                          children: [
                            getItemWidget(
                              title: lang.database,
                              icon: Broken.box_1,
                              items: AppPathsBackupEnumCategories.database,
                              youtubeAvailable: true,
                              youtubeItems: AppPathsBackupEnumCategories.database_yt,
                            ),
                            getItemWidget(
                              title: lang.playlists,
                              icon: Broken.music_library_2,
                              items: AppPathsBackupEnumCategories.playlists,
                              youtubeAvailable: true,
                              youtubeItems: AppPathsBackupEnumCategories.playlists_yt,
                            ),
                            getItemWidget(
                              title: lang.history,
                              icon: Broken.refresh,
                              items: AppPathsBackupEnumCategories.history,
                              youtubeAvailable: true,
                              youtubeItems: AppPathsBackupEnumCategories.history_yt,
                            ),
                            getItemWidget(
                              title: lang.settings,
                              icon: Broken.setting,
                              items: AppPathsBackupEnumCategories.settings,
                              youtubeAvailable: false,
                              youtubeItems: [],
                            ),
                            getItemWidget(
                              title: lang.lyrics,
                              icon: Broken.document,
                              items: AppPathsBackupEnumCategories.lyrics,
                              youtubeAvailable: false,
                              youtubeItems: [],
                            ),
                            getItemWidget(
                              title: lang.queues,
                              icon: Broken.driver,
                              items: AppPathsBackupEnumCategories.queues,
                              youtubeAvailable: false,
                              youtubeItems: [],
                            ),
                            getItemWidget(
                              title: lang.colorPalettes,
                              icon: Broken.colorfilter,
                              items: AppPathsBackupEnumCategories.palette,
                              youtubeAvailable: true,
                              youtubeForceFollowItems: false,
                              youtubeItems: AppPathsBackupEnumCategories.palette_yt,
                            ),
                            getItemWidget(
                              title: lang.videoCache,
                              icon: Broken.video,
                              items: AppPathsBackupEnumCategories.videos_cache,
                              youtubeAvailable: false,
                              youtubeForceFollowItems: true,
                              youtubeItems: [],
                            ),
                            getItemWidget(
                              title: lang.audioCache,
                              icon: Broken.audio_square,
                              items: AppPathsBackupEnumCategories.audios_cache,
                              youtubeAvailable: false,
                              youtubeForceFollowItems: true,
                              youtubeItems: [],
                            ),
                            getItemWidget(
                              title: lang.artworks,
                              icon: Broken.image,
                              items: AppPathsBackupEnumCategories.artworks,
                              youtubeAvailable: false,
                              youtubeItems: [],
                            ),
                            getItemWidget(
                              title: lang.thumbnails,
                              icon: Broken.image,
                              items: AppPathsBackupEnumCategories.thumbnails,
                              youtubeAvailable: true,
                              youtubeItems: AppPathsBackupEnumCategories.thumbnails_yt,
                            ),
                            getItemWidget(
                              title: lang.metadataCache,
                              icon: Broken.message_text,
                              items: AppPathsBackupEnumCategories.youtipie_cache,
                              youtubeAvailable: true,
                              youtubeForceFollowItems: true,
                              youtubeItems: [],
                            ),
                          ].addSeparators(separator: const SizedBox(height: 8.0)).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // -- Restore Backup
          getRestoreBackupWidget(),

          // -- Default Backup Location
          getDefaultBackupLocationWidget(),

          // -- Auto backup interval
          getItemWrapper(
            key: _BackupAndRestoreKeys.autoBackupInterval,
            child: CustomListTile(
              bgColor: getBgColor(_BackupAndRestoreKeys.autoBackupInterval),
              title: lang.autoBackupInterval,
              icon: Broken.timer,
              trailing: Obx(
                (context) {
                  final days = settings.autoBackupIntervalDays.valueR;
                  return NamidaWheelSlider(
                    max: 14,
                    initValue: days,
                    onValueChanged: (val) => settings.save(autoBackupIntervalDays: val),
                    text: days == 0 ? lang.none : "$days ${days == 1 ? lang.day : lang.days}",
                  );
                },
              ),
            ),
          ),

          getItemWrapper(
            key: _BackupAndRestoreKeys.crossPlatformSync,
            child: CustomListTile(
              bgColor: getBgColor(_BackupAndRestoreKeys.crossPlatformSync),
              title: lang.crossPlatformSync,
              icon: Broken.cloud_change,
              onTap: _openNamidaSync,
            ),
          ),

          // -- Import Youtube History
          getItemWrapper(
            key: _BackupAndRestoreKeys.importYT,
            child: CustomListTile(
              bgColor: getBgColor(_BackupAndRestoreKeys.importYT),
              title: lang.importYoutubeHistory,
              leading: StackedIcon(
                baseIcon: Broken.import_2,
                smallChild: BorderRadiusClip(
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                  child: Image.asset(
                    'assets/icons/youtube.png',
                    width: 12,
                    height: 12,
                  ),
                ),
              ),
              trailing: const SizedBox(
                height: 32.0,
                width: 32.0,
                child: ParsingJsonPercentage(
                  size: 32.0,
                  source: TrackSource.youtube,
                  forceDisplay: false,
                ),
              ),
              onTap: () {
                if (!_canDoImport(isYT: true)) return;

                void onConfirm(bool pickDirectory) async {
                  Widget getTitleText(String text) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: 10.0)),
                    child: Text("- $text", style: namida.textTheme.displayLarge),
                  );

                  var jsonfiles = <File>[];
                  Directory? mainDirectory;
                  if (pickDirectory) {
                    mainDirectory = await NamidaFileBrowser.pickDirectory(note: lang.importYoutubeHistory);
                  } else {
                    jsonfiles = await NamidaFileBrowser.pickFiles(note: lang.importYoutubeHistory, allowedExtensions: NamidaFileExtensionsWrapper.jsonAndZip);
                  }
                  if (jsonfiles.isNotEmpty || mainDirectory != null) {
                    final isMatchingTypeLink = true.obs;
                    final isMatchingTypeTitleAndArtist = false.obs;
                    final matchYT = true.obs;
                    final matchYTMusic = true.obs;
                    final matchAll = false.obs;
                    final oldestDate = Rxn<DateTime>();
                    DateTime? newestDate;
                    NamidaNavigator.inst.navigateDialog(
                      onDisposing: () {
                        isMatchingTypeLink.close();
                        isMatchingTypeTitleAndArtist.close();
                        matchYT.close();
                        matchYTMusic.close();
                        matchAll.close();
                        oldestDate.close();
                      },
                      dialog: CustomBlurryDialog(
                        title: lang.configure,
                        actions: [
                          Obx(
                            (context) => NamidaButton(
                              enabled: isMatchingTypeLink.valueR || isMatchingTypeTitleAndArtist.valueR,
                              textWidget: Obx((context) => Text(oldestDate.valueR != null ? lang.importTimeRange : lang.importAll)),
                              onPressed: () async {
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
                                );
                              },
                            ),
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            getTitleText(lang.source),
                            ListTileWithCheckMark(
                              activeRx: matchYT,
                              title: lang.youtube,
                              onTap: matchYT.toggle,
                            ),
                            const SizedBox(height: 8.0),
                            ListTileWithCheckMark(
                              activeRx: matchYTMusic,
                              title: lang.youtubeMusic,
                              onTap: matchYTMusic.toggle,
                            ),
                            getDivider(),
                            getTitleText(lang.matchingType),
                            ListTileWithCheckMark(
                              activeRx: isMatchingTypeLink,
                              title: lang.link,
                              onTap: isMatchingTypeLink.toggle,
                            ),
                            const SizedBox(height: 8.0),
                            ListTileWithCheckMark(
                              activeRx: isMatchingTypeTitleAndArtist,
                              title: [lang.title, lang.artist].join(' & '),
                              onTap: isMatchingTypeTitleAndArtist.toggle,
                            ),
                            getDivider(),
                            Obx(
                              (context) => matchAllTracksListTile(
                                active: matchAll.valueR,
                                onTap: matchAll.toggle,
                                displayPerfWarning: isMatchingTypeTitleAndArtist.valueR, // link matching wont result in perf issue
                              ),
                            ),
                            getDivider(),
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
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          onConfirm(true);
                        },
                      ),
                      SizedBox(width: 2.0),
                      NamidaButton(
                        text: lang.confirm,
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          onConfirm(false);
                        },
                      ),
                    ],
                    child: NamidaSelectableAutoLinkText(
                      text: lang.importYoutubeHistoryGuide(takeoutLink: 'https://takeout.google.com/takeout/custom/youtube'),
                    ),
                  ),
                );
              },
            ),
          ),

          // -- Import last.fm History
          getItemWrapper(
            key: _BackupAndRestoreKeys.importLastfm,
            child: CustomListTile(
              bgColor: getBgColor(_BackupAndRestoreKeys.importLastfm),
              title: lang.importLastFmHistory,
              leading: StackedIcon(
                baseIcon: Broken.import_2,
                smallChild: BorderRadiusClip(
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                  child: Image.asset(
                    'assets/icons/lastfm.png',
                    width: 12,
                    height: 12,
                  ),
                ),
              ),
              trailing: const SizedBox(
                height: 32.0,
                width: 32.0,
                child: ParsingJsonPercentage(
                  size: 32.0,
                  source: TrackSource.lastfm,
                  forceDisplay: false,
                ),
              ),
              onTap: () {
                if (!_canDoImport(isYT: false)) return;

                void onConfirm(bool pickDirectory) async {
                  var csvFiles = <File>[];
                  Directory? mainDirectory;
                  if (pickDirectory) {
                    mainDirectory = await NamidaFileBrowser.pickDirectory(note: lang.importLastFmHistory);
                  } else {
                    csvFiles = await NamidaFileBrowser.pickFiles(note: lang.importLastFmHistory, allowedExtensions: NamidaFileExtensionsWrapper.csv);
                  }

                  if (csvFiles.isNotEmpty || mainDirectory != null) {
                    final oldestDate = Rxn<DateTime>();
                    DateTime? newestDate;
                    final matchAll = false.obs;
                    NamidaNavigator.inst.navigateDialog(
                      onDisposing: () {
                        oldestDate.close();
                        matchAll.close();
                      },
                      dialog: CustomBlurryDialog(
                        horizontalInset: 38.0,
                        verticalInset: 38.0,
                        title: lang.configure,
                        actions: [
                          const CancelButton(),
                          NamidaButton(
                            textWidget: Obx((context) => Text(oldestDate.valueR != null ? lang.importTimeRange : lang.importAll)),
                            onPressed: () async {
                              NamidaNavigator.inst.closeDialog();
                              await JsonToHistoryParser.inst.addFilesSourceToNamidaHistory(
                                files: csvFiles,
                                mainDirectory: mainDirectory,
                                source: TrackSource.lastfm,
                                oldestDate: oldestDate.value,
                                newestDate: newestDate,
                                matchAll: matchAll.value,
                              );
                            },
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(
                              (context) => matchAllTracksListTile(
                                active: matchAll.valueR,
                                onTap: matchAll.toggle,
                                displayPerfWarning: true,
                              ),
                            ),
                            getDivider(),
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
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          onConfirm(true);
                        },
                      ),
                      SizedBox(width: 2.0),
                      NamidaButton(
                        text: lang.confirm,
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          onConfirm(false);
                        },
                      ),
                    ],
                    child: NamidaSelectableAutoLinkText(
                      text: lang.importLastFmHistoryGuide(lastfmCsvLink: 'https://benjaminbenben.com/lastfm-to-csv/'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
