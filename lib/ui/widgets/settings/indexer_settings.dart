import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/pages/subpages/indexer_missing_tracks_subpage.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

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
  List<List<SettingEntry>> get sections => _sections;

  static final artworkCache = SettingToggleGroup(
    settings.cacheArtworks,
    leading: const StackedIcon(
      baseIcon: Broken.gallery,
      secondaryIcon: Broken.cpu_charge,
    ),
    title: () => lang.enableArtworkCache,
    subtitle: () => lang.enableArtworkCacheSubtitle,
    onChanged: _onArtworkCacheToggle,
    children: [
      SettingCustom(
        title: () => lang.groupArtworksByAlbum,
        keys: [settings.groupArtworksByAlbum],
        onReset: () => _showReindexingPrompt(title: lang.groupArtworksByAlbum, body: lang.requiresClearingImageCacheAndReIndexing),
        tile: (args) => _ExclusiveArtworkToggleTile(
          args: args,
          setting: settings.groupArtworksByAlbum,
          exclusiveSetting: settings.uniqueArtworkHash,
          icon: Broken.backward_item,
          title: lang.groupArtworksByAlbum,
        ),
      ),
      SettingCustom(
        title: () => lang.uniqueArtworkHash,
        keys: [settings.uniqueArtworkHash],
        onReset: () => _showReindexingPrompt(title: lang.uniqueArtworkHash, body: lang.requiresClearingImageCacheAndReIndexing),
        tile: (args) => _ExclusiveArtworkToggleTile(
          args: args,
          setting: settings.uniqueArtworkHash,
          exclusiveSetting: settings.groupArtworksByAlbum,
          leading: const StackedIcon(
            baseIcon: Broken.gallery,
            secondaryIcon: Broken.cpu,
            secondaryIconSize: 13.0,
          ),
          title: lang.uniqueArtworkHash,
          note: lang.performanceNote,
        ),
      ),
    ],
  );

  static final includeVideos = SettingCustom(
    title: () => lang.includeVideos,
    keys: [settings.includeVideos],
    onReset: () => showRefreshPromptDialog(false),
    tile: (args) => _IncludeVideosTile(
      args: args,
    ),
  );

  static final addFolder = SettingCustom(
    title: () => lang.addFolder,
    aliases: _getAddFolderAliases,
    tile: (args) => _AddFolderTile(
      args: args,
    ),
  );

  static final foldersToScan = SettingCustom(
    title: () => lang.listOfFolders,
    aliases: _getAddFolderAliases,
    tile: (args) => _FoldersToScanTile(
      args: args,
    ),
  );

  static final foldersToExclude = SettingCustom(
    title: () => lang.excludedFodlers,
    keys: [settings.directoriesToExclude],
    onReset: () => showRefreshPromptDialog(true),
    tile: (args) => _FoldersToExcludeTile(
      args: args,
    ),
  );

  static final respectNoMedia = SettingCustom(
    title: () => lang.respectNoMedia,
    aliases: () => [lang.respectNoMediaSubtitle],
    keys: [settings.respectNoMedia],
    tile: (args) => _RespectNoMediaTile(
      args: args,
    ),
  );

  static final minFileDuration = SettingCustom(
    title: () => lang.minFileDuration,
    keys: [settings.indexMinDurationInSec],
    tile: (args) => _MinFileDurationTile(
      args: args,
    ),
  );

  static final minFileSize = SettingCustom(
    title: () => lang.minFileSize,
    keys: [settings.indexMinFileSizeInB],
    tile: (args) => _MinFileSizeTile(
      args: args,
    ),
  );

  static final albumIdentifiers = SettingCustom(
    title: () => lang.albumIdentifiers,
    keys: [settings.albumIdentifiers],
    onReset: () => _showReindexingPrompt(title: lang.albumIdentifiers, body: lang.requiresClearingImageCacheAndReIndexing),
    tile: (args) => _AlbumIdentifiersTile(
      bgColor: args.bgColor,
    ),
  );

  static final _sections = <List<SettingEntry>>[
    [
      addFolder,
      SettingCustom(
        title: () => lang.refreshLibrary,
        aliases: () => [lang.refreshLibrarySubtitle],
        tile: (args) => _RefreshLibraryTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingCustom(
        title: () => lang.reIndex,
        aliases: () => [lang.reIndexSubtitle],
        tile: (args) => _ReIndexTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingToggle(
        settings.refreshOnStartup,
        icon: Broken.d_rotate,
        title: () => lang.refreshOnStartup,
      ),
      SettingCustom(
        title: () => lang.missingTracks,
        tile: (args) => _MissingTracksTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingToggle(
        settings.extractFeatArtistFromTitle,
        icon: Broken.microphone,
        title: () => lang.extractFeatArtist,
        subtitle: () => "${lang.extractFeatArtistSubtitle} ${lang.instantlyApplies}.",
        onChanged: (_) => Indexer.inst.rebuildTracksAfterExtractFeatArtistChanges(),
      ),
      SettingCustom(
        title: () => lang.separators,
        aliases: () => [lang.trackArtistsSeparator, lang.trackGenresSeparator],
        keys: [
          settings.trackArtistsSeparators, settings.trackArtistsSeparatorsBlacklist, //
          settings.trackGenresSeparators, settings.trackGenresSeparatorsBlacklist, //
          settings.trackAlbumsSeparators, settings.trackAlbumsSeparatorsBlacklist, //
        ],
        onReset: () => Indexer.inst.rebuildTracksAfterSplitConfigChanges(),
        tile: (args) => _SeparatorsTile(
          bgColor: args.bgColor,
        ),
      ),
      albumIdentifiers,
    ],
    [
      includeVideos,
      respectNoMedia,
      minFileDuration,
      minFileSize,
      SettingCustom(
        title: () => '${lang.extension} (${lang.blacklist})',
        keys: [settings.extensionsBlacklist],
        onReset: () => showRefreshPromptDialog(false),
        tile: (args) => _ExtensionsBlacklistTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingToggle(
        settings.preventDuplicatedTracks,
        icon: Broken.copy,
        title: () => lang.preventDuplicatedTracks,
        subtitle: () => "${lang.preventDuplicatedTracksSubtitle}. ${lang.indexRefreshRequired}",
      ),
    ],
    [
      artworkCache,
    ],
    [
      foldersToScan,
      foldersToExclude,
    ],
  ];

  static IndexerSettings _forTile(SettingTileArgs args) {
    final page = args.page;
    return page is IndexerSettings ? page : const IndexerSettings();
  }

  static List<String> _getAddFolderAliases() => getAddFolderSubtitleKeys(includeAllInfo: true).toFixedList();

  static void _onArtworkCacheToggle(bool isEnabled) {
    if (isEnabled) {
      _showReindexingPrompt(title: lang.enableArtworkCache, body: lang.requiresClearingImageCacheAndReIndexing);
    } else {
      _promptClearArtworkCache();
    }
  }

  static Iterable<String> getAddFolderSubtitleKeys({required bool includeAllInfo}) sync* {
    for (final d in DirectoryIndexType.values) {
      if (d == DirectoryIndexType.unknown) continue;
      yield d.toText();
      if (includeAllInfo) {
        final subtitle = d.toSubtitle();
        if (subtitle != null) yield subtitle;
      }
    }
  }

  void _maybeShowRefreshPromptDialog(bool didModifyFolder) {
    if (!isInFirstConfigScreen) showRefreshPromptDialog(didModifyFolder);
  }

  String? _withIndexingNote(String? subtitle, String note) {
    if (isInFirstConfigScreen) return subtitle;
    return [?subtitle, note].join('. ');
  }

  void _reAuthDirIndex(DirectoryIndexServer e) {
    void onSuccessChoose(List<DirectoryIndex> dirsPath) {
      settings.directoriesToScan.update((list) => list.remove(e));
      MusicWebServerAuthDetails.manager.deleteFromDb(e);
      settings.directoriesToScan.update((list) => list.addAllNoDuplicates(dirsPath));
    }

    if (e.type == DirectoryIndexType.saf) {
      _pickSafFolder(onSuccessChoose);
    } else {
      _pickServerFolder(
        initialType: e.type,
        initialDir: e,
        onSuccessChoose: onSuccessChoose,
      );
    }
  }

  /// saved with empty credentials so it goes through the same server flow as the others.
  void _pickSafFolder(void Function(List<DirectoryIndex> dirsPath) onSuccessChoose) async {
    final treeUri = await NamidaStorage.inst.safPickTree(note: lang.addFolder);

    if (treeUri == null) {
      snackyy(title: lang.note, message: lang.noFolderChosen);
      return;
    }

    final dir = DirectoryIndexServer.saf(treeUri);
    onSuccessChoose([dir]);

    final authInfo = MusicWebServerAuthDetails.create(
      dir: dir,
      password: '',
      share: null,
      subdir: null,
      legacyAuth: true,
    );
    await authInfo.saveToDb(dir);
    _maybeShowRefreshPromptDialog(true);
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

  /// [types] are offered as a switch inside the dialog, they must share the same tags as [initialType].
  void _pickServerFolder({
    required DirectoryIndexType initialType,
    List<DirectoryIndexType>? types,
    DirectoryIndex? initialDir,
    required void Function(List<DirectoryIndex> dirsPath) onSuccessChoose,
  }) {
    final selectableTypes = types ?? [initialType];

    final isURLHost = initialType.check(.isURLHost);
    final initialSource = initialDir?.sourceRaw;

    final supportsLibraryId = initialType.check(.supportsLibraryId);

    final isAuthenticatingRx = false.obs;
    final possibleErrorRx = Rxn<MusicWebServerError>();
    final selectedTypeRx = initialType.obs;
    final legacyAuthRx = initialType.check(.legacyAuthOnly) ? null : false.obs;
    final urlOrHostController = TextEditingController(text: initialSource);
    final usernameController = TextEditingController(text: initialDir?.username);
    final passwordController = TextEditingController(text: null);
    final shareNameController = initialType.check(.supportsShare) ? TextEditingController(text: null) : null;
    final libraryIdController = initialType.check(.supportsLibraryId) ? TextEditingController(text: null) : null;
    final subdirController = initialType.check(.supportsSubdir) ? TextEditingController(text: null) : null;
    final portController = initialType.check(.supportsPort) ? TextEditingController(text: null) : null;
    final shareTargetController = shareNameController ?? libraryIdController; // -- smb shares or jellyfin libraries
    final availableSharesRx = shareTargetController == null ? null : <ServerShareWrapper>{}.obs;
    final formKey = GlobalKey<FormState>();

    if (availableSharesRx != null) {
      initialDir?.toWebServer()?.getAvailableShares().catchError((_) => null).then(
        (value) {
          availableSharesRx.value = value ?? <ServerShareWrapper>{};
        },
      );
    }

    String? initialDirSourceHint = initialSource;
    String? shareHint;
    String? subdirHint;
    String? portHint;
    String? libraryIdHint;
    if (initialSource != null && isURLHost) {
      try {
        final parsed = HostServerInfo.fromUrl(initialSource);
        initialDirSourceHint = parsed.host;
        shareHint = parsed.share;
        subdirHint = parsed.subdir;
        portHint = parsed.port?.toString();

        urlOrHostController.text = parsed.host;
        shareNameController?.text = parsed.share ?? '';
        subdirController?.text = parsed.subdir ?? '';
        portController?.text = parsed.port?.toString() ?? '';
      } catch (_) {}
    }
    if (initialSource != null && supportsLibraryId) {
      try {
        final library = ServerShareWrapper.fromUrl(initialSource);
        final uriCleanString = DirectoryIndexServer.parseWithoutLibraryIdAndClean(initialSource);

        initialDirSourceHint = uriCleanString;
        libraryIdHint = library?.id;

        urlOrHostController.text = uriCleanString;
        libraryIdController?.text = library?.id ?? '';
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
        final share = shareNameController?.text;
        final subdir = subdirController?.text;
        final libraryId = libraryIdController?.text;
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
            : supportsLibraryId
            ? DirectoryIndexServer.withLibraryId(
                urlOrHost,
                libraryId,
                selectedType,
                username,
              )
            : DirectoryIndexServer.raw(
                urlOrHost,
                selectedType,
                username,
              );
        if (isDuplicated(dir)) {
          return;
        }

        if (initialDir != null) settings.directoriesToScan.update((list) => list.remove(initialDir));
        settings.directoriesToScan.update((list) => list.remove(dir));

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
      possibleErrorRx.value = null;
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
        shareNameController?.dispose();
        libraryIdController?.dispose();
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
              CancelButtonDisabled(
                disabledRx: isAuthenticatingRx,
              ),
              ObxO(
                rx: isAuthenticatingRx,
                builder: (context, isAuthenticating) => NamidaButton(
                  text: lang.add,
                  onTap: authenticate,
                  enabled: !isAuthenticating,
                  isLoading: isAuthenticating,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: selectableTypes
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
                          )
                          .toFixedList(),
                    ),
                    if (initialType.check(.downloadsWholeFiles)) ...[
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
                    if (shareNameController != null) ...[
                      CustomTagTextField(
                        controller: shareNameController,
                        hintText: shareHint ?? '',
                        labelText: lang.share,
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    if (libraryIdController != null) ...[
                      CustomTagTextField(
                        controller: libraryIdController,
                        hintText: libraryIdHint ?? '',
                        labelText: "${lang.folder} (ID)",
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
                              crossAxisAlignment: .start,
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
                                              shareTargetController?.text = e.id;
                                            },
                                            child: Text(
                                              e.name,
                                              style: context.textTheme.displayMedium,
                                            ),
                                          ),
                                        )
                                        .toFixedList(),
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

  void promptAddFolderType() {
    _promptAddFolderType((dirsPath) {
      settings.directoriesToScan.update((list) => list.addAllNoDuplicates(dirsPath));
    });
  }

  void _promptAddFolderType(void Function(List<DirectoryIndex> dirsPath) onSuccessChoose) {
    final groups = <List<DirectoryIndexType>>[
      const [DirectoryIndexType.local],
      const [DirectoryIndexType.subsonic],
      const [DirectoryIndexType.jellyfin],
      const [DirectoryIndexType.webdav],
      const [DirectoryIndexType.smb],
      const [DirectoryIndexType.ftp, DirectoryIndexType.sftp],
      if (NamidaFeaturesVisibility.showSafFolders) const [DirectoryIndexType.saf],
    ];
    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        title: lang.choose,
        actions: const [
          CancelButton(addMargin: false),
        ],
        child: Column(
          children: groups.map(
            (group) {
              final e = group.first;
              final assetImagePath = e.toAssetImage();
              final assetWidget = assetImagePath == null
                  ? null
                  : Image.asset(
                      assetImagePath,
                      height: 20.0,
                    );
              final title = group.map((t) => t.toText()).join(' / ');
              return CustomListTile(
                icon: assetWidget != null ? null : e.toIcon(),
                leading: assetWidget,
                title: title,
                subtitle: e.toSubtitle(),
                onTap: () async {
                  NamidaNavigator.inst.closeDialog();
                  if (e == DirectoryIndexType.local) {
                    _pickLocalFolder(onSuccessChoose);
                  } else if (e == DirectoryIndexType.saf) {
                    _pickSafFolder(onSuccessChoose);
                  } else {
                    _pickServerFolder(initialType: e, types: group, onSuccessChoose: onSuccessChoose);
                  }
                },
              );
            },
          ).toFixedList(),
        ),
      ),
    );
  }

  void _promptAddExcludedFolder() {
    _pickLocalFolder((dirsPath) {
      settings.directoriesToExclude.update((list) => list.addAllNoDuplicates(dirsPath));
    });
  }

  // Widget getMediaStoreWidget() {
  //   return getItemWrapper(
  //     key: _IndexerSettingsKeys.useMediaStore,
  //     child: Obx(
  //       (context) => CustomSwitchListTile(
  //         bgColor: getBgColor(_IndexerSettingsKeys.useMediaStore),
  //         icon: Broken.airdrop,
  //         title: lang.useMediaStore,
  //         subtitle: lang.useMediaStoreSubtitle,
  //         value: settings.useMediaStore.valueR,
  //         onChanged: (isTrue) {
  //           settings.useMediaStore.save(!isTrue);
  //           _maybeShowRefreshPromptDialog(false);
  //         },
  //       ),
  //     ),
  //   );
  // }

  static void _promptClearArtworkCache() async {
    Indexer.inst.calculateAllImageSizesInStorage();
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.note,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.clear,
            onTap: () async {
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

  static void _showReindexingPrompt({
    required String title,
    required String body,
  }) {
    if (Indexer.inst.tracksInfoList.value.isEmpty) return;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: title,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: [lang.clear, lang.reIndex].join(' & '),
            onTap: () async {
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
    const refreshIconKey = 'kururin';

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
            onPressed: () => showRefreshPromptDialog(false, allowBypassing: true),
            child: const RefreshLibraryIcon(
              widgetKey: refreshIconKey,
            ),
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
            height: 52.0,
            width: context.width,
            child: FittedBox(
              fit: .scaleDown,
              alignment: Dimensions.inst.availableAppContentWidthContext(context) < 664.0 ? AlignmentDirectional.center : AlignmentDirectional.centerStart,
              child: ObxO(
                rx: Indexer.inst.allAudioFiles,
                builder: (context, allAudioFiles) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Obx(
                      (context) {
                        final tracksCount = Indexer.inst.tracksInfoList.valueR.length;
                        final networkTracksCount = Indexer.inst.networkTracksCount.valueR;
                        final filesCount = allAudioFiles.length + networkTracksCount;
                        final filesCountText = filesCount == 0 ? null : filesCount.formatDecimal();
                        return StatsContainer(
                          icon: Broken.music_circle,
                          title: '${lang.tracks}:',
                          value: tracksCount.formatDecimal(),
                          total: filesCountText,
                        );
                      },
                    ),
                    ObxO(
                      rx: Indexer.inst.artworksInStorage,
                      builder: (context, artworksInStorage) => StatsContainer(
                        icon: Broken.image,
                        title: '${lang.artworks}:',
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
          // const _ExtractingPathsWidget(itemPadding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0)),
          SettingSectionsColumn(
            page: this,
          ),
        ],
      ),
    );
  }
}

class _RespectNoMediaTile extends StatelessWidget {
  final SettingTileArgs args;

  const _RespectNoMediaTile({required this.args});

  void _onChanged(bool isTrue) => settings.respectNoMedia.save(!isTrue);

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final subtitle = host._withIndexingNote(lang.respectNoMediaSubtitle, lang.indexRefreshRequired);
    return Obx(
      (context) {
        final isMediaStoreEnabled = settings.useMediaStore.valueR;
        final value = !isMediaStoreEnabled && settings.respectNoMedia.valueR;
        return CustomSwitchListTile(
          bgColor: args.bgColor,
          enabled: !isMediaStoreEnabled,
          icon: Broken.cd,
          title: lang.respectNoMedia,
          subtitle: subtitle,
          onChanged: _onChanged,
          value: value,
        );
      },
    );
  }
}

class _ExclusiveArtworkToggleTile extends StatelessWidget {
  final SettingTileArgs args;
  final SettingsKey<bool> setting;
  final SettingsKey<bool> exclusiveSetting;
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? note;

  const _ExclusiveArtworkToggleTile({
    required this.args,
    required this.setting,
    required this.exclusiveSetting,
    this.icon,
    this.leading,
    required this.title,
    this.note,
  });

  void _onChanged(bool isTrue) {
    setting.save(!isTrue);
    IndexerSettings._showReindexingPrompt(title: title, body: lang.requiresClearingImageCacheAndReIndexing);
  }

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final subtitle = host._withIndexingNote(note, lang.requiresClearingImageCacheAndReIndexing);
    return Obx(
      (context) => AnimatedEnabled(
        enabled: !exclusiveSetting.valueR,
        child: CustomSwitchListTile(
          bgColor: args.bgColor,
          icon: icon,
          leading: leading,
          title: title,
          subtitle: subtitle,
          value: setting.valueR,
          onChanged: _onChanged,
        ),
      ),
    );
  }
}

class _SeparatorsTile extends StatelessWidget {
  final Color? bgColor;

  const _SeparatorsTile({required this.bgColor});

  void _showDialog() {
    final lists = _SeparatorsType.values.expand((e) => [e.getList(isBlacklist: false).rx, e.getList(isBlacklist: true).rx]).toFixedList();
    final originals = lists.map((e) => List<String>.from(e.value)).toFixedList();

    bool didChange() {
      for (int i = 0; i < lists.length; i++) {
        if (lists[i].value.didChangeFrom(originals[i])) return true;
      }
      return false;
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        if (didChange()) Indexer.inst.rebuildTracksAfterSplitConfigChanges();
      },
      dialog: CustomBlurryDialog(
        title: lang.separators,
        normalTitleStyle: true,
        icon: Broken.scissor,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._SeparatorsType.values.map(
              (e) => _SeparatorsTypeTile(
                type: e,
                onTap: () => NamidaNavigator.inst.navigateDialog(
                  dialog: _SeparatorsDialog(
                    type: e,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = '${lang.artists}, ${lang.genres}, ${lang.albums} • ${lang.instantlyApplies}';
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.scissor,
      title: lang.separators,
      subtitle: subtitle,
      trailing: const Icon(
        Broken.arrow_right_3,
      ),
      onTap: _showDialog,
    );
  }
}

class _AlbumIdentifiersTile extends StatelessWidget {
  final Color? bgColor;

  const _AlbumIdentifiersTile({required this.bgColor});

  void _showDialog() {
    final tempList = List<AlbumIdentifier>.from(settings.albumIdentifiers.value).obs;
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        tempList.close();
      },
      dialog: CustomBlurryDialog(
        title: lang.albumIdentifiers,
        actions: [
          const CancelButton(),
          Obx(
            (context) {
              final albumIdentifiers = settings.albumIdentifiers.valueR;
              final tempIdentifiers = tempList.valueR;
              final hasChanges =
                  albumIdentifiers.any((element) => !tempIdentifiers.contains(element)) ||
                  tempIdentifiers.any((element) => !albumIdentifiers.contains(element)); // isEqualTo wont work cuz order shouldnt matter
              return NamidaButton(
                enabled: hasChanges,
                text: lang.save,
                onTap: () async {
                  NamidaNavigator.inst.closeDialog();
                  final identifiers = tempList.value.toList();
                  settings.albumIdentifiers.replace(identifiers);
                  IndexerSettings._showReindexingPrompt(title: lang.albumIdentifiers, body: lang.requiresClearingImageCacheAndReIndexing);
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
                    padding: const EdgeInsets.all(3.0),
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
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.albumIdentifiers,
      builder: (context, albumIdentifiers) {
        final albumIdentifiersText = albumIdentifiers.map((e) => e.toText()).join(', ');
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.arrow_square,
          title: lang.albumIdentifiers,
          subtitle: albumIdentifiersText,
          trailingText: albumIdentifiers.length.toString(),
          onTap: _showDialog,
        );
      },
    );
  }
}

class _ExtensionsBlacklistTile extends StatelessWidget {
  final Color? bgColor;

  const _ExtensionsBlacklistTile({required this.bgColor});

  Future<void> _showDialog(String title, RxBaseCore<List<String>> blacklistItems) async {
    final blacklistController = TextEditingController();

    final original = List<String>.from(blacklistItems.value);
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        blacklistController.dispose();
      },
      onDismissing: () {
        final didChange = blacklistItems.value.didChangeFrom(original);
        if (didChange) {
          showRefreshPromptDialog(false);
        }
      },
      durationInMs: 200,
      dialogBuilder: (theme) => _ChipsEditorDialog(
        title: title,
        controller: blacklistController,
        itemsList: blacklistItems,
        onAdd: (value) {
          if (blacklistController.text.isNotEmpty) {
            String extensionToBlacklist = blacklistController.text;
            if (extensionToBlacklist.startsWith('.')) extensionToBlacklist = extensionToBlacklist.substring(1);

            if (extensionToBlacklist.isNotEmpty) {
              settings.extensionsBlacklist.update((list) => list.addNoDuplicates(extensionToBlacklist));
            }

            blacklistController.clear();
          } else {
            snackyy(title: lang.emptyValue, message: lang.pleaseEnterAName);
          }
        },
        onRemove: (e) {
          settings.extensionsBlacklist.update((list) => list.remove(e));
        },
        bottomWidget: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: SmoothSingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ObxO(
              rx: blacklistItems,
              builder: (context, blacklistItems) => Row(
                children: NamidaFileExtensionsWrapper.audioAndVideo.extensions.map(
                  (e) {
                    if (blacklistItems.contains(e)) return const SizedBox();
                    return NamidaInkWell(
                      borderRadius: 12.0,
                      bgColor: theme.cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      onTap: () {
                        settings.extensionsBlacklist.update((list) => list.addNoDuplicates(e));
                      },
                      child: Text(
                        e,
                        style: theme.textTheme.displaySmall,
                      ),
                    );
                  },
                ).toFixedList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${lang.extension} (${lang.blacklist})';
    return ObxO(
      rx: settings.extensionsBlacklist,
      builder: (context, extensionsBlacklist) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.location_slash,
        title: title,
        subtitle: lang.indexRefreshRequired,
        trailingText: "${extensionsBlacklist.length}",
        onTap: () => _showDialog(title, settings.extensionsBlacklist),
      ),
    );
  }
}

class _MinFileSizeTile extends StatelessWidget {
  final SettingTileArgs args;

  const _MinFileSizeTile({required this.args});

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final subtitle = host._withIndexingNote(null, lang.indexRefreshRequired);
    return ObxO(
      rx: settings.indexMinFileSizeInB,
      builder: (context, indexMinFileSizeInB) => CustomListTile(
        bgColor: args.bgColor,
        icon: Broken.unlimited,
        title: lang.minFileSize,
        subtitle: subtitle,
        trailing: NamidaWheelSlider(
          width: 100.0,
          max: 1024,
          multiplier: (1024 * 10),
          initValue: indexMinFileSizeInB,
          onValueChanged: settings.indexMinFileSizeInB.save,
          text: indexMinFileSizeInB.fileSizeFormatted,
        ),
      ),
    );
  }
}

class _MinFileDurationTile extends StatelessWidget {
  final SettingTileArgs args;

  const _MinFileDurationTile({required this.args});

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final subtitle = host._withIndexingNote(null, lang.indexRefreshRequired);
    return ObxO(
      rx: settings.indexMinDurationInSec,
      builder: (context, indexMinDurationInSec) => CustomListTile(
        bgColor: args.bgColor,
        icon: Broken.timer_1,
        title: lang.minFileDuration,
        subtitle: subtitle,
        trailing: NamidaWheelSlider(
          width: 100.0,
          max: 180,
          initValue: indexMinDurationInSec,
          onValueChanged: settings.indexMinDurationInSec.save,
          text: "$indexMinDurationInSec s",
        ),
      ),
    );
  }
}

class _IncludeVideosTile extends StatelessWidget {
  final SettingTileArgs args;

  const _IncludeVideosTile({required this.args});

  void _onChanged(bool isTrue) {
    settings.includeVideos.save(!isTrue);
    final host = IndexerSettings._forTile(args);
    host._maybeShowRefreshPromptDialog(false);
  }

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final rescanButton = host.isInFirstConfigScreen
        ? null
        : const LocalVideosRescanButton(
            padding: EdgeInsetsDirectional.only(start: 8.0),
          );
    return Obx(
      (context) {
        final videosCountText = VideoController.inst.getLocalVideosCountTextR();
        return CustomSwitchListTile(
          bgColor: args.bgColor,
          leading: const StackedIcon(
            baseIcon: Broken.video_play,
            secondaryIcon: Broken.tick_circle,
            secondaryIconSize: 12.0,
          ),
          title: lang.includeVideos,
          subtitle: '${lang.videos}: $videosCountText',
          trailingBeforeSwitch: rescanButton,
          value: settings.includeVideos.valueR,
          onChanged: _onChanged,
        );
      },
    );
  }
}

class _MissingTracksTile extends StatelessWidget {
  final Color? bgColor;

  const _MissingTracksTile({required this.bgColor});

  Future<void> _onTap() async {
    if (Indexer.inst.isIndexing.value ||
        BackupController.inst.isCreatingBackup.value ||
        BackupController.inst.isRestoringBackup.value ||
        HistoryController.inst.isLoadingHistory ||
        YoutubeHistoryController.inst.isLoadingHistory ||
        JsonToHistoryParser.inst.isParsing.value) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return;
    }
    if (!await requestManageStoragePermission()) return;
    const IndexerMissingTracksSubpage().navigate();
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.location_cross,
      title: lang.missingTracks,
      trailing: const Icon(
        Broken.arrow_right_3,
      ),
      onTap: _onTap,
    );
  }
}

class _ReIndexTile extends StatelessWidget {
  final Color? bgColor;

  const _ReIndexTile({required this.bgColor});

  Future<void> _showDialog(TextTheme textTheme) async {
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
            onTap: () async {
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
              const SizedBox(
                height: 16.0,
              ),
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
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.refresh,
      title: lang.reIndex,
      subtitle: lang.reIndexSubtitle,
      onTap: () => _showDialog(textTheme),
    );
  }
}

class _RefreshLibraryTile extends StatelessWidget {
  final Color? bgColor;

  const _RefreshLibraryTile({required this.bgColor});

  static const _kRefreshIconKey = 'kurukuru';

  void _onTap() => showRefreshPromptDialog(false, allowBypassing: true);

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      leading: const RefreshLibraryIcon(
        widgetKey: _kRefreshIconKey,
      ),
      title: lang.refreshLibrary,
      subtitle: lang.refreshLibrarySubtitle,
      onTap: _onTap,
    );
  }
}

class _AddFolderTile extends StatelessWidget {
  final SettingTileArgs args;

  const _AddFolderTile({required this.args});

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final subtitle = IndexerSettings.getAddFolderSubtitleKeys(includeAllInfo: false).join(', ');
    return CustomListTile(
      bgColor: args.bgColor,
      icon: Broken.folder_add,
      title: lang.addFolder,
      subtitle: subtitle,
      onTap: host.promptAddFolderType,
    );
  }
}

class _FoldersToScanTile extends StatelessWidget {
  final SettingTileArgs args;

  const _FoldersToScanTile({required this.args});

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final isTargetWithin = args.page?.isTargetWithin(args.entry) == true;
    return NamidaExpansionTile(
      bgColor: args.bgColor,
      initiallyExpanded: isTargetWithin,
      icon: Broken.folder,
      titleText: lang.listOfFolders,
      subtitle: _FoldersCountSubtitle(
        foldersRx: settings.directoriesToScan,
      ),
      trailingBuilder: (arrow) => _AddFolderTrailing(
        arrow: arrow,
        onAdd: host.promptAddFolderType,
      ),
      children: [
        _ScanFoldersList(
          host: host,
        ),
      ],
    );
  }
}

class _ScanFoldersList extends StatelessWidget {
  final IndexerSettings host;

  const _ScanFoldersList({required this.host});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final isMediaStoreEnabled = settings.useMediaStore.valueR;
        final tiles = settings.directoriesToScan.valueR
            .map(
              (e) => _ScanFolderTile(
                dir: e,
                isMediaStoreEnabled: isMediaStoreEnabled,
                host: host,
              ),
            )
            .toFixedList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: tiles,
        );
      },
    );
  }
}

class _ScanFolderTile extends StatelessWidget {
  final DirectoryIndex dir;
  final bool isMediaStoreEnabled;
  final IndexerSettings host;

  const _ScanFolderTile({
    required this.dir,
    required this.isMediaStoreEnabled,
    required this.host,
  });

  void _onRemoveTap() {
    if (settings.directoriesToScan.value.length == 1) {
      snackyy(
        title: lang.minimumOneItem,
        message: lang.minimumOneFolderSubtitle,
        displayDuration: SnackDisplayDuration.veryLong,
      );
      return;
    }
    final dir = this.dir;
    String bodyText = "${lang.remove} \"${dir.toSourceInfo()}\"?";
    if (dir.isServer) {
      final title = [dir.type.toText(), dir.username ?? '?'].joinText(separator: ' - ');
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
            onTap: () {
              settings.directoriesToScan.update((list) => list.remove(dir));
              if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
              NamidaNavigator.inst.closeDialog();
              host._maybeShowRefreshPromptDialog(true);
            },
          ),
        ],
        bodyText: bodyText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dir = this.dir;
    final type = dir.type;
    final assetImagePath = type.toAssetImage();
    final leading = assetImagePath == null
        ? Icon(
            type.toIcon(),
            size: 20.0,
          )
        : Image.asset(
            assetImagePath,
            height: 20.0,
          );
    final isServer = dir is DirectoryIndexServer;
    final subtitle = isServer
        ? [
            type.toText(),
            dir.username,
          ].joinText(separator: ' - ')
        : isMediaStoreEnabled
        ? lang.mediaStoreIsEnabledThisWillHaveNoEffect
        : null;
    return CustomListTile(
      extraDense: true,
      leading: leading,
      title: dir.toSourceInfo(),
      subtitle: subtitle,
      trailingRaw: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isServer)
            IconButton(
              onPressed: () => host._reAuthDirIndex(dir),
              icon: Obx(
                (context) {
                  final hasAuth = MusicWebServerAuthDetails.manager.dirHasAuthInfoR(dir);
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
          NamidaTextButton(
            minHeight: NamidaTextButton.kDefaultMinHeight * 0.8,
            onTap: _onRemoveTap,
            text: lang.remove.toUpperCase(),
            fontSizeMultiplier: 0.92,
          ),
        ],
      ),
    );
  }
}

class _FoldersToExcludeTile extends StatelessWidget {
  final SettingTileArgs args;

  const _FoldersToExcludeTile({required this.args});

  @override
  Widget build(BuildContext context) {
    final host = IndexerSettings._forTile(args);
    final isTargetWithin = args.page?.isTargetWithin(args.entry) == true;
    return NamidaExpansionTile(
      bgColor: args.bgColor,
      initiallyExpanded: isTargetWithin,
      icon: Broken.folder_minus,
      titleText: lang.excludedFodlers,
      subtitle: _FoldersCountSubtitle(
        foldersRx: settings.directoriesToExclude,
      ),
      trailingBuilder: (arrow) => _AddFolderTrailing(
        arrow: arrow,
        onAdd: host._promptAddExcludedFolder,
      ),
      children: [
        _ExcludedFoldersList(
          host: host,
        ),
      ],
    );
  }
}

class _ExcludedFoldersList extends StatelessWidget {
  final IndexerSettings host;

  const _ExcludedFoldersList({required this.host});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.directoriesToExclude,
      builder: (context, directoriesToExclude) {
        if (directoriesToExclude.isEmpty) {
          return ListTile(
            title: Text(
              lang.noExcludedFolders,
              style: context.textTheme.displayMedium,
            ),
          );
        }
        final tiles = directoriesToExclude
            .map(
              (e) => _ExcludedFolderTile(
                dir: e,
                host: host,
              ),
            )
            .toFixedList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: tiles,
        );
      },
    );
  }
}

class _ExcludedFolderTile extends StatelessWidget {
  final DirectoryIndex dir;
  final IndexerSettings host;

  const _ExcludedFolderTile({
    required this.dir,
    required this.host,
  });

  void _onRemoveTap() {
    settings.directoriesToExclude.update((list) => list.remove(dir));
    host._maybeShowRefreshPromptDialog(true);
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      title: dir.toSourceInfo(),
      subtitle: dir.username,
      trailingRaw: NamidaTextButton(
        minHeight: NamidaTextButton.kDefaultMinHeight * 0.8,
        onTap: _onRemoveTap,
        text: lang.remove.toUpperCase(),
        fontSizeMultiplier: 0.92,
      ),
    );
  }
}

class _FoldersCountSubtitle extends StatelessWidget {
  final RxBaseCore<List<DirectoryIndex>> foldersRx;

  const _FoldersCountSubtitle({required this.foldersRx});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return ObxO(
      rx: foldersRx,
      builder: (context, folders) => Text(
        folders.length.displayFolderKeyword,
        style: textTheme.displaySmall,
      ),
    );
  }
}

class _AddFolderTrailing extends StatelessWidget {
  final Widget arrow;
  final void Function() onAdd;

  const _AddFolderTrailing({
    required this.arrow,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NamidaButton(
          icon: Broken.folder_add,
          text: lang.add,
          opaqueBG: true,
          onTap: onAdd,
        ),
        arrow,
      ],
    );
  }
}

class _ChipsEditorDialog extends StatelessWidget {
  final String title;
  final Widget? bottomWidget;
  final TextEditingController controller;
  final RxBaseCore<List<String>> itemsList;
  final void Function(String value) onAdd;
  final void Function(String value) onRemove;

  const _ChipsEditorDialog({
    required this.title,
    this.bottomWidget,
    required this.controller,
    required this.itemsList,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return CustomBlurryDialog(
      title: title,
      actions: [
        Padding(
          padding: const EdgeInsetsGeometry.symmetric(horizontal: 4.0),
          child: NamidaTextButton(
            onTap: NamidaNavigator.inst.closeDialog,
            text: lang.done,
          ),
        ),
        NamidaButton(
          text: lang.add,
          onTap: () => onAdd(controller.text),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            (context) => Wrap(
              children: [
                ...itemsList.valueR.map(
                  (e) => _TextChip(
                    text: e,
                    onRemove: () => onRemove(e),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 12.0,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14.0),
            child: CustomTagTextField(
              controller: controller,
              hintText: lang.value,
              labelText: '',
            ),
          ),
          ?bottomWidget,
        ],
      ),
    );
  }
}

Future<void> showRefreshPromptDialog(bool didModifyFolder, {bool allowBypassing = false}) async {
  // [didModifyFolder] was mainly used to force recheck libraries, now it will always recheck.
  RefreshLibraryIconController.repeat();
  final currentFiles = await Indexer.inst.getAudioFilesForRefresh();
  RefreshLibraryIconController.fling().ignoreError().whenComplete(RefreshLibraryIconController.stop);

  Widget? bypassWidget;
  if (allowBypassing) {
    if (settings.bypassRefreshPrompt.value) {
      VideoController.inst.rescanLocalVideosPaths();
      await Indexer.inst.refreshLibraryAndCheckForDiff(
        currentFiles: currentFiles,
      );
      return;
    }

    bypassWidget = ListTileWithCheckMark(
      icon: Broken.message_question,
      title: lang.dontAskAgain,
      activeRx: settings.bypassRefreshPrompt,
      onTap: () => settings.bypassRefreshPrompt.save(!settings.bypassRefreshPrompt.value),
    );
  }

  final pathsDifference = Indexer.inst.getPathsDifference(currentFiles);
  final newPaths = pathsDifference.newPaths;
  final modifiedPaths = pathsDifference.modifiedPaths;
  final deletedPath = pathsDifference.deletedPaths;

  final settingsServers = settings.directoriesToScan.value.allServers();
  final hasServer = settingsServers.isNotEmpty || allTracksInLibrary.any((element) => element.isNetwork);
  final noLocalChanges = newPaths.isEmpty && modifiedPaths.isEmpty && deletedPath.isEmpty;
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
                    icon: Broken.edit_2,
                    label: lang.changed,
                    colorScheme: Colors.orange,
                    paths: modifiedPaths,
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

    if (bypassWidget != null) {
      bodyWidgets.add(
        const NamidaContainerDivider(
          margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        ),
      );
      bodyWidgets.add(bypassWidget);
      bodyWidgets.add(const SizedBox(height: 8.0));
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
              onTap: () async {
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
    _loopControllers((c) {
      try {
        c?.stop();
      } catch (_) {}
    });
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

// class _ExtractingPathsWidget extends StatefulWidget {
//   final EdgeInsetsGeometry itemPadding;
//   const _ExtractingPathsWidget({required this.itemPadding});

//   @override
//   State<_ExtractingPathsWidget> createState() => __ExtractingPathsWidgetState();
// }

// class __ExtractingPathsWidgetState extends State<_ExtractingPathsWidget> {
//   final _scrollController = ScrollController();
//   bool _isPathsExpanded = false;

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = context.textTheme;
//     return NamidaInkWell(
//       onTap: () => setState(() => _isPathsExpanded = !_isPathsExpanded),
//       child: ObxO(
//         rx: NamidaTaggerController.inst.currentPathsBeingExtracted,
//         builder: (context, pathsMap) {
//           final paths = pathsMap.values.toFixedList();
//           return paths.isEmpty
//               ? const SizedBox()
//               : SizedBox(
//                   height: 128.0,
//                   child: NamidaScrollbar(
//                     showOnStart: true,
//                     controller: _scrollController,
//                     child: SuperSmoothListView.builder(
//                       controller: _scrollController,
//                       itemCount: paths.length,
//                       itemBuilder: (context, index) {
//                         final e = paths[index];
//                         return Padding(
//                           padding: widget.itemPadding,
//                           child: Text(
//                             e,
//                             maxLines: _isPathsExpanded ? null : 1,
//                             overflow: _isPathsExpanded ? null : TextOverflow.ellipsis,
//                             style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 );
//         },
//       ),
//     );
//   }
// }

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
    final pathsList = paths.toFixedList();
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
    final itemsColor = Colors.white.withOpacityExt(0.75);
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
            color: itemsColor,
          ),
          const SizedBox(width: 2.0),
          Flexible(
            child: Text(
              '$label: ${paths.length.displayFilesKeyword}',
              style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 12.0, color: itemsColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeparatorsTypeTile extends StatelessWidget {
  final _SeparatorsType type;
  final void Function() onTap;

  const _SeparatorsTypeTile({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final separatorsRx = type.getList(isBlacklist: false).rx;
    final blacklistRx = type.getList(isBlacklist: true).rx;
    final extraFields = type.toExtraFieldsText();
    final titleSuffix = extraFields == null ? null : '  ($extraFields)';
    return Obx(
      (context) {
        final separators = separatorsRx.valueR;
        final blacklistCount = blacklistRx.valueR.length;
        final separatorsText = separators.map((e) => _SeparatorsType.toDisplayText(e).trim()).join('  ');
        final blacklistCountWidget = blacklistCount == 0
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Broken.slash,
                    size: 16.0,
                  ),
                  const SizedBox(
                    width: 4.0,
                  ),
                  Text(
                    '$blacklistCount',
                    style: textTheme.displaySmall,
                  ),
                ],
              );
        return CustomListTile(
          icon: type.toIcon(),
          title: type.toText(),
          titleSuffix: titleSuffix,
          subtitle: separatorsText,
          trailing: blacklistCountWidget,
          onTap: onTap,
        );
      },
    );
  }
}

class _SeparatorsDialog extends StatefulWidget {
  final _SeparatorsType type;

  const _SeparatorsDialog({
    required this.type,
  });

  @override
  State<_SeparatorsDialog> createState() => _SeparatorsDialogState();
}

class _SeparatorsDialogState extends State<_SeparatorsDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add({required bool isBlacklist}) {
    final text = _controller.text;
    if (text.isEmpty) {
      snackyy(title: lang.emptyValue, message: isBlacklist ? lang.pleaseEnterAName : lang.enterSymbol);
      return;
    }
    final value = isBlacklist ? text : _SeparatorsType.fromInputText(text);
    final items = widget.type.getList(isBlacklist: isBlacklist);
    items.update((list) => list.addNoDuplicates(value));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final type = widget.type;
    final separators = type.getList(isBlacklist: false);
    final blacklist = type.getList(isBlacklist: true);
    return CustomBlurryDialog(
      title: type.toText(),
      normalTitleStyle: true,
      icon: type.toIcon(),
      actions: [
        NamidaButton(
          text: lang.blacklist,
          onTap: () => _add(isBlacklist: true),
        ),
        NamidaButton(
          text: lang.add,
          onTap: () => _add(isBlacklist: false),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.separatorsMessage,
            style: textTheme.displaySmall,
          ),
          const SizedBox(
            height: 16.0,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.separators,
                  style: textTheme.displayMedium,
                ),
              ),
              NamidaIconButton(
                icon: Broken.refresh,
                iconSize: 20.0,
                tooltip: () => lang.restoreDefaults,
                onPressed: separators.reset,
              ),
            ],
          ),
          const SizedBox(
            height: 8.0,
          ),
          _SeparatorsChips(
            list: separators,
          ),
          const SizedBox(
            height: 16.0,
          ),
          Text(
            lang.blacklist,
            style: textTheme.displayMedium,
          ),
          Text(
            lang.separatorsBlacklistSubtitle,
            style: textTheme.displaySmall,
          ),
          const SizedBox(
            height: 4.0,
          ),
          _SeparatorsChips(
            list: blacklist,
          ),
          const SizedBox(
            height: 16.0,
          ),
          CustomTagTextField(
            controller: _controller,
            hintText: lang.value,
            labelText: '',
          ),
          const SizedBox(
            height: 4.0,
          ),
          _SeparatorsPreview(
            type: type,
            controller: _controller,
          ),
        ],
      ),
    );
  }
}

class _SeparatorsChips extends StatelessWidget {
  final _SeparatorsList list;

  const _SeparatorsChips({
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => Wrap(
        children: [
          ...list.rx.valueR.map(
            (e) => _TextChip(
              text: _SeparatorsType.toDisplayText(e),
              onRemove: () => list.update((items) => items.remove(e)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeparatorsPreview extends StatelessWidget {
  final _SeparatorsType type;
  final TextEditingController controller;

  const _SeparatorsPreview({
    required this.type,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.textTheme.displaySmall;
    final emptyLabelColor = labelStyle?.color?.withOpacityExt(0.5);
    final emptyLabelStyle = labelStyle?.copyWith(color: emptyLabelColor);
    final separatorsRx = type.getList(isBlacklist: false).rx;
    final blacklistRx = type.getList(isBlacklist: true).rx;
    return SizedBox(
      height: 40.0,
      child: Obx(
        (context) {
          final blacklist = blacklistRx.valueR;
          final config = SplitterConfig(
            separators: separatorsRx.valueR,
            separatorsBlacklist: blacklist,
          );
          final blacklistLower = blacklist.map((e) => config.normalize(e).toLowerCase()).toSet();
          return ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) {
              final text = value.text;
              final parts = text.isEmpty ? const <String>[] : config.splitText(text);
              return Row(
                children: [
                  Text(
                    '${lang.preview}:',
                    style: parts.isEmpty ? emptyLabelStyle : labelStyle,
                  ),
                  Expanded(
                    child: SmoothSingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...parts.map(
                            (e) => _TextChip(
                              text: e,
                              isHighlighted: blacklistLower.contains(e.toLowerCase()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String text;
  final bool isHighlighted;
  final void Function()? onRemove;

  const _TextChip({
    required this.text,
    this.isHighlighted = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final borderColor = isHighlighted ? theme.colorScheme.secondary : Colors.transparent;
    return NamidaInkWell(
      onTap: onRemove,
      margin: const EdgeInsets.all(4.0),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
      bgColor: theme.cardTheme.color,
      borderRadius: 16.0,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: theme.textTheme.displayMedium,
          ),
          if (onRemove != null) ...[
            const SizedBox(
              width: 6.0,
            ),
            const Icon(
              Broken.close_circle,
              size: 18.0,
            ),
          ],
        ],
      ),
    );
  }
}

enum _SeparatorsType {
  artists,
  genres,
  albums,
  ;

  static const _kNbsp = '\u00A0';
  static const _kNbspLabel = 'NBSP';

  static String toDisplayText(String separator) => separator == _kNbsp ? _kNbspLabel : separator;

  static String fromInputText(String text) => text.toUpperCase() == _kNbspLabel ? _kNbsp : text;

  String toText() => switch (this) {
    _SeparatorsType.artists => lang.artists,
    _SeparatorsType.genres => lang.genres,
    _SeparatorsType.albums => lang.albums,
  };

  String? toExtraFieldsText() => switch (this) {
    _SeparatorsType.artists => '${lang.albumArtist}, ${lang.composer}',
    _SeparatorsType.genres => lang.style,
    _SeparatorsType.albums => null,
  };

  IconData toIcon() => switch (this) {
    _SeparatorsType.artists => Broken.profile_2user,
    _SeparatorsType.genres => MediaType.genre.toIcon(),
    _SeparatorsType.albums => MediaType.album.toIcon(),
  };

  _SeparatorsList getList({required bool isBlacklist}) {
    final key = switch (this) {
      _SeparatorsType.artists => isBlacklist ? settings.trackArtistsSeparatorsBlacklist : settings.trackArtistsSeparators,
      _SeparatorsType.genres => isBlacklist ? settings.trackGenresSeparatorsBlacklist : settings.trackGenresSeparators,
      _SeparatorsType.albums => isBlacklist ? settings.trackAlbumsSeparatorsBlacklist : settings.trackAlbumsSeparators,
    };
    return (rx: key, update: key.update, reset: key.reset);
  }
}

typedef _SeparatorsList = ({RxBaseCore<List<String>> rx, void Function(void Function(List<String> list) fn) update, void Function() reset});
