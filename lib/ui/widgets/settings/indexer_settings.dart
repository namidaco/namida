import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/current_color.dart';
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
  artworksCache,
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
    _IndexerSettingsKeys.preventDuplicatedTracks: [lang.preventDuplicatedTracks, lang.preventDuplicatedTracksSubtitle],
    _IndexerSettingsKeys.respectNoMedia: [lang.respectNoMedia, lang.respectNoMediaSubtitle],
    _IndexerSettingsKeys.extractFtArtist: [lang.extractFeatArtist, lang.extractFeatArtistSubtitle],
    _IndexerSettingsKeys.artworksCache: [lang.enableArtworkCache, lang.enableArtworkCacheSubtitle],
    _IndexerSettingsKeys.groupArtworksByAlbum: [lang.groupArtworksByAlbum],
    _IndexerSettingsKeys.uniqueArtworkHash: [lang.uniqueArtworkHash],
    _IndexerSettingsKeys.albumIdentifiers: [lang.albumIdentifiers],
    _IndexerSettingsKeys.artistSeparators: [lang.trackArtistsSeparator],
    _IndexerSettingsKeys.genreSeparators: [lang.trackGenresSeparator],
    _IndexerSettingsKeys.minimumFileSize: [lang.minFileSize],
    _IndexerSettingsKeys.minimumTrackDur: [lang.minFileDuration],
    _IndexerSettingsKeys.useMediaStore: [lang.useMediaStore, lang.useMediaStoreSubtitle],
    _IndexerSettingsKeys.includeVideos: [lang.includeVideos],
    _IndexerSettingsKeys.refreshOnStartup: [lang.refreshOnStartup],
    _IndexerSettingsKeys.missingTracks: [lang.missingTracks],
    _IndexerSettingsKeys.reindex: [lang.reIndex, lang.reIndexSubtitle],
    _IndexerSettingsKeys.refreshLibrary: [lang.refreshLibrary, lang.refreshLibrarySubtitle],
    _IndexerSettingsKeys.foldersToScan: [lang.listOfFolders],
    _IndexerSettingsKeys.foldersToExclude: [lang.excludedFodlers],
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
    final folders = await NamidaFileBrowser.pickDirectories(note: lang.addFolder);

    if (folders.isEmpty) {
      snackyy(title: lang.note, message: lang.noFolderChosen);
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

    final isURLHost = initialType.check(.isURLHost);
    final initialSource = initialDir?.sourceRaw;

    final isAuthenticatingRx = false.obs;
    final possibleErrorRx = Rxn<MusicWebServerError>();
    final selectedTypeRx = initialType.obs;
    final legacyAuthRx = initialType.check(.legacyAuthOnly) ? null : false.obs;
    final urlOrHostController = TextEditingController(text: initialSource);
    final usernameController = TextEditingController(text: initialDir?.username);
    final passwordController = TextEditingController(text: null);
    final shareController = initialType.check(.supportsShare) ? TextEditingController(text: null) : null;
    final subdirController = initialType.check(.supportsSubdir) ? TextEditingController(text: null) : null;
    final portController = initialType.check(.supportsSubdir) ? TextEditingController(text: null) : null;
    final availableSharesRx = shareController == null ? null : <String>{}.obs;
    final formKey = GlobalKey<FormState>();

    if (availableSharesRx != null) {
      initialDir?.toWebServer()?.getAvailableShares().catchError((_) => null).then(
        (value) {
          availableSharesRx.value = value ?? <String>{};
        },
      );
    }

    String? initialDirSourceHint = initialSource;
    String? shareHint;
    String? subdirHint;
    String? portHint;
    if (initialSource != null && isURLHost) {
      try {
        final parsed = SMBServerInfo.fromUrl(initialSource);
        initialDirSourceHint = parsed.host;
        shareHint = parsed.share;
        subdirHint = parsed.subdir;
        portHint = parsed.port?.toString();

        urlOrHostController.text = parsed.host;
        shareController?.text = parsed.share ?? '';
        subdirController?.text = parsed.subdir ?? '';
        portController?.text = parsed.port?.toString() ?? '';
      } catch (_) {}
    }

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
        return lang.emptyValue;
      }
      return null;
    }

    String? validator(String? value) {
      final v = emptyValidator(value);
      if (v != null) {
        return v;
      }

      // -- we already remove before adding
      // final urlOrHost = urlOrHostController.text;
      // final username = usernameController.text;
      // final selectedType = selectedTypeRx.value;

      // if (initialDir == null) {
      //   // -- only if adding new

      //   final dir = isURLHost
      //       ? DirectoryIndexServer.fromHost(
      //           urlOrHost,
      //           shareController?.text,
      //           subdirController?.text,
      //           selectedType,
      //           username,
      //           portController?.text,
      //         )
      //       : DirectoryIndexServer.raw(urlOrHost, selectedType, username);
      //   if (isDuplicated(dir)) {
      //     return lang.alreadyExists;
      //   }
      // }

      return null;
    }

    String? urlValidator(String? value) {
      final v = validator(value);
      if (v != null) {
        return v;
      }
      if (!isURLHost) {
        final parsedUri = Uri.tryParse(value!);
        if (parsedUri == null) {
          return lang.nameContainsBadCharacter;
        }
      }

      return null;
    }

    Future<void> authenticateRaw() async {
      if (formKey.currentState!.validate()) {
        final urlOrHost = urlOrHostController.text;
        final username = usernameController.text;
        final password = passwordController.text;
        final share = shareController?.text;
        final subdir = subdirController?.text;
        final port = portController?.text;
        final selectedType = selectedTypeRx.value;
        final legacyAuth = legacyAuthRx?.value ?? initialType.check(.legacyAuthOnly);

        final dir = isURLHost
            ? DirectoryIndexServer.fromHost(
                urlOrHost,
                share,
                subdir,
                selectedType,
                username,
                port,
              )
            : DirectoryIndexServer.raw(
                urlOrHost,
                selectedType,
                username,
              );
        if (isDuplicated(dir)) {
          return;
        }

        if (initialDir != null) settings.removeFromList(directoriesToScan1: initialDir);
        settings.removeFromList(directoriesToScan1: dir);

        onSuccessChoose([dir]); // before db cuz this could remove old stuff

        final authInfo = MusicWebServerAuthDetails.create(
          dir: dir,
          password: password,
          share: share,
          subdir: subdir,
          legacyAuth: legacyAuth,
        );
        await authInfo.saveToDb(dir);
        possibleErrorRx.value = await dir.toWebServer()?.ping();
        if (possibleErrorRx.value != null) {
          MusicWebServerAuthDetails.manager.deleteFromDb(dir);
          return;
        }

        _maybeShowRefreshPromptDialog(true);

        NamidaNavigator.inst.closeDialog();
      }
    }

    Future<void> authenticate() async {
      isAuthenticatingRx.value = true;
      await authenticateRaw().ignoreError();
      isAuthenticatingRx.value = false;
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        isAuthenticatingRx.close();
        possibleErrorRx.close();
        selectedTypeRx.close();
        legacyAuthRx?.close();
        urlOrHostController.dispose();
        usernameController.dispose();
        passwordController.dispose();
        shareController?.dispose();
        subdirController?.dispose();
        portController?.dispose();
        availableSharesRx?.close();
      },
      dialogBuilder: (theme) {
        final mainColorScheme = initialType.toColor(theme);
        return Form(
          key: formKey,
          child: CustomBlurryDialog(
            theme: theme,
            normalTitleStyle: true,
            title: lang.configure,
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
                    text: lang.add,
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
                                Widget? assetWidget = assetImagePath == null
                                    ? null
                                    : Image.asset(
                                        assetImagePath,
                                        height: 22.0,
                                      );
                                assetWidget ??= Icon(
                                  e.toIcon(),
                                  size: 22.0,
                                );
                                final color = e.toColor(theme);
                                return Expanded(
                                  child: NamidaInkWell(
                                    alignment: Alignment.center,
                                    animationDurationMS: 200,
                                    borderRadius: 8.0,
                                    bgColor: color.withOpacityExt(0.2),
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      border: isSelected
                                          ? Border.all(
                                              color: color.withOpacityExt(0.6),
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
                                        ...[
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
                    if (initialType.check(.isFileBased)) ...[
                      const SizedBox(height: 8.0),
                      NamidaCoolBox(
                        colorScheme: mainColorScheme,
                        text: lang.fileBasedServerWarning,
                      ),
                    ],
                    const SizedBox(height: 12.0),
                    NamidaContainerDivider(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                    const SizedBox(height: 12.0),
                    if (legacyAuthRx != null) ...[
                      ObxO(
                        rx: legacyAuthRx,
                        builder: (context, value) => CustomSwitchListTile(
                          visualDensity: VisualDensity.compact,
                          title: lang.legacyAuthentication,
                          value: value,
                          onChanged: (_) => legacyAuthRx.toggle(),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: CustomTagTextField(
                            controller: urlOrHostController,
                            hintText: initialDirSourceHint ?? demoInfo?.url ?? '',
                            labelText: '${isURLHost ? 'IP/${lang.host}' : 'URL'} *',
                            validator: urlValidator,
                          ),
                        ),
                        if (portController != null) ...[
                          const SizedBox(width: 8.0),
                          Expanded(
                            flex: 2,
                            child: CustomTagTextField(
                              controller: portController,
                              hintText: portHint ?? '',
                              labelText: lang.port,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    if (shareController != null) ...[
                      CustomTagTextField(
                        controller: shareController,
                        hintText: shareHint ?? '',
                        labelText: lang.share,
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    if (availableSharesRx != null) ...[
                      ObxO(
                        rx: availableSharesRx,
                        builder: (context, availableShares) {
                          return AnimatedShow(
                            show: availableShares.isNotEmpty,
                            duration: const Duration(milliseconds: 300),
                            child: Column(
                              mainAxisSize: .min,
                              children: [
                                SmoothSingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: availableShares
                                        .map(
                                          (e) => NamidaInkWell(
                                            borderRadius: 99.0,
                                            bgColor: theme.cardColor,
                                            margin: const EdgeInsets.symmetric(horizontal: 3.0),
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                            onTap: () {
                                              shareController?.text = e;
                                            },
                                            child: Text(
                                              e,
                                              style: context.textTheme.displayMedium,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(height: 12.0),
                                const SizedBox(height: 4.0),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (subdirController != null) ...[
                      CustomTagTextField(
                        controller: subdirController,
                        hintText: subdirHint ?? '',
                        labelText: lang.subdirectory,
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    CustomTagTextField(
                      controller: usernameController,
                      hintText: initialDir?.username ?? demoInfo?.username ?? '',
                      labelText: lang.login,
                    ),
                    const SizedBox(height: 12.0),
                    CustomTagTextField(
                      controller: passwordController,
                      hintText: initialDir != null ? '' : demoInfo?.password ?? '',
                      labelText: lang.password,
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
                                  "${lang.error}: ${err.code}\n${err.message}",
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
        );
      },
    );
  }

  void _promptAddFolderType(void Function(List<DirectoryIndex> dirsPath) onSuccessChoose) {
    final types = List<DirectoryIndexType>.from(DirectoryIndexType.values);
    types.remove(DirectoryIndexType.unknown);
    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        title: lang.choose,
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
                      height: 20.0,
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
                    case DirectoryIndexType.subsonic || DirectoryIndexType.jellyfin || DirectoryIndexType.webdav || DirectoryIndexType.smb:
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
          title: lang.useMediaStore,
          subtitle: lang.useMediaStoreSubtitle,
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
          title: lang.includeVideos,
          value: includeVideos,
          onChanged: (isTrue) {
            settings.save(includeVideos: !isTrue);
            _maybeShowRefreshPromptDialog(false);
          },
        ),
      ),
    );
  }

  void _promptClearArtworkCache(BuildContext context) async {
    Indexer.inst.calculateAllImageSizesInStorage();
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.note,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.clear,
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              await Indexer.inst.clearImageCache();
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ObxO(
            rx: Indexer.inst.artworksSizeInStorage,
            builder: (context, artworksSizeInStorage) => ListTileWithCheckMark(
              dense: true,
              icon: Broken.broom,
              title: lang.clearImageCache,
              subtitle: artworksSizeInStorage == 0 ? '?' : artworksSizeInStorage.fileSizeFormatted,
              active: true,
              onTap: null,
            ),
          ),
        ),
      ),
    );
  }

  Widget getArtworkCacheWidget(BuildContext context) {
    return getItemWrapper(
      key: _IndexerSettingsKeys.artworksCache,
      child: NamidaExpansionTile(
        bgColor: getBgColor(_IndexerSettingsKeys.artworksCache),
        bigahh: true,
        normalRightPadding: true,
        borderless: true,
        initiallyExpanded: settings.cacheArtworks.value || initialItem == _IndexerSettingsKeys.artworksCache,
        leading: const StackedIcon(
          baseIcon: Broken.gallery,
          secondaryIcon: Broken.cpu_charge,
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
        iconColor: context.defaultIconColor(),
        titleText: lang.enableArtworkCache,
        subtitleText: lang.enableArtworkCacheSubtitle,
        onExpansionChanged: (wasCollapsed) {
          if (wasCollapsed) {
            settings.save(cacheArtworks: true);
            _showReindexingPrompt(title: lang.enableArtworkCache, body: lang.requiresClearingImageCacheAndReIndexing);
          } else {
            settings.save(cacheArtworks: false);
            _promptClearArtworkCache(context);
          }
        },
        trailingBuilder: (_) => Obx((context) {
          return CustomSwitch(active: settings.cacheArtworks.valueR);
        }),
        children: [
          _getGroupArtworksByAlbumWidget(),
          _getUniqueArtworkHashWidget(),
        ],
      ),
    );
  }

  Widget _getGroupArtworksByAlbumWidget() {
    return getItemWrapper(
      key: _IndexerSettingsKeys.groupArtworksByAlbum,
      child: Obx(
        (context) => AnimatedEnabled(
          enabled: !settings.uniqueArtworkHash.valueR,
          child: CustomSwitchListTile(
            bgColor: getBgColor(_IndexerSettingsKeys.groupArtworksByAlbum),
            icon: Broken.backward_item,
            title: lang.groupArtworksByAlbum,
            subtitle: lang.requiresClearingImageCacheAndReIndexing,
            value: settings.groupArtworksByAlbum.valueR,
            onChanged: (isTrue) {
              settings.save(groupArtworksByAlbum: !isTrue);
              _showReindexingPrompt(title: lang.groupArtworksByAlbum, body: lang.requiresClearingImageCacheAndReIndexing);
            },
          ),
        ),
      ),
    );
  }

  Widget _getUniqueArtworkHashWidget() {
    return getItemWrapper(
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
            title: lang.uniqueArtworkHash,
            subtitle: "${lang.performanceNote}. ${lang.requiresClearingImageCacheAndReIndexing}",
            value: settings.uniqueArtworkHash.valueR,
            onChanged: (isTrue) {
              settings.save(uniqueArtworkHash: !isTrue);
              _showReindexingPrompt(title: lang.uniqueArtworkHash, body: lang.requiresClearingImageCacheAndReIndexing);
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
            titleText: lang.listOfFolders,
            textColor: textTheme.displayLarge!.color,
            trailingBuilder: (iconWidget) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamidaButton(
                  icon: Broken.folder_add,
                  text: lang.add,
                  onPressed: () {
                    _promptAddFolderType((dirsPath) {
                      settings.save(directoriesToScan: dirsPath);
                    });
                  },
                ),
                const SizedBox(width: 8.0),
                iconWidget,
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
                    leading:
                        assetWidget ??
                        Icon(
                          e.type.toIcon(),
                          size: 20.0,
                        ),
                    title: e.toSourceInfo(),
                    subtitle: isServer
                        ? [
                            e.type.toText(),
                            e.username,
                          ].joinText(separator: ' - ')
                        : mediaStoreEnabled
                        ? lang.mediaStoreIsEnabledThisWillHaveNoEffect
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
                                title: lang.minimumOneItem,
                                message: lang.minimumOneFolderSubtitle,
                                displayDuration: SnackDisplayDuration.veryLong,
                              );
                            } else {
                              String bodyText = "${lang.remove} \"${e.toSourceInfo()}\"?";
                              if (e.isServer) {
                                final title = [e.type.toText(), e.username ?? '?'].joinText(separator: ' - ');
                                bodyText += "\n$title";
                              }
                              NamidaNavigator.inst.navigateDialog(
                                dialog: CustomBlurryDialog(
                                  normalTitleStyle: true,
                                  isWarning: true,
                                  actions: [
                                    const CancelButton(),
                                    NamidaButton(
                                      text: lang.remove,
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
                            lang.remove.toUpperCase(),
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
          titleText: lang.excludedFodlers,
          textColor: textTheme.displayLarge!.color,
          trailingBuilder: (iconWidget) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NamidaButton(
                icon: Broken.folder_add,
                text: lang.add,
                onPressed: () {
                  _pickLocalFolder((dirsPath) {
                    settings.save(directoriesToExclude: dirsPath);
                  });
                },
              ),
              const SizedBox(width: 8.0),
              iconWidget,
            ],
          ),
          children: directoriesToExclude.isEmpty
              ? [
                  ListTile(
                    title: Text(
                      lang.noExcludedFolders,
                      style: textTheme.displayMedium,
                    ),
                  ),
                ]
              : [
                  ...directoriesToExclude.map(
                    (e) => CustomListTile(
                      title: e.toSourceInfo(),
                      subtitle: e.username,
                      trailingRaw: TextButton(
                        onPressed: () {
                          settings.removeFromList(directoriesToExclude1: e);
                          _maybeShowRefreshPromptDialog(true);
                        },
                        child: NamidaButtonText(
                          lang.remove.toUpperCase(),
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
            text: [lang.clear, lang.reIndex].join(' & '),
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
      title: lang.indexer,
      subtitle: lang.indexerSubtitle,
      icon: Broken.component,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NamidaIconButton(
            icon: Broken.refresh_2,
            tooltip: () => lang.refreshLibrary,
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
                        title: '${lang.tracksInfo} :',
                        value: tracksInfoList.length.formatDecimal(),
                        total: allAudioFiles.isEmpty ? null : allAudioFiles.length.formatDecimal(),
                      ),
                    ),
                    ObxO(
                      rx: Indexer.inst.artworksInStorage,
                      builder: (context, artworksInStorage) => StatsContainer(
                        icon: Broken.image,
                        title: '${lang.artworks} :',
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
              lang.indexerNote,
              style: textTheme.displaySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Obx(
              (context) => Text(
                '${lang.duplicatedTracks}: ${Indexer.inst.duplicatedTracksLength.valueR}\n${lang.tracksExcludedByNomedia}: ${Indexer.inst.tracksExcludedByNoMedia.valueR}\n${lang.filteredBySizeAndDuration}: ${Indexer.inst.filteredForSizeDurationTracks.valueR}',
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
                title: lang.preventDuplicatedTracks,
                subtitle: "${lang.preventDuplicatedTracksSubtitle}. ${lang.indexRefreshRequired}",
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
                title: lang.respectNoMedia,
                subtitle: "${lang.respectNoMediaSubtitle}. ${lang.indexRefreshRequired}",
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
                title: lang.extractFeatArtist,
                subtitle: "${lang.extractFeatArtistSubtitle} ${lang.instantlyApplies}.",
                onChanged: (isTrue) async {
                  settings.save(extractFeatArtistFromTitle: !isTrue);
                  Indexer.inst.rebuildTracksAfterExtractFeatArtistChanges();
                },
                value: settings.extractFeatArtistFromTitle.valueR,
              ),
            ),
          ),
          getArtworkCacheWidget(context),
          getItemWrapper(
            key: _IndexerSettingsKeys.albumIdentifiers,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_IndexerSettingsKeys.albumIdentifiers),
                icon: Broken.arrow_square,
                title: lang.albumIdentifiers,
                trailingText: settings.albumIdentifiers.length.toString(),
                onTap: () {
                  final tempList = List<AlbumIdentifier>.from(settings.albumIdentifiers.value).obs;
                  NamidaNavigator.inst.navigateDialog(
                    onDisposing: () {
                      tempList.close();
                    },
                    dialog: CustomBlurryDialog(
                      title: lang.albumIdentifiers,
                      actions: [
                        const CancelButton(),
                        const SizedBox(width: 8.0),
                        Obx(
                          (context) {
                            return NamidaButton(
                              enabled:
                                  settings.albumIdentifiers.valueR.any((element) => !tempList.contains(element)) ||
                                  tempList.valueR.any((element) => !settings.albumIdentifiers.contains(element)), // isEqualTo wont work cuz order shouldnt matter
                              text: lang.save,
                              onPressed: () async {
                                NamidaNavigator.inst.closeDialog();
                                settings.removeFromList(albumIdentifiersAll: AlbumIdentifier.values);
                                settings.save(albumIdentifiers: tempList.value);
                                _showReindexingPrompt(title: lang.albumIdentifiers, body: lang.requiresClearingImageCacheAndReIndexing);
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
                title: lang.trackArtistsSeparator,
                subtitle: lang.instantlyApplies,
                trailingText: "${settings.trackArtistsSeparators.length}",
                onTap: () async {
                  await _showSeparatorSymbolsDialog(
                    lang.trackArtistsSeparator,
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
                title: lang.trackGenresSeparator,
                subtitle: lang.instantlyApplies,
                trailingText: "${settings.trackGenresSeparators.length}",
                onTap: () async {
                  await _showSeparatorSymbolsDialog(
                    lang.trackGenresSeparator,
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
                title: lang.minFileSize,
                subtitle: lang.indexRefreshRequired,
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
                title: lang.minFileDuration,
                subtitle: lang.indexRefreshRequired,
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
                title: lang.refreshOnStartup,
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
              title: lang.missingTracks,
              trailing: const Icon(Broken.arrow_right_3),
              onTap: () {
                if (BackupController.inst.isCreatingBackup.value ||
                    BackupController.inst.isRestoringBackup.value ||
                    HistoryController.inst.isLoadingHistory ||
                    YoutubeHistoryController.inst.isLoadingHistory ||
                    JsonToHistoryParser.inst.isParsing.value) {
                  snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
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
              title: lang.reIndex,
              subtitle: lang.reIndexSubtitle,
              onTap: () async {
                Indexer.inst.calculateAllImageSizesInStorage();

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
                        text: lang.reIndex,
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
                            lang.reIndexWarning,
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
                                title: lang.clearImageCache,
                                subtitle: artworksSizeInStorage == 0 ? '?' : artworksSizeInStorage.fileSizeFormatted,
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
              title: lang.refreshLibrary,
              subtitle: lang.refreshLibrarySubtitle,
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
                return Text('${lang.blacklist}$t');
              }),
              onPressed: () {
                if (trackArtistsSeparators) {
                  _showSeparatorSymbolsDialog(
                    lang.blacklist,
                    settings.trackArtistsSeparatorsBlacklist,
                    trackArtistsSeparatorsBlacklist: true,
                  );
                }
                if (trackGenresSeparators) {
                  _showSeparatorSymbolsDialog(
                    lang.blacklist,
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
                    text: lang.add,
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
                        snackyy(title: lang.emptyValue, message: lang.enterSymbol);
                      }
                    },
                  ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBlackListDialog ? lang.separatorsBlacklistSubtitle : lang.separatorsMessage,
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
                            ),
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
                  hintText: lang.value,
                ),
                controller: separatorsController,
              ),
            ),
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
  final newPaths = Indexer.inst.getNewFoundPaths(currentFiles);
  final deletedPath = Indexer.inst.getDeletedPaths(currentFiles);
  final settingsServers = settings.directoriesToScan.value.allServers();
  final hasServer = settingsServers.isNotEmpty || allTracksInLibrary.any((element) => element.isNetwork);
  final noLocalChanges = newPaths.isEmpty && deletedPath.isEmpty;
  if (!hasServer && noLocalChanges) {
    snackyy(title: lang.note, message: lang.noChangesFound);
  } else {
    final bodyWidgets = <Widget>[];

    bodyWidgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12.0, left: 6.0, right: 6.0),
        child: Text(
          '${lang.theFollowingChangesWereDetected}.\n${lang.confirmRefresh}',
          style: namida.textTheme.displayMedium,
        ),
      ),
    );

    if (noLocalChanges) {
      bodyWidgets.add(
        DirectoryIndexLocal('').toWidget(
          theme: namida.theme,
          title: lang.local,
          subtitle: lang.noChangesFound,
        ),
      );
      bodyWidgets.add(const SizedBox(height: 8.0));
    } else {
      bodyWidgets.add(
        DirectoryIndexLocal('').toWidget(
          theme: namida.theme,
          title: lang.local,
          subtitleBuilder: (context) {
            return Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Wrap(
                spacing: 2.0,
                runSpacing: 3.0,
                crossAxisAlignment: .start,
                children: [
                  _LocalFilesSmallChip(
                    icon: Broken.add_circle,
                    label: lang.newLabel,
                    colorScheme: Colors.green,
                    paths: newPaths,
                  ),
                  _LocalFilesSmallChip(
                    icon: Broken.eraser_1,
                    label: '${lang.deleted}/${lang.filtered}',
                    colorScheme: Colors.red,
                    paths: deletedPath,
                  ),
                ],
              ),
            );
          },
        ),
      );
      bodyWidgets.add(const SizedBox(height: 8.0));
    }

    if (hasServer) {
      final tracksServers = <String, bool>{};
      for (final trExt in Indexer.inst.allTracksMappedByPath.values) {
        final s = trExt.server;
        if (s != null) {
          tracksServers[s] ??= false;
        }
      }
      final servers = <DirectoryIndex, bool>{};
      for (final s in settingsServers) {
        servers[s] = true;
      }
      for (final ts in tracksServers.entries) {
        if (servers.keys.any((element) => element.sourceRaw == ts.key)) {
          // already exists and more detailed
        } else {
          final dir = DirectoryIndexServer.parseFromEncodedUrlPath(ts.key);
          servers[dir] ??= ts.value;
        }
      }

      for (final k in servers.keys) {
        bodyWidgets.add(
          k.toWidget(theme: namida.theme, stillExistsCallback: (d) => servers[d]),
        );
        bodyWidgets.add(const SizedBox(height: 8.0));
      }
    }

    bodyWidgets.removeLast(); // remove extra bottom padding

    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) {
        return CustomBlurryDialog(
          title: lang.confirm,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.refresh,
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
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: bodyWidgets,
          ),
        );
      },
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
                      .map(
                        (e) => Padding(
                          padding: widget.itemPadding,
                          child: Text(
                            e,
                            maxLines: _isPathsExpanded ? null : 1,
                            overflow: _isPathsExpanded ? null : TextOverflow.ellipsis,
                            style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                          ),
                        ),
                      )
                      .toList(),
                );
        },
      ),
    );
  }
}

class _LocalFilesSmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colorScheme;
  final Set<String> paths;

  const _LocalFilesSmallChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.paths,
  });

  void _onTap() {
    final pathsList = paths.toList();
    if (pathsList.isEmpty) return;

    final separatorWidget = NamidaContainerDivider(
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
    );
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: '$label: ${paths.length.displayFilesKeyword}',
        normalTitleStyle: true,
        actions: [
          const DoneButton(),
        ],
        child: SizedBox(
          height: namida.height * 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ListView.separated(
              separatorBuilder: (context, index) => separatorWidget,
              itemCount: pathsList.length,
              itemBuilder: (context, i) {
                final p = pathsList[i];
                return TapDetector(
                  onTap: () => NamidaUtils.copyToClipboard(content: p),
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      Icon(
                        icon,
                        size: 16.0,
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Text(
                          p,
                          style: context.textTheme.displaySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaInkWell(
      borderRadius: 6.0,
      bgColor: Color.alphaBlend(colorScheme.withOpacityExt(0.25), CurrentColor.inst.color.withOpacityExt(0.4)),
      padding: EdgeInsetsGeometry.symmetric(horizontal: 6.0, vertical: 3.0),
      onTap: _onTap,
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(
            icon,
            size: 9.0,
          ),
          const SizedBox(width: 2.0),
          Flexible(
            child: Text(
              '$label: ${paths.length.displayFilesKeyword}',
              style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 12.0),
            ),
          ),
        ],
      ),
    );
  }
}
