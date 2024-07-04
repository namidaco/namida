import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:namida/core/utils.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/color_m.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

enum ThumbnailType {
  video,
  playlist,
  channel,
  other,
}

const _typeToIcon = {
  ThumbnailType.video: Broken.video,
  ThumbnailType.playlist: Broken.music_library_2,
  ThumbnailType.channel: Broken.user,
  ThumbnailType.other: null,
};

class YoutubeThumbnail extends StatefulWidget {
  final String? videoId;
  final String? customUrl;
  final String? urlSymLinkId;
  final double? height;
  final double width;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsetsGeometry? margin;
  final void Function(File? imageFile)? onImageReady;
  final void Function(NamidaColor? color)? onColorReady;
  final List<Widget> onTopWidgets;
  final String? smallBoxText;
  final IconData? smallBoxIcon;
  final bool displayFallbackIcon;
  final bool extractColor;
  final double blur;
  final bool compressed;
  final bool isImportantInCache;
  final bool preferLowerRes;
  final ThumbnailType type;
  final double? iconSize;
  final List<BoxShadow>? boxShadow;
  final bool forceSquared;

  const YoutubeThumbnail({
    required super.key,
    this.videoId,
    this.customUrl,
    this.urlSymLinkId,
    this.height,
    required this.width,
    this.borderRadius = 12.0,
    this.isCircle = false,
    this.margin,
    this.onImageReady,
    this.onColorReady,
    this.onTopWidgets = const <Widget>[],
    this.smallBoxText,
    this.smallBoxIcon,
    this.displayFallbackIcon = true,
    this.extractColor = false,
    this.blur = 1.5,
    this.compressed = true,
    required this.isImportantInCache,
    this.preferLowerRes = true,
    required this.type,
    this.iconSize,
    this.boxShadow,
    this.forceSquared = true,
  });

  @override
  State<YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> with LoadingItemsDelayMixin {
  String? imagePath;
  NamidaColor? imageColors;
  Color? smallBoxDynamicColor;
  final _thumbnailNotFound = false.obs;

  Timer? _dontTouchMeImFetchingThumbnail;

  @override
  void initState() {
    super.initState();
    _getThumbnail();
  }

  @override
  void dispose() {
    if (widget.videoId != null) ThumbnailManager.inst.closeThumbnailClients(widget.videoId!);
    if (widget.customUrl != null) ThumbnailManager.inst.closeThumbnailClients(widget.customUrl!);
    _dontTouchMeImFetchingThumbnail?.cancel();
    _dontTouchMeImFetchingThumbnail = null;
    _thumbnailNotFound.close();
    super.dispose();
  }

  Future<void> _getThumbnail() async {
    if (_dontTouchMeImFetchingThumbnail?.isActive == true) return;
    if (imagePath != null && imageColors != null) return;
    _dontTouchMeImFetchingThumbnail = null;
    _dontTouchMeImFetchingThumbnail = Timer(const Duration(seconds: 8), () {});

    void onThumbnailNotFound() => _thumbnailNotFound.value = true;

    if (imagePath == null) {
      final videoId = widget.videoId;

      File? res = ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(
        id: videoId,
        customUrl: widget.customUrl,
        isTemp: false,
      );
      if (res == null && (!widget.isImportantInCache || widget.preferLowerRes)) {
        res = ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(
          id: videoId,
          customUrl: widget.customUrl,
          isTemp: true,
        );
      }

      if (res == null) {
        await Future.delayed(Duration.zero);
        if (!await canStartLoadingItems()) return;
        if (videoId != null) {
          // -- for video:
          // --- isImportantInCache -> fetch to file
          // --- !isImportantInCache -> fetch lowres temp file only
          if (widget.isImportantInCache && !widget.preferLowerRes) {
            res = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
              id: videoId,
              isImportantInCache: true,
              onNotFound: onThumbnailNotFound,
            );
          } else {
            res = await ThumbnailManager.inst.getLowResYoutubeVideoThumbnail(videoId, onNotFound: onThumbnailNotFound);
          }
        } else {
          // for channels/playlists -> default
          res = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
            customUrl: widget.customUrl,
            symlinkId: widget.urlSymLinkId,
            isImportantInCache: widget.isImportantInCache,
            onNotFound: onThumbnailNotFound,
          );
        }
      }

      widget.onImageReady?.call(res);

      // -- only put the image if bytes are NOT valid, or if specified by parent
      final newPath = res?.path;
      if (imagePath != newPath) {
        refreshState(() => imagePath = newPath);
      }
    }

    if (imageColors == null && widget.extractColor && imagePath != null) {
      final c = await CurrentColor.inst.extractPaletteFromImage(
        imagePath!,
        useIsolate: true,
        paletteSaveDirectory: Directory(AppDirs.YT_PALETTES),
      );
      imageColors = c ?? NamidaColor(used: null, mix: playerStaticColor, palette: [playerStaticColor]);
      widget.onColorReady?.call(c);
      if (mounted) setState(() => smallBoxDynamicColor = c?.color);
    }
  }

  Key get thumbKey => Key("$smallBoxDynamicColor${widget.videoId}${widget.customUrl}${widget.urlSymLinkId}$imagePath${widget.smallBoxText}");

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: ArtworkWidget(
        key: thumbKey,
        onError: () {
          imagePath = null;
          imageColors = null;
          smallBoxDynamicColor = null;
          _getThumbnail();
        },
        isCircle: widget.isCircle,
        bgcolor: context.theme.cardColor.withAlpha(60),
        compressed: widget.compressed,
        blur: widget.isCircle ? 0.0 : widget.blur,
        borderRadius: widget.isCircle ? 0.0 : widget.borderRadius,
        fadeMilliSeconds: 200,
        path: imagePath,
        height: widget.height,
        width: widget.width,
        thumbnailSize: widget.width,
        boxShadow: widget.boxShadow,
        icon: _typeToIcon[widget.type] ?? Broken.musicnote,
        iconSize: widget.iconSize ?? (widget.customUrl != null ? null : widget.width * 0.3),
        forceSquared: widget.forceSquared,
        // cacheHeight: (widget.height?.round() ?? widget.width.round()) ~/ 1.2,
        onTopWidgets: [
          ...widget.onTopWidgets,
          if (widget.smallBoxText != null || widget.smallBoxIcon != null)
            Positioned(
              bottom: 0.0,
              right: 0.0,
              child: Container(
                clipBehavior: Clip.hardEdge,
                margin: const EdgeInsets.all(2.0),
                padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0.multipliedRadius),
                  color: Colors.black.withOpacity(0.3),
                ),
                child: NamidaBgBlur(
                  blur: 2.0,
                  enabled: settings.enableBlurEffect.value,
                  child: widget.smallBoxIcon != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.smallBoxIcon,
                              size: 15.0,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            if (widget.smallBoxText != null) ...[
                              const SizedBox(width: 2.0),
                              Text(
                                widget.smallBoxText!,
                                style: context.textTheme.displaySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Text(
                          widget.smallBoxText!,
                          style: context.textTheme.displaySmall?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          ObxO(
            rx: _thumbnailNotFound,
            builder: (notFound) => notFound
                ? Positioned(
                    top: 0.0,
                    right: 0.0,
                    child: Container(
                      clipBehavior: Clip.hardEdge,
                      margin: const EdgeInsets.all(2.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.0.multipliedRadius),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Icon(
                        Broken.danger,
                        size: 12.0,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  )
                : const SizedBox(),
          )
        ],
        displayIcon: widget.displayFallbackIcon,
      ),
    );
  }
}
