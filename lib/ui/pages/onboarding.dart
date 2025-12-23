import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
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

  late final ScrollController c;

  final _shouldShowGlow = false.obs;

  void _scrollListener() {
    if (c.hasClients) {
      if (c.position.extentAfter > 0) {
        _shouldShowGlow.value = true;
      } else {
        _shouldShowGlow.value = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    c = ScrollController()..addListener(_scrollListener);
    Timer(Duration.zero, _scrollListener);

    _requestPermission(request: false); // just to set it to true only if granted.
  }

  @override
  void dispose() {
    c.dispose();
    _shouldShowGlow.close();
    super.dispose();
  }

  Future<void> _requestPermission({bool request = true}) async {
    didGrantStoragePermission = await requestStoragePermission(request: request);
    if (request) didDenyStoragePermission = !didGrantStoragePermission; // if user denied permission after requested
    if (mounted) setState(() {});
  }

  void _navigateToNamida() async {
    if (!didGrantStoragePermission) {
      snackyy(
        title: lang.STORAGE_PERMISSION_DENIED,
        message: lang.STORAGE_PERMISSION_DENIED_SUBTITLE,
        top: false,
        isError: true,
      );
      return;
    }

    NamidaNavigator.inst.navigateToRootReplacement(
      MainPageWrapper(
        shouldShowOnBoarding: false,
      ),
    );
    Indexer.inst.prepareTracksFile();
    return QueueController.inst.prepareLatestQueueAsync();
  }

  void _onRestoreBackupIconTap() async {
    await _requestPermission();
    if (!didGrantStoragePermission) return;
    const backupAndRestore = BackupAndRestore();
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.refresh_circle,
        normalTitleStyle: true,
        title: lang.BACKUP_AND_RESTORE,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          children: [
            backupAndRestore.getRestoreBackupWidget(),
            backupAndRestore.getDefaultBackupLocationWidget(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final maxWidth = context.width; // use context as dimensions might not be initialized yet

    const indexer = IndexerSettings();
    final useMediaStore = indexer.getMediaStoreWidget();
    final includeVideosWidget = indexer.getIncludeVideosWidget();
    final foldersToScan = indexer.getFoldersToScanWidget(context: context, initiallyExpanded: true);
    final foldersToExclude = indexer.getFoldersToExcludeWidget(context: context, initiallyExpanded: true);
    final groupArtworksByAlbum = indexer.getGroupArtworksByAlbumWidget();

    const themeSettings = ThemeSetting();
    final themeTile = themeSettings.getThemeTile(maxWidth: maxWidth);
    final languageTile = themeSettings.getLanguageTile(context);

    const extras = ExtrasSettings();
    final libraryTabsTile = extras.getLibraryTabsTile(context);

    const advanced = AdvancedSettings();
    final performanceTile = advanced.getPerformanceTile(context);

    return BackgroundWrapper(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: context.height * 0.7,
            width: context.width,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context)),
              child: SettingsCard(
                icon: Broken.candle,
                title: lang.CONFIGURE,
                subtitle: lang.SETUP_FIRST_STARTUP,
                trailing: Column(
                  children: [
                    NamidaIconButton(
                      tooltip: () => lang.RESTORE_BACKUP,
                      icon: Broken.back_square,
                      onPressed: _onRestoreBackupIconTap,
                    ),
                    const SizedBox(height: 2.0),
                    ObxShow(
                      showIf: BackupController.inst.isRestoringBackup,
                      child: const LoadingIndicator(),
                    ),
                  ],
                ),
                childRaw: Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              SuperSmoothListView(
                                controller: c,
                                padding: EdgeInsets.zero,
                                children: [
                                  themeTile,
                                  languageTile,
                                  performanceTile,
                                  libraryTabsTile,
                                  useMediaStore,
                                  includeVideosWidget,
                                  groupArtworksByAlbum,
                                  foldersToScan,
                                  foldersToExclude,
                                ],
                              ),
                              Obx(
                                (context) => SizedBox(
                                  height: 12.0,
                                  width: context.width,
                                  child: AnimatedDecoration(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: _shouldShowGlow.valueR ? CurrentColor.inst.color.withValues(alpha: 0.5) : Colors.transparent,
                                          blurRadius: 12.0,
                                          spreadRadius: 2.0,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(theme.scaffoldBackgroundColor.withValues(alpha: 0.7), theme.cardColor),
                            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                          ),
                          child: Row(
                            children: [
                              if (!NamidaFeaturesVisibility.isStoragePermissionNotRequired)
                                Expanded(
                                  child: NamidaInkWell(
                                    animationDurationMS: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        width: 1.5,
                                        color: didGrantStoragePermission
                                            ? Colors.green.withValues(alpha: 0.3)
                                            : didDenyStoragePermission
                                                ? Colors.red.withValues(alpha: 0.3)
                                                : Colors.transparent,
                                      ),
                                    ),
                                    onTap: _requestPermission,
                                    borderRadius: didGrantStoragePermission ? 8.0 : 16.0,
                                    bgColor: theme.cardColor,
                                    margin: const EdgeInsets.all(12.0),
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lang.GRANT_STORAGE_PERMISSION,
                                            style: textTheme.displayMedium,
                                          ),
                                        ),
                                        const SizedBox(width: 12.0),
                                        NamidaCheckMark(
                                          size: 16.0,
                                          active: didGrantStoragePermission,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Flexible(
                                flex: NamidaFeaturesVisibility.isStoragePermissionNotRequired ? 1 : 0,
                                fit: NamidaFeaturesVisibility.isStoragePermissionNotRequired ? FlexFit.tight : FlexFit.loose,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 400),
                                  opacity: didGrantStoragePermission ? 1.0 : 0.5,
                                  child: NamidaInkWell(
                                    width: NamidaFeaturesVisibility.isStoragePermissionNotRequired ? null : maxWidth * 0.2,
                                    onTap: () async {
                                      await _requestPermission();
                                      if (BackupController.inst.isRestoringBackup.value) {
                                        snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
                                        return;
                                      }
                                      _navigateToNamida();
                                    },
                                    borderRadius: 8.0,
                                    bgColor: theme.cardColor,
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
                        )
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
