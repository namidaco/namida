// by claude
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'artwork_source_menu.crop.dart';

/// every way of getting a new artwork in one menu: storage, paste, web search, folder cover, youtube thumbnail, crop and remove.
class ArtworkSourceMenu extends StatefulWidget {
  final Widget Function(VoidCallback openMenu) childBuilder;
  final FutureOr<void> Function(String imagePath) onArtworkObtained;
  final VoidCallback onRemove;
  final bool Function() canRemove;
  final bool Function() canCrop;
  final Future<Uint8List?> Function() getArtworkBytes;
  final String Function() getSearchQuery;
  final String? youtubeId;
  final String? folderCoverPath;
  final List<NamidaPopupItem> Function()? getExtraItems;

  /// opens the menu once the route showing it finishes opening. a menu built after that (ex: under a new key) stays closed.
  final bool openOnRouteEnter;

  const ArtworkSourceMenu({
    super.key,
    required this.childBuilder,
    required this.onArtworkObtained,
    required this.onRemove,
    required this.canRemove,
    required this.canCrop,
    required this.getArtworkBytes,
    required this.getSearchQuery,
    this.youtubeId,
    this.folderCoverPath,
    this.getExtraItems,
    this.openOnRouteEnter = false,
  });

  /// `artist album cover`, the title takes the place of a missing album.
  static String buildSearchQuery({required String? artist, required String? album, required String? title, required String fallback}) {
    final knownAlbum = album == UnknownTags.ALBUM ? null : album?.nullifyEmpty();
    final name = knownAlbum ?? title?.nullifyEmpty();
    if (name == null) return fallback;
    final knownArtist = artist == UnknownTags.ARTIST ? null : artist?.nullifyEmpty();
    return knownArtist == null ? '$name cover' : '$knownArtist $name cover';
  }

  @override
  State<ArtworkSourceMenu> createState() => _ArtworkSourceMenuState();
}

class _ArtworkSourceMenuState extends State<ArtworkSourceMenu> {
  @override
  void initState() {
    super.initState();
    if (widget.openOnRouteEnter) WidgetsBinding.instance.addPostFrameCallback(_openOnRouteEnter);
  }

  void _openOnRouteEnter(Duration _) {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status != AnimationStatus.forward) return;
    void onStatus(AnimationStatus status) {
      if (!status.isCompleted) return;
      animation.removeStatusListener(onStatus);
      if (mounted) _createPopup().showPopupMenu(context);
    }

    animation.addStatusListener(onStatus);
  }

  static const _kClipboardImageFormats = [
    (format: Formats.png, extension: 'png'),
    (format: Formats.jpeg, extension: 'jpg'),
    (format: Formats.webp, extension: 'webp'),
  ];

  static Future<String> _writeTempImage(Uint8List bytes, String extension) async {
    final tempDirectoryPath = Directory.systemTemp.path;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final tempFilePath = FileParts.joinPath(tempDirectoryPath, 'namida_artwork_$stamp.$extension');
    final tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(bytes);
    return tempFilePath;
  }

  static Future<String?> _readClipboardImageToTempFile(SystemClipboard clipboard) async {
    final reader = await clipboard.read();
    final imageFormat = _kClipboardImageFormats.firstWhereEff((e) => reader.canProvide(e.format));
    if (imageFormat == null) return null;
    final completer = Completer<String?>();
    final progress = reader.getFile(
      imageFormat.format,
      (file) async {
        try {
          final bytes = await file.readAll();
          final imagePath = await _writeTempImage(bytes, imageFormat.extension);
          completer.completeIfWasnt(imagePath);
        } catch (_) {
          completer.completeIfWasnt(null);
        }
      },
      onError: (_) => completer.completeIfWasnt(null),
    );
    if (progress == null) return null;
    return completer.future;
  }

  Future<void> _onPickFromStorageTap() async {
    final pickedFile = await NamidaFileBrowser.pickFile(note: lang.editArtwork, memeType: NamidaStorageFileMemeType.image);
    final imagePath = pickedFile?.path;
    if (imagePath == null || imagePath.isEmpty) return;
    await widget.onArtworkObtained(imagePath);
  }

  Future<void> _onPasteTap(SystemClipboard clipboard) async {
    String? imagePath;
    try {
      imagePath = await _readClipboardImageToTempFile(clipboard);
    } catch (_) {}
    if (imagePath == null) {
      snackyy(title: lang.error, message: '${lang.failed}: ${lang.paste}', isError: true);
      return;
    }
    await widget.onArtworkObtained(imagePath);
  }

  Future<void> _onCropTap() async {
    final ui.Image image;
    try {
      final bytes = await widget.getArtworkBytes();
      if (bytes == null || bytes.isEmpty) return;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      image = frame.image;
    } catch (e) {
      snackyy(title: lang.error, message: '$e', isError: true);
      return;
    }
    final croppedBytes = await _ArtworkCropDialog.show(image);
    if (croppedBytes == null) return;
    final imagePath = await _writeTempImage(croppedBytes, 'png');
    await widget.onArtworkObtained(imagePath);
  }

  void _onSearchOnlineTap() {
    final searchQuery = widget.getSearchQuery();
    final query = Uri.encodeComponent(searchQuery);
    final url = 'https://www.google.com/search?tbm=isch&q=$query';
    NamidaLinkUtils.openLink(url, preferredMode: LaunchMode.externalApplication);
  }

  Future<void> _onYoutubeThumbnailTap(String youtubeId) async {
    final tempDirectoryPath = Directory.systemTemp.path;
    final tempFilePath = FileParts.joinPath(tempDirectoryPath, '$youtubeId.png');
    final res = await YoutubeInfoController.utils.getVideoThumbnailOrSquareCover(youtubeId, tempFilePath: tempFilePath);
    if (res == null) {
      snackyy(title: lang.error, message: '${lang.failed}: ${lang.youtube}', isError: true);
      return;
    }
    await widget.onArtworkObtained(res.file.path);
  }

  void _onRemoveTap() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: '${lang.remove}: ${lang.artwork}?',
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.remove.toUpperCase(),
            onTap: () {
              widget.onRemove();
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
  }

  List<NamidaPopupItem> _getMenuItems() {
    final youtubeId = widget.youtubeId;
    final folderCoverPath = widget.folderCoverPath;
    final extraItems = widget.getExtraItems?.call();
    final clipboard = SystemClipboard.instance;
    return [
      NamidaPopupItem(
        icon: Broken.gallery_import,
        title: lang.pickFromStorage,
        onTap: _onPickFromStorageTap,
      ),
      if (clipboard != null)
        NamidaPopupItem(
          icon: Broken.clipboard_import,
          title: lang.paste,
          onTap: () => _onPasteTap(clipboard),
        ),
      NamidaPopupItem(
        icon: Broken.global_search,
        title: '${lang.search}: Google',
        onTap: _onSearchOnlineTap,
      ),
      ...?extraItems,
      if (folderCoverPath != null)
        NamidaPopupItem(
          icon: Broken.folder,
          title: lang.folder,
          trailing: ArtworkWidget(
            key: Key(folderCoverPath),
            path: folderCoverPath,
            thumbnailSize: 24.0,
            borderRadius: 4.0,
            fadeMilliSeconds: 0,
            extractInternally: false,
            fallbackToFolderCover: false,
          ),
          onTap: () => widget.onArtworkObtained(folderCoverPath),
        ),
      if (youtubeId != null)
        NamidaPopupItem(
          icon: Broken.video_square,
          title: lang.youtube,
          trailing: YoutubeThumbnail(
            key: Key(youtubeId),
            type: ThumbnailType.video,
            videoId: youtubeId,
            width: 40.0,
            height: 40.0 * 9 / 16,
            borderRadius: 4.0,
            iconSize: 12.0,
            isImportantInCache: true,
          ),
          onTap: () => _onYoutubeThumbnailTap(youtubeId),
        ),
      if (widget.canCrop())
        NamidaPopupItem(
          icon: Broken.crop,
          title: lang.crop,
          onTap: _onCropTap,
        ),
      if (widget.canRemove())
        NamidaPopupItem(
          icon: Broken.gallery_remove,
          title: lang.remove,
          onTap: _onRemoveTap,
        ),
    ];
  }

  NamidaPopupWrapper _createPopup() {
    return NamidaPopupWrapper(
      childrenDefault: _getMenuItems,
      childBuilder: widget.childBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _createPopup();
  }
}
