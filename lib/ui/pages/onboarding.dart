import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/permission_manager/permission_manager.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/ui/pages/sync_manager_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/backup_restore_settings.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class FirstRunConfigureScreen extends StatefulWidget {
  const FirstRunConfigureScreen({super.key});

  @override
  State<FirstRunConfigureScreen> createState() => _FirstRunConfigureScreenState();
}

class _FirstRunConfigureScreenState extends State<FirstRunConfigureScreen> {
  bool didGrantStoragePermission = false;
  bool didDenyStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermission(request: false); // just to set it to true only if granted.
  }

  Future<void> _requestPermission({bool request = true}) async {
    didGrantStoragePermission = await PermissionManager.platform.requestStoragePermission(request: request);
    if (request) didDenyStoragePermission = !didGrantStoragePermission; // if user denied permission after requested
    if (mounted) setState(() {});
  }

  void _navigateToNamida(NamidaRouteWidget? pageAfterFirstLoad) async {
    if (!didGrantStoragePermission) {
      snackyy(
        title: lang.storagePermissionDenied,
        message: lang.storagePermissionDeniedSubtitle,
        top: false,
        isError: true,
      );
      return;
    }

    if (pageAfterFirstLoad != null) NamidaNavigator.inst.openAfterFirstLoad(pageAfterFirstLoad);
    NamidaNavigator.inst.navigateToRootReplacement(
      const MainPageWrapper(),
    );
    Indexer.inst.prepareTracksFile();
    return QueueController.inst.prepareLatestQueueAndLatestPlayedForSourceAsync();
  }

  Future<void> _onContinueTap([NamidaRouteWidget? pageAfterFirstLoad]) async {
    await _requestPermission();
    if (BackupController.inst.isRestoringBackup.value) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return;
    }
    _navigateToNamida(pageAfterFirstLoad);
  }

  void _onSyncTap() => _onContinueTap(const NamidaSyncManagerPage());

  void _onRestoreBackupTap() async {
    await _requestPermission();
    if (!didGrantStoragePermission) return;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.refresh_circle,
        normalTitleStyle: true,
        title: lang.backupAndRestore,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          children: [
            SettingEntryTile(
              entry: BackupAndRestore.restoreBackup,
            ),
            SettingEntryTile(
              entry: BackupAndRestore.defaultBackupLocation,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.width; // use context as dimensions might not be initialized yet

    Dimensions.inst.availableAppContentWidth = maxWidth;

    const firstConfigIndexer = IndexerSettings(isInFirstConfigScreen: true);
    // final useMediaStore = indexer.getMediaStoreWidget();

    final returningUserRow = _ReturningUserRow(
      onRestoreBackupTap: _onRestoreBackupTap,
      onSyncTap: _onSyncTap,
    );

    final languageTile = SettingEntryTile(
      entry: ThemeSetting.language,
    );
    final themeTile = SettingEntryTile(
      entry: ThemeSetting.themeMode,
    );
    final performanceTile = SettingEntryTile(
      entry: AdvancedSettings.performanceMode,
    );
    final libraryTabsTile = SettingEntryTile(
      entry: ExtrasSettings.libraryTabs,
    );

    final storagePermissionTile = NamidaFeaturesVisibility.isStoragePermissionNotRequired
        ? null
        : _StoragePermissionTile(
            isGranted: didGrantStoragePermission,
            isDenied: didDenyStoragePermission,
            onTap: _requestPermission,
          );
    final addFolderWidget = SettingEntryTile(
      entry: IndexerSettings.addFolder,
      page: firstConfigIndexer,
    );
    final foldersToScan = SettingEntryTile(
      entry: IndexerSettings.foldersToScan,
      page: firstConfigIndexer,
    );
    final foldersToExclude = SettingEntryTile(
      entry: IndexerSettings.foldersToExclude,
      page: firstConfigIndexer,
    );
    final includeVideosWidget = SettingEntryTile(
      entry: IndexerSettings.includeVideos,
      page: firstConfigIndexer,
    );
    final minFileDurationTile = SettingEntryTile(
      entry: IndexerSettings.minFileDuration,
      page: firstConfigIndexer,
    );
    final minFileSizeTile = SettingEntryTile(
      entry: IndexerSettings.minFileSize,
      page: firstConfigIndexer,
    );
    final albumIdentifiersTile = SettingEntryTile(
      entry: IndexerSettings.albumIdentifiers,
      page: firstConfigIndexer,
    );
    final respectNoMediaTile = SettingEntryTile(
      entry: IndexerSettings.respectNoMedia,
      page: firstConfigIndexer,
    );
    final artworkCacheWidget = SettingEntryTile(
      entry: IndexerSettings.artworkCache,
      page: firstConfigIndexer,
    );

    final sections = <List<Widget>>[
      [
        returningUserRow,
      ],
      [
        languageTile,
        themeTile,
        performanceTile,
        libraryTabsTile,
      ],
      [
        ?storagePermissionTile,
        addFolderWidget,
        foldersToScan,
        foldersToExclude,
        includeVideosWidget,
        minFileDurationTile,
        minFileSizeTile,
        // useMediaStore,
        albumIdentifiersTile,
        respectNoMediaTile,
        artworkCacheWidget,
      ],
    ];
    final sectionsWidgets = sections
        .map(
          (section) => Column(
            mainAxisSize: MainAxisSize.min,
            children: section,
          ),
        )
        .addSeparators(
          separator: SettingSectionsColumn.sectionsDivider,
        )
        .toFixedList();

    return BackgroundWrapper(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // always enable for a sneak peak?
          // if (NamidaJellys.enabled)
          const Positioned.fill(
            child: IgnorePointer(
              child: JellyField(
                count: 4,
                opacity: 0.3,
                minHeight: 90.0,
                maxHeight: 240.0,
                seed: 3,
              ),
            ),
          ),

          SizedBox(
            height: context.height * 0.78,
            width: context.width,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context)),
              child: SettingsCard(
                icon: Broken.candle,
                title: lang.configure,
                subtitle: lang.setupFirstStartup,
                childRaw: Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: NamidaScrollbarWithController(
                            showOnStart: true,
                            child: (c) => SuperSmoothListView(
                              controller: c,
                              padding: EdgeInsets.zero,
                              children: sectionsWidgets,
                            ),
                          ),
                        ),
                        NContainer(
                          decoration: (colors) => BoxDecoration(
                            color: Color.alphaBlend(colors.scaffold.withOpacityExt(0.7), colors.card),
                            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: didGrantStoragePermission ? 1.0 : 0.5,
                            child: NamidaInkWell(
                              onTap: _onContinueTap,
                              borderRadius: 8.0,
                              bgColor: NColors.card,
                              margin: const EdgeInsets.all(12.0),
                              padding: const EdgeInsets.all(12.0),
                              child: const Icon(
                                Broken.arrow_right,
                                size: 24.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturningUserRow extends StatelessWidget {
  final void Function() onRestoreBackupTap;
  final void Function() onSyncTap;

  const _ReturningUserRow({
    required this.onRestoreBackupTap,
    required this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: ObxO(
              rx: BackupController.inst.isRestoringBackup,
              builder: (context, isRestoringBackup) => NBuilder(
                selfAnimated: true,
                builder: (context, colors) => NamidaInkWellButton(
                  bgColor: colors.secondaryContainer.withOpacityExt(0.2),
                  centered: true,
                  paddingMultiplier: 1.65,
                  icon: Broken.back_square,
                  text: lang.restoreBackup,
                  enabled: !isRestoringBackup,
                  onTap: onRestoreBackupTap,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: NBuilder(
              selfAnimated: true,
              builder: (context, colors) => NamidaInkWellButton(
                bgColor: colors.secondaryContainer.withOpacityExt(0.2),
                centered: true,
                paddingMultiplier: 1.65,
                icon: Broken.cloud_change,
                text: lang.sync,
                onTap: onSyncTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoragePermissionTile extends StatelessWidget {
  final bool isGranted;
  final bool isDenied;
  final void Function() onTap;

  const _StoragePermissionTile({
    required this.isGranted,
    required this.isDenied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isGranted
        ? Colors.green.withOpacityExt(0.3)
        : isDenied
        ? Colors.red.withOpacityExt(0.3)
        : Colors.transparent;
    return NamidaInkWell(
      animationDurationMS: 100,
      decoration: BoxDecoration(
        border: Border.all(
          width: 1.5,
          color: borderColor,
        ),
      ),
      onTap: onTap,
      borderRadius: isGranted ? 8.0 : 16.0,
      bgColor: NColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: NamidaText(
              lang.grantStoragePermission,
              style: NText.medium,
            ),
          ),
          const SizedBox(width: 12.0),
          NamidaCheckMark(
            size: 18.0,
            active: isGranted,
            burst: true,
          ),
        ],
      ),
    );
  }
}
