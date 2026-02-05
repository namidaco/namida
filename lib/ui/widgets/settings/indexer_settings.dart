import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/pages/subpages/indexer_missing_tracks_subpage.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

class IndexerSettingsKeysGlobal {
  const IndexerSettingsKeysGlobal._();

  static const foldersToScan = _IndexerSettingsKeys.foldersToScan;
}

enum _IndexerSettingsKeys with SettingKeysBase {
  preventDuplicatedTracks,
  respectNoMedia,
  extractFtArtist,
  groupArtworksByAlbum,
  uniqueArtworkHash,
  albumIdentifiers,
  artistSeparators,
  genreSeparators,
  minimumFileSize,
  minimumTrackDur,
  useMediaStore(NamidaFeaturesAvailablity.android),
  includeVideos,
  refreshOnStartup,
  missingTracks,
  reindex,
  refreshLibrary,
  foldersToScan,
  foldersToExclude,
  ;

  @override
  final NamidaFeaturesAvailablityBase? availability;
  const _IndexerSettingsKeys([this.availability]);
}

class IndexerSettings extends SettingSubpageProvider {
  final bool isInFirstConfigScreen;
  const IndexerSettings({
    super.key,
    super.initialItem,
    this.isInFirstConfigScreen = false,
  });

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.indexer;

  @override
  Map<SettingKeysBase, List<String>> get lookupMap => {
        _IndexerSettingsKeys.preventDuplicatedTracks: [lang.PREVENT_DUPLICATED_TRACKS, lang.PREVENT_DUPLICATED_TRACKS_SUBTITLE],
        _IndexerSettingsKeys.respectNoMedia: [lang.RESPECT_NO_MEDIA, lang.RESPECT_NO_MEDIA_SUBTITLE],
        _IndexerSettingsKeys.extractFtArtist: [lang.EXTRACT_FEAT_ARTIST, lang.EXTRACT_FEAT_ARTIST_SUBTITLE],
        _IndexerSettingsKeys.groupArtworksByAlbum: [lang.GROUP_ARTWORKS_BY_ALBUM],
        _IndexerSettingsKeys.uniqueArtworkHash: [lang.UNIQUE_ARTWORK_HASH],
        _IndexerSettingsKeys.albumIdentifiers: [lang.ALBUM_IDENTIFIERS],
        _IndexerSettingsKeys.artistSeparators: [lang.TRACK_ARTISTS_SEPARATOR],
        _IndexerSettingsKeys.genreSeparators: [lang.TRACK_GENRES_SEPARATOR],
        _IndexerSettingsKeys.minimumFileSize: [lang.MIN_FILE_SIZE],
        _IndexerSettingsKeys.minimumTrackDur: [lang.MIN_FILE_DURATION],
        _IndexerSettingsKeys.useMediaStore: [lang.USE_MEDIA_STORE, lang.USE_MEDIA_STORE_SUBTITLE],
        _IndexerSettingsKeys.includeVideos: [lang.INCLUDE_VIDEOS],
        _IndexerSettingsKeys.refreshOnStartup: [lang.REFRESH_ON_STARTUP],
        _IndexerSettingsKeys.missingTracks: [lang.MISSING_TRACKS],
        _IndexerSettingsKeys.reindex: [lang.RE_INDEX, lang.RE_INDEX_SUBTITLE],
        _IndexerSettingsKeys.refreshLibrary: [lang.REFRESH_LIBRARY, lang.REFRESH_LIBRARY_SUBTITLE],
        _IndexerSettingsKeys.foldersToScan: [lang.LIST_OF_FOLDERS],
        _IndexerSettingsKeys.foldersToExclude: [lang.EXCLUDED_FODLERS],
      };

  void _maybeShowRefreshPromptDialog(bool didModifyFolder) {
    if (!isInFirstConfigScreen) showRefreshPromptDialog(didModifyFolder);
  }

  void _reAuthDirIndex(DirectoryIndexServer e) {
    _pickServerFolder(
      initialType: e.type,
      initialDir: e,
      onSuccessChoose: (dirsPath) {
        settings.removeFromList(directoriesToScan1: e);
        MusicWebServerAuthDetails.manager.deleteFromDb(e);
        settings.save(directoriesToScan: dirsPath);
      },
    );
  }

  void _pickLocalFolder(void Function(List<DirectoryIndex> dirsPath) onSuccessChoose) async {
    final folders = await NamidaFileBrowser.pickDirectories(note: lang.ADD_FOLDER);

    if (folders.isEmpty) {
      snackyy(title: lang.NOTE, message: lang.NO_FOLDER_CHOSEN);
      return;
    }

    onSuccessChoose(folders.map((e) => DirectoryIndexLocal(e.path)).toList());
    _maybeShowRefreshPromptDialog(true);
  }

  void _pickServerFolder({
    required DirectoryIndexType initialType,
    DirectoryIndex? initialDir,
    required void Function(List<DirectoryIndex> dirsPath) onSuccessChoose,
  }) {
    // -- uncomment to support in-place selections
    // final types = List<DirectoryIndexType>.from(DirectoryIndexType.values);
    // types.remove(DirectoryIndexType.unknown);
    // types.remove(DirectoryIndexType.local);
    final types = [initialType];

    final isAuthenticatingRx = false.obs;
    final possibleErrorRx = Rxn<MusicWebServerError>();
    final selectedTypeRx = initialType.obs;
    final legacyAuthRx = false.obs;
    final urlController = TextEditingController(text: initialDir?.source);
    final usernameController = TextEditingController(text: initialDir?.username);
    final passwordController = TextEditingController(text: null);
    final formKey = GlobalKey<FormState>();

    bool isDuplicated(DirectoryIndexServer dir) {
      if (initialDir == null) {
        // -- only if adding new
        if (settings.directoriesToScan.value.any((element) => element == dir)) {
          return true;
        }
      }
      return false;
    }

    String? emptyValidator(String? value) {
      value ??= '';
      if (value.isEmpty) {
        return lang.EMPTY_VALUE;
      }
      return null;
    }

    String? validator(String? value) {
      final v = emptyValidator(value);
      if (v != null) {
        return v;
      }

      final url = urlController.text;
      final username = usernameController.text;
      final selectedType = selectedTypeRx.value;

      if (initialDir == null) {
        // -- only if adding new
        final dir = DirectoryIndexServer(url, selectedType, username);
        if (isDuplicated(dir)) {
          return lang.ALREADY_EXISTS;
        }
      }

      return null;
    }

    String? urlValidator(String? value) {
      final v = validator(value);
      if (v != null) {
        return v;
      }
      final parsedUri = Uri.tryParse(value!);
      if (parsedUri == null) {
        return lang.NAME_CONTAINS_BAD_CHARACTER;
      }
      return null;
    }

    Future<void> authenticate() async {
      if (formKey.currentState!.validate()) {
        final url = urlController.text;
        final username = usernameController.text;
        final password = passwordController.text;
        final selectedType = selectedTypeRx.value;
        final legacyAuth = legacyAuthRx.value;

        final dir = DirectoryIndexServer(url, selectedType, username);
        if (isDuplicated(dir)) {
          return;
        }

        onSuccessChoose([dir]); // before db cuz this could remove old stuff

        final authInfo = MusicWebServerAuthDetails.create(
          dir: dir,
          password: password,
          legacyAuth: legacyAuth,
        );
        await authInfo.saveToDb(dir);
        possibleErrorRx.value = await dir.toWebServer()?.ping();
        if (possibleErrorRx.value != null) {
          return;
        }

        _maybeShowRefreshPromptDialog(true);

        NamidaNavigator.inst.closeDialog();
      }
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        isAuthenticatingRx.close();
        possibleErrorRx.close();
        selectedTypeRx.close();
        legacyAuthRx.close();
        urlController.dispose();
        usernameController.dispose();
        passwordController.dispose();
      },
      dialogBuilder: (theme) => Form(
        key: formKey,
        child: CustomBlurryDialog(
          theme: theme,
          normalTitleStyle: true,
          title: lang.CONFIGURE,
          actions: [
            ObxO(
              rx: isAuthenticatingRx,
              builder: (context, isAuthenticating) => AnimatedEnabled(
                enabled: !isAuthenticating,
                child: const CancelButton(),
              ),
            ),
            ObxO(
              rx: isAuthenticatingRx,
              builder: (context, isAuthenticating) => AnimatedEnabled(
                enabled: !isAuthenticating,
                child: NamidaButton(
                  text: lang.ADD,
                  onPressed: authenticate,
                ),
              ),
            ),
          ],
          child: ObxO(
            rx: selectedTypeRx,
            builder: (context, selectedType) {
              late final demoInfo = selectedType.toDemoInfo();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: types
                          .map(
                            (e) {
                              final isSelected = e == selectedType;
                              final assetImagePath = e.toAssetImage();
                              final assetWidget = assetImagePath == null
                                  ? null
                                  : Image.asset(
                                      assetImagePath,
                                      height: 24.0,
                                    );
                              final color = e.toColor(theme);
                              return Expanded(
                                child: NamidaInkWell(
                                  alignment: Alignment.center,
                                  animationDurationMS: 200,
                                  borderRadius: 8.0,
                                  bgColor: color.withValues(alpha: 0.2),
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    border: isSelected
                                        ? Border.all(
                                            color: color.withValues(alpha: 0.6),
                                            width: 1.2,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                  ),
                                  onTap: () {
                                    selectedTypeRx.value = e;
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (assetWidget != null) ...[
                                        assetWidget,
                                        const SizedBox(width: 12.0),
                                      ],
                                      Flexible(
                                        child: Text(
                                          e.toText(),
                                          style: theme.textTheme.displayMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                          .addSeparators(
                            separator: SizedBox(width: 8.0),
                            skipFirst: 1,
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  NamidaContainerDivider(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                  const SizedBox(height: 12.0),
                  ObxO(
                    rx: legacyAuthRx,
                    builder: (context, value) => CustomSwitchListTile(
                      visualDensity: VisualDensity.compact,
                      title: lang.LEGACY_AUTHENTICATION,
                      value: value,
                      onChanged: (_) => legacyAuthRx.toggle(),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  CustomTagTextField(
                    controller: urlController,
                    hintText: initialDir?.source ?? demoInfo?.url ?? '',
                    labelText: 'URL',
                    validator: urlValidator,
                  ),
                  const SizedBox(height: 12.0),
                  CustomTagTextField(
                    controller: usernameController,
                    hintText: initialDir?.username ?? demoInfo?.username ?? '',
                    labelText: lang.LOGIN,
                    validator: validator,
                  ),
                  const SizedBox(height: 12.0),
                  CustomTagTextField(
                    controller: passwordController,
                    hintText: initialDir != null ? '' : demoInfo?.password ?? '',
                    labelText: lang.PASSWORD,
                    validator: emptyValidator,
                    obscureText: true,
                    maxLines: 1,
                    keyboardType: TextInputType.visiblePassword,
                  ),
                  const SizedBox(height: 8.0),
                  ObxO(
                    rx: possibleErrorRx,
                    builder: (context, err) => err == null
                        ? const SizedBox()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NamidaContainerDivider(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                "${lang.ERROR}: ${err.code}\n${err.message}",
                                style: context.textTheme.displayMedium?.copyWith(
                                  color: const Color.fromARGB(255, 221, 69, 58),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12.0),
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
  }

  void _promptAddFolderType(void Function(List<DirectoryIndex> dirsPath) onSuccessChoose) {
    final types = List<DirectoryIndexType>.from(DirectoryIndexType.values);
    types.remove(DirectoryIndexType.unknown);
    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        title: lang.CHOOSE,
        actions: const [
          CancelButton(),
        ],
        child: Column(
          children: types.map(
            (e) {
              final assetImagePath = e.toAssetImage();
              final assetWidget = assetImagePath == null
                  ? null
                  : Image.asset(
                      assetImagePath,
                      height: 24.0,
                    );
              return CustomListTile(
                visualDensity: VisualDensity.compact,
                icon: assetWidget != null ? null : e.toIcon(),
                leading: assetWidget,
                title: e.toText(),
                subtitle: e.toSubtitle(),
                onTap: () async {
                  NamidaNavigator.inst.closeDialog();
                  switch (e) {
                    case DirectoryIndexType.local:
                      _pickLocalFolder(onSuccessChoose);
                    case DirectoryIndexType.subsonic:
                      _pickServerFolder(initialType: e, onSuccessChoose: onSuccessChoose);
                    case DirectoryIndexType.unknown:
                  }
                },
              );
            },
          ).toList(),
        ),
      ),
    );
  }

  Widget getMediaStoreWidget() {
    return getItemWrapper(
      key: _IndexerSettingsKeys.useMediaStore,
      child: Obx(
        (context) => CustomSwitchListTile(
          bgColor: getBgColor(_IndexerSettingsKeys.useMediaStore),
          icon: Broken.airdrop,
          title: lang.USE_MEDIA_STORE,
          subtitle: lang.USE_MEDIA_STORE_SUBTITLE,
          value: settings.useMediaStore.valueR,
          onChanged: (isTrue) {
            settings.save(useMediaStore: !isTrue);
            _maybeShowRefreshPromptDialog(false);
          },
        ),
      ),
    );
  }

  Widget getIncludeVideosWidget() {
    return getItemWrapper(
      key: _IndexerSettingsKeys.includeVideos,
      child: ObxO(
        rx: settings.includeVideos,
        builder: (context, includeVideos) => CustomSwitchListTile(
          bgColor: getBgColor(_IndexerSettingsKeys.includeVideos),
          leading: StackedIcon(
            baseIcon: Broken.video_play,
            secondaryIcon: Broken.tick_circle,
            secondaryIconSize: 12.0,
          ),
          title: lang.INCLUDE_VIDEOS,
          value: includeVideos,
          onChanged: (isTrue) {
            settings.save(includeVideos: !isTrue);
            _maybeShowRefreshPromptDialog(false);
          },
        ),
      ),
    );
  }

  Widget getGroupArtworksByAlbumWidget() {
    return getItemWrapper(
      key: _IndexerSettingsKeys.groupArtworksByAlbum,
      child: Obx(
        (context) => AnimatedEnabled(
          enabled: !settings.uniqueArtworkHash.valueR,
          child: CustomSwitchListTile(
            bgColor: getBgColor(_IndexerSettingsKeys.groupArtworksByAlbum),
            icon: Broken.backward_item,
            title: lang.GROUP_ARTWORKS_BY_ALBUM,
            subtitle: lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING,
            value: settings.groupArtworksByAlbum.valueR,
            onChanged: (isTrue) {
              settings.save(groupArtworksByAlbum: !isTrue);
              _showReindexingPrompt(title: lang.GROUP_ARTWORKS_BY_ALBUM, body: lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING);
            },
          ),
        ),
      ),
    );
  }

  Widget getFoldersToScanWidget({
    required BuildContext context,
    bool initiallyExpanded = false,
  }) {
    final textTheme = context.textTheme;
    return getItemWrapper(
      key: _IndexerSettingsKeys.foldersToScan,
      child: Obx(
        (context) {
          final mediaStoreEnabled = settings.useMediaStore.valueR;
          return NamidaExpansionTile(
            bgColor: getBgColor(_IndexerSettingsKeys.foldersToScan),
            bigahh: false,
            compact: false,
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            initiallyExpanded: initiallyExpanded || initialItem == _IndexerSettingsKeys.foldersToScan,
            icon: Broken.folder,
            titleText: lang.LIST_OF_FOLDERS,
            textColor: textTheme.displayLarge!.color,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamidaButton(
                  icon: Broken.folder_add,
                  text: lang.ADD,
                  onPressed: () {
                    _promptAddFolderType((dirsPath) {
                      settings.save(directoriesToScan: dirsPath);
                    });
                  },
                ),
                const SizedBox(width: 8.0),
                const Icon(Broken.arrow_down_2),
              ],
            ),
            children: [
              ...settings.directoriesToScan.valueR.map(
                (e) {
                  final assetImagePath = e.type.toAssetImage();
                  final assetWidget = assetImagePath == null
                      ? null
                      : Image.asset(
                          assetImagePath,
                          height: 20.0,
                        );
                  final isServer = e is DirectoryIndexServer;
                  return CustomListTile(
                    visualDensity: VisualDensity.compact,
                    leading: assetWidget ??
                        Icon(
                          e.type.toIcon(),
                          size: 20.0,
                        ),
                    title: e.source,
                    subtitle: isServer
                        ? [
                            e.type.toText(),
                            e.username,
                          ].joinText(separator: ' - ')
                        : mediaStoreEnabled
                            ? lang.MEDIA_STORE_IS_ENABLED_THIS_WILL_HAVE_NO_EFFECT
                            : null,
                    trailingRaw: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isServer)
                          IconButton(
                            onPressed: () => _reAuthDirIndex(e),
                            icon: Obx(
                              (context) {
                                final hasAuth = MusicWebServerAuthDetails.manager.dirHasAuthInfoR(e);
                                return hasAuth
                                    ? const Icon(
                                        Broken.lock,
                                        size: 20.0,
                                      )
                                    : const StackedIcon(
                                        baseIcon: Broken.lock,
                                        iconSize: 20.0,
                                        secondaryIcon: Broken.danger,
                                        secondaryIconSize: 13.0,
                                      );
                              },
                            ),
                          ),
                        TextButton(
                          onPressed: () {
                            if (settings.directoriesToScan.length == 1) {
                              snackyy(
                                title: lang.MINIMUM_ONE_ITEM,
                                message: lang.MINIMUM_ONE_FOLDER_SUBTITLE,
                                displayDuration: SnackDisplayDuration.veryLong,
                              );
                            } else {
                              String bodyText = "${lang.REMOVE} \"${e.source}\"?";
                              if (e.isServer) {
                                final title = '${e.type.toText()} - ${e.username ?? '?'}';
                                bodyText += "\n$title";
                              }
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
                                        if (isServer) MusicWebServerAuthDetails.manager.deleteFromDb(e);
                                        NamidaNavigator.inst.closeDialog();
                                        _maybeShowRefreshPromptDialog(true);
                                      },
                                    ),
                                  ],
                                  bodyText: bodyText,
                                ),
                              );
                            }
                          },
                          child: NamidaButtonText(
                            lang.REMOVE.toUpperCase(),
                            style: const TextStyle(fontSize: 14.0),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget getFoldersToExcludeWidget({
    required BuildContext context,
    bool initiallyExpanded = false,
  }) {
    final textTheme = context.textTheme;
    return getItemWrapper(
      key: _IndexerSettingsKeys.foldersToExclude,
      child: ObxO(
        rx: settings.directoriesToExclude,
        builder: (context, directoriesToExclude) => NamidaExpansionTile(
          bgColor: getBgColor(_IndexerSettingsKeys.foldersToExclude),
          bigahh: false,
          compact: false,
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          initiallyExpanded: initiallyExpanded || initialItem == _IndexerSettingsKeys.foldersToExclude,
          icon: Broken.folder_minus,
          titleText: lang.EXCLUDED_FODLERS,
          textColor: textTheme.displayLarge!.color,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NamidaButton(
                icon: Broken.folder_add,
                text: lang.ADD,
                onPressed: () {
                  _pickLocalFolder((dirsPath) {
                    settings.save(directoriesToExclude: dirsPath);
                  });
                },
              ),
              const SizedBox(width: 8.0),
              const Icon(Broken.arrow_down_2),
            ],
          ),
          children: directoriesToExclude.isEmpty
              ? [
                  ListTile(
                    title: Text(
                      lang.NO_EXCLUDED_FOLDERS,
                      style: textTheme.displayMedium,
                    ),
                  ),
                ]
              : [
                  ...directoriesToExclude.map(
                    (e) => CustomListTile(
                      title: e.source,
                      subtitle: e.username,
                      trailingRaw: TextButton(
                        onPressed: () {
                          settings.removeFromList(directoriesToExclude1: e);
                          _maybeShowRefreshPromptDialog(true);
                        },
                        child: NamidaButtonText(
                          lang.REMOVE.toUpperCase(),
                          style: const TextStyle(fontSize: 14.0),
                        ),
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
    final textTheme = context.textTheme;
    const refreshIconKey1 = 'kurukuru';
    const refreshIconKey2 = 'kururin';

    final useMediaStoreWidget = getMediaStoreWidget();
    final includeVideosWidget = getIncludeVideosWidget();
    return SettingsCard(
      title: lang.INDEXER,
      subtitle: lang.INDEXER_SUBTITLE,
      icon: Broken.component,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NamidaIconButton(
            icon: Broken.refresh_2,
            tooltip: () => lang.REFRESH_LIBRARY,
            onPressed: () => showRefreshPromptDialog(false),
            child: const RefreshLibraryIcon(widgetKey: refreshIconKey2),
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
              child: ObxO(
                rx: Indexer.inst.allAudioFiles,
                builder: (context, allAudioFiles) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ObxO(
                      rx: Indexer.inst.tracksInfoList,
                      builder: (context, tracksInfoList) => StatsContainer(
                        icon: Broken.info_circle,
                        title: '${lang.TRACKS_INFO} :',
                        value: tracksInfoList.length.formatDecimal(),
                        total: allAudioFiles.isEmpty ? null : allAudioFiles.length.formatDecimal(),
                      ),
                    ),
                    ObxO(
                      rx: Indexer.inst.artworksInStorage,
                      builder: (context, artworksInStorage) => StatsContainer(
                        icon: Broken.image,
                        title: '${lang.ARTWORKS} :',
                        value: artworksInStorage == 0 ? '?' : artworksInStorage.formatDecimal(),
                        total: allAudioFiles.isEmpty ? null : allAudioFiles.length.formatDecimal(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              lang.INDEXER_NOTE,
              style: textTheme.displaySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Obx(
              (context) => Text(
                '${lang.DUPLICATED_TRACKS}: ${Indexer.inst.duplicatedTracksLength.valueR}\n${lang.TRACKS_EXCLUDED_BY_NOMEDIA}: ${Indexer.inst.tracksExcludedByNoMedia.valueR}\n${lang.FILTERED_BY_SIZE_AND_DURATION}: ${Indexer.inst.filteredForSizeDurationTracks.valueR}',
                style: textTheme.displaySmall,
              ),
            ),
          ),
          const _ExtractingPathsWidget(itemPadding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0)),
          getItemWrapper(
            key: _IndexerSettingsKeys.preventDuplicatedTracks,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.preventDuplicatedTracks),
                icon: Broken.copy,
                title: lang.PREVENT_DUPLICATED_TRACKS,
                subtitle: "${lang.PREVENT_DUPLICATED_TRACKS_SUBTITLE}. ${lang.INDEX_REFRESH_REQUIRED}",
                onChanged: (isTrue) => settings.save(preventDuplicatedTracks: !isTrue),
                value: settings.preventDuplicatedTracks.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.respectNoMedia,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.respectNoMedia),
                enabled: !settings.useMediaStore.valueR,
                icon: Broken.cd,
                title: lang.RESPECT_NO_MEDIA,
                subtitle: "${lang.RESPECT_NO_MEDIA_SUBTITLE}. ${lang.INDEX_REFRESH_REQUIRED}",
                onChanged: (isTrue) => settings.save(respectNoMedia: !isTrue),
                value: settings.useMediaStore.valueR ? false : settings.respectNoMedia.valueR,
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.extractFtArtist,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.extractFtArtist),
                icon: Broken.microphone,
                title: lang.EXTRACT_FEAT_ARTIST,
                subtitle: "${lang.EXTRACT_FEAT_ARTIST_SUBTITLE} ${lang.INSTANTLY_APPLIES}.",
                onChanged: (isTrue) async {
                  settings.save(extractFeatArtistFromTitle: !isTrue);
                  Indexer.inst.rebuildTracksAfterExtractFeatArtistChanges();
                },
                value: settings.extractFeatArtistFromTitle.valueR,
              ),
            ),
          ),
          getGroupArtworksByAlbumWidget(),
          getItemWrapper(
            key: _IndexerSettingsKeys.uniqueArtworkHash,
            child: Obx(
              (context) => AnimatedEnabled(
                enabled: !settings.groupArtworksByAlbum.valueR,
                child: CustomSwitchListTile(
                  bgColor: getBgColor(_IndexerSettingsKeys.uniqueArtworkHash),
                  leading: StackedIcon(
                    baseIcon: Broken.gallery,
                    secondaryIcon: Broken.cpu,
                    secondaryIconSize: 13.0,
                  ),
                  title: lang.UNIQUE_ARTWORK_HASH,
                  subtitle: "${lang.PERFORMANCE_NOTE}. ${lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING}",
                  value: settings.uniqueArtworkHash.valueR,
                  onChanged: (isTrue) {
                    settings.save(uniqueArtworkHash: !isTrue);
                    _showReindexingPrompt(title: lang.UNIQUE_ARTWORK_HASH, body: lang.REQUIRES_CLEARING_IMAGE_CACHE_AND_RE_INDEXING);
                  },
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.albumIdentifiers,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.albumIdentifiers),
                icon: Broken.arrow_square,
                title: lang.ALBUM_IDENTIFIERS,
                trailingText: settings.albumIdentifiers.length.toString(),
                onTap: () {
                  final tempList = List<AlbumIdentifier>.from(settings.albumIdentifiers.value).obs;
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
                          (context) {
                            return NamidaButton(
                              enabled: settings.albumIdentifiers.valueR.any((element) => !tempList.contains(element)) ||
                                  tempList.valueR.any((element) => !settings.albumIdentifiers.contains(element)), // isEqualTo wont work cuz order shouldnt matter
                              text: lang.SAVE,
                              onPressed: () async {
                                NamidaNavigator.inst.closeDialog();
                                settings.removeFromList(albumIdentifiersAll: AlbumIdentifier.values);
                                settings.save(albumIdentifiers: tempList.value);
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
                                    (context) => ListTileWithCheckMark(
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
              (context) => CustomListTile(
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
              (context) => CustomListTile(
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
            child: ObxO(
              rx: settings.indexMinFileSizeInB,
              builder: (context, indexMinFileSizeInB) => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.minimumFileSize),
                icon: Broken.unlimited,
                title: lang.MIN_FILE_SIZE,
                subtitle: lang.INDEX_REFRESH_REQUIRED,
                trailing: NamidaWheelSlider(
                  width: 100.0,
                  max: 1024,
                  multiplier: (1024 * 10),
                  initValue: indexMinFileSizeInB,
                  onValueChanged: (val) => settings.save(indexMinFileSizeInB: val),
                  text: indexMinFileSizeInB.fileSizeFormatted,
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.minimumTrackDur,
            child: ObxO(
              rx: settings.indexMinDurationInSec,
              builder: (context, indexMinDurationInSec) => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.minimumTrackDur),
                icon: Broken.timer_1,
                title: lang.MIN_FILE_DURATION,
                subtitle: lang.INDEX_REFRESH_REQUIRED,
                trailing: NamidaWheelSlider(
                  width: 100.0,
                  max: 180,
                  initValue: indexMinDurationInSec,
                  onValueChanged: (val) => settings.save(indexMinDurationInSec: val),
                  text: "$indexMinDurationInSec s",
                ),
              ),
            ),
          ),
          useMediaStoreWidget,
          includeVideosWidget,
          getItemWrapper(
            key: _IndexerSettingsKeys.refreshOnStartup,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.refreshOnStartup),
                icon: Broken.d_rotate,
                title: lang.REFRESH_ON_STARTUP,
                value: settings.refreshOnStartup.valueR,
                onChanged: (isTrue) => settings.save(refreshOnStartup: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _IndexerSettingsKeys.missingTracks,
            child: CustomListTile(
              bgColor: getBgColor(_IndexerSettingsKeys.missingTracks),
              icon: Broken.location_cross,
              title: lang.MISSING_TRACKS,
              trailing: const Icon(Broken.arrow_right_3),
              onTap: () {
                if (BackupController.inst.isCreatingBackup.value ||
                    BackupController.inst.isRestoringBackup.value ||
                    HistoryController.inst.isLoadingHistory ||
                    YoutubeHistoryController.inst.isLoadingHistory ||
                    JsonToHistoryParser.inst.isParsing.value) {
                  snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
                  return;
                }
                const IndexerMissingTracksSubpage().navigate();
              },
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
                            style: textTheme.displayMedium,
                          ),
                          const SizedBox(height: 16.0),
                          ObxO(
                            rx: Indexer.inst.artworksSizeInStorage,
                            builder: (context, artworksSizeInStorage) => ObxO(
                              rx: clearArtworks,
                              builder: (context, active) => ListTileWithCheckMark(
                                dense: true,
                                icon: Broken.broom,
                                title: lang.CLEAR_IMAGE_CACHE,
                                subtitle: artworksSizeInStorage.fileSizeFormatted,
                                active: active,
                                onTap: clearArtworks.toggle,
                              ),
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
              leading: const RefreshLibraryIcon(widgetKey: refreshIconKey1),
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

    final updatingLibrary = false.obs;

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        updatingLibrary.close();
        separatorsController.dispose();
      },
      onDismissing: isBlackListDialog
          ? null
          : () async {
              updatingLibrary.value = true;
              Indexer.inst.rebuildTracksAfterSplitConfigChanges();
            },
      durationInMs: 200,
      dialog: CustomBlurryDialog(
        title: title,
        actions: [
          if (!isBlackListDialog)
            NamidaButton(
              textWidget: Obx((context) {
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
            (context) => updatingLibrary.valueR
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
              style: namida.textTheme.displaySmall,
            ),
            const SizedBox(
              height: 12.0,
            ),
            Obx(
              (context) => Wrap(
                children: [
                  ...itemsList.valueR.map(
                    (e) => Container(
                      margin: const EdgeInsets.all(4.0),
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: namida.theme.cardTheme.color,
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
                style: namida.textTheme.displaySmall?.copyWith(fontSize: 16.0, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  errorMaxLines: 3,
                  isDense: true,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                    borderSide: BorderSide(color: namida.theme.colorScheme.onSurface.withAlpha(100), width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    borderSide: BorderSide(color: namida.theme.colorScheme.onSurface.withAlpha(100), width: 1.0),
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
  final settingsServers = settings.directoriesToScan.value.allServers();
  final hasServer = settingsServers.isNotEmpty || allTracksInLibrary.any((element) => element.isNetwork);
  if (!hasServer && newPathsLength == 0 && deletedPathLength == 0) {
    snackyy(title: lang.NOTE, message: lang.NO_CHANGES_FOUND);
  } else {
    String bodyText = lang.PROMPT_INDEXING_REFRESH
        .replaceFirst(
          '_NEW_FILES_',
          newPathsLength.toString(),
        )
        .replaceFirst(
          '_DELETED_FILES_',
          deletedPathLength.toString(),
        );
    if (hasServer) {
      final tracksServers = <String, bool>{};
      for (final trExt in Indexer.inst.allTracksMappedByPath.values) {
        final s = trExt.server;
        if (s != null) {
          tracksServers[s] ??= false;
        }
      }
      final servers = <DirectoryIndexServer, bool>{};
      for (final s in settingsServers) {
        servers[s] = true;
      }
      for (final ts in tracksServers.entries) {
        if (servers.keys.any((element) => element.source == ts.key)) {
          // already exists and more detailed
        } else {
          final dir = DirectoryIndexServer.parseFromEncodedUrlPath(ts.key);
          servers[dir] ??= ts.value;
        }
      }
      final serversText = servers.keys.toBodyText(stillExistsCallback: (d) => servers[d]);
      bodyText = '${lang.LOCAL}:\n$bodyText\n\n$serversText';
    }
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.NOTE,
        bodyText: bodyText,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.REFRESH,
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              await Future.delayed(const Duration(milliseconds: 300));
              VideoController.inst.rescanLocalVideosPaths();
              await Indexer.inst.refreshLibraryAndCheckForDiff(
                currentFiles: currentFiles,
              );
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

class RefreshLibraryIcon extends StatefulWidget {
  final String widgetKey;
  final Color? color;
  final double? size;

  const RefreshLibraryIcon({
    super.key,
    required this.widgetKey,
    this.color,
    this.size,
  });

  @override
  State<RefreshLibraryIcon> createState() => RefreshLibraryIconState();
}

class RefreshLibraryIconState extends State<RefreshLibraryIcon> with TickerProviderStateMixin {
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
        size: widget.size,
        color: widget.color ?? context.defaultIconColor(),
      ),
    );
  }
}

class _ExtractingPathsWidget extends StatefulWidget {
  final EdgeInsetsGeometry itemPadding;
  const _ExtractingPathsWidget({required this.itemPadding});

  @override
  State<_ExtractingPathsWidget> createState() => __ExtractingPathsWidgetState();
}

class __ExtractingPathsWidgetState extends State<_ExtractingPathsWidget> {
  bool _isPathsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return NamidaInkWell(
      onTap: () => setState(() => _isPathsExpanded = !_isPathsExpanded),
      child: Obx(
        (context) {
          final paths = NamidaTaggerController.inst.currentPathsBeingExtracted.values;
          return paths.isEmpty
              ? const SizedBox()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: paths
                      .map((e) => Padding(
                            padding: widget.itemPadding,
                            child: Text(
                              e,
                              maxLines: _isPathsExpanded ? null : 1,
                              overflow: _isPathsExpanded ? null : TextOverflow.ellipsis,
                              style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                            ),
                          ))
                      .toList(),
                );
        },
      ),
    );
  }
}
