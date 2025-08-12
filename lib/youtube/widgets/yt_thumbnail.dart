import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/color_m.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

enum ThumbnailType {
  video(Broken.video),
  playlist(Broken.music_library_2),
  channel(Broken.user),
  other(null);

  final IconData? icon;
  const ThumbnailType(this.icon);
}

class YoutubeThumbnail extends StatefulWidget {
  final String? videoId;
  final String? customUrl;
  final String? urlSymLinkId;
  final double? height;
  final double width;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsetsGeometry? margin;
  final void Function()? onImageFetchStart;
  final void Function(File? imageFile)? onImageReady;
  final void Function(NamidaColor? color)? onColorReady;
  final List<Widget> Function(NamidaColor? color)? onTopWidgets;
  final String? smallBoxText;
  final IconData? smallBoxIcon;
  final bool displayFallbackIcon;
  final bool extractColor;
  final double blur;
  final bool? enableGlow;
  final bool compressed;
  final bool isImportantInCache;
  final bool preferLowerRes;
  final ThumbnailType type;
  final double? iconSize;
  final List<BoxShadow>? boxShadow;
  final bool forceSquared;
  final bool? fetchMissingIfRequired;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final int fadeMilliSeconds;
  final bool disableBlurBgSizeShrink;
  final bool reduceInitialFlashes;

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
    this.onImageFetchStart,
    this.onImageReady,
    this.onColorReady,
    this.onTopWidgets,
    this.smallBoxText,
    this.smallBoxIcon,
    this.displayFallbackIcon = true,
    this.extractColor = false,
    this.blur = 5.0,
    this.enableGlow,
    this.compressed = true,
    required this.isImportantInCache,
    this.preferLowerRes = true,
    required this.type,
    this.iconSize,
    this.boxShadow,
    this.forceSquared = true,
    this.fetchMissingIfRequired,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fadeMilliSeconds = 200,
    this.disableBlurBgSizeShrink = false,
    this.reduceInitialFlashes = false,
  });

  @override
  State<YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> with LoadingItemsDelayMixin {
  String? imagePath = ArtworkWidget.kImagePathInitialValue;
  NamidaColor? imageColors;
  Color? smallBoxDynamicColor;

  Timer? _dontTouchMeImFetchingThumbnail;

  bool? requestedThumbnailTemp;
  bool? requestedThumbnailNonTemp;

  @override
  void initState() {
    super.initState();
    _getThumbnail();
  }

  @override
  void dispose() {
    if (widget.videoId != null) {
      if (requestedThumbnailTemp == true) ThumbnailManager.inst.closeThumbnailClients(widget.videoId!, true);
      if (requestedThumbnailNonTemp == true) ThumbnailManager.inst.closeThumbnailClients(widget.videoId!, false);
    }
    if (widget.customUrl != null) {
      if (requestedThumbnailTemp == true) ThumbnailManager.inst.closeThumbnailClients(widget.customUrl!, true);
      if (requestedThumbnailNonTemp == true) ThumbnailManager.inst.closeThumbnailClients(widget.customUrl!, false);
    }
    _dontTouchMeImFetchingThumbnail?.cancel();
    _dontTouchMeImFetchingThumbnail = null;
    super.dispose();
  }

  Future<void> _getThumbnail() async {
    if (_dontTouchMeImFetchingThumbnail?.isActive == true) return;
    if (imagePath != ArtworkWidget.kImagePathInitialValue && imageColors != null) return;

    if (imagePath == ArtworkWidget.kImagePathInitialValue) {
      // -- basic init
      if (widget.reduceInitialFlashes) {
        imagePath = ThumbnailManager.inst
                .imageUrlToCacheFile(
                  id: widget.videoId,
                  url: widget.customUrl,
                  isTemp: !widget.isImportantInCache,
                  type: widget.type,
                )
                ?.path ??
            ArtworkWidget.kImagePathInitialValue;
      }

      final videoId = widget.videoId;

      File? res = await ThumbnailManager.inst.getYoutubeThumbnailFromCache(
        id: videoId,
        customUrl: widget.customUrl,
        isTemp: false,
        type: widget.type,
      );
      if (res == null && (!widget.isImportantInCache || widget.preferLowerRes)) {
        res = await ThumbnailManager.inst.getYoutubeThumbnailFromCache(
          id: videoId,
          customUrl: widget.customUrl,
          isTemp: true,
          type: widget.type,
        );
      }

      if (res == null) {
        widget.onImageFetchStart?.call();

        _dontTouchMeImFetchingThumbnail?.cancel();
        _dontTouchMeImFetchingThumbnail = Timer(const Duration(seconds: 8), () {});
        await Future.delayed(Duration.zero);
        if (!await canStartLoadingItems()) return;
        if (videoId != null) {
          // -- for video:
          // --- isImportantInCache -> fetch to file
          // --- !isImportantInCache -> fetch lowres temp file only
          if (widget.isImportantInCache && !widget.preferLowerRes) {
            requestedThumbnailNonTemp = true;
            res = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
              id: videoId,
              isImportantInCache: true,
              type: widget.type,
            );
          } else {
            res = await ThumbnailManager.inst.getLowResYoutubeVideoThumbnail(videoId);
          }
        } else {
          // for channels/playlists -> default
          widget.isImportantInCache ? requestedThumbnailNonTemp = true : requestedThumbnailTemp = true;
          res = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
            customUrl: widget.customUrl,
            symlinkId: widget.urlSymLinkId,
            isImportantInCache: widget.isImportantInCache,
            type: widget.type,
          );
        }
      }

      if (res == null && widget.fetchMissingIfRequired == true && videoId != null) {
        res = await YoutubeInfoController.missingInfo.fetchMissingThumbnail(videoId);
      }

      widget.onImageReady?.call(res);

      // -- only put the image if bytes are NOT valid, or if specified by parent
      String? newPath = res?.path;
      newPath ??= ArtworkWidget.kImagePathInitialValue;
      if (imagePath != newPath) {
        refreshState(() => imagePath = newPath);
      }
    }

    if (imageColors == null && widget.extractColor && imagePath != null && imagePath != ArtworkWidget.kImagePathInitialValue) {
      final c = await CurrentColor.inst.extractPaletteFromImage(
        imagePath!,
        useIsolate: true,
        paletteSaveDirectory: Directory(AppDirs.YT_PALETTES),
      );
      imageColors = c ?? NamidaColor.single(playerStaticColor);
      widget.onColorReady?.call(c);
      if (mounted) setState(() => smallBoxDynamicColor = c?.color);
    }

    if (imagePath == ArtworkWidget.kImagePathInitialValue && widget.displayFallbackIcon) {
      if (mounted) setState(() => imagePath = null);
    }
  }

  Key get thumbKey => Key("$smallBoxDynamicColor${widget.videoId}${widget.customUrl}${widget.urlSymLinkId}$imagePath${widget.smallBoxText}");

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: ArtworkWidget(
        key: thumbKey,
        isCircle: widget.isCircle,
        bgcolor: context.theme.cardColor.withAlpha(60),
        compressed: widget.compressed,
        blur: widget.blur,
        enableGlow: widget.enableGlow,
        disableBlurBgSizeShrink: widget.disableBlurBgSizeShrink,
        borderRadius: widget.isCircle ? 0.0 : widget.borderRadius,
        fadeMilliSeconds: widget.fadeMilliSeconds,
        path: imagePath,
        height: widget.height,
        width: widget.width,
        thumbnailSize: widget.width,
        boxShadow: widget.boxShadow,
        icon: widget.type.icon ?? Broken.musicnote,
        iconSize: widget.iconSize ?? widget.width * 0.3,
        forceSquared: widget.forceSquared,
        // cacheHeight: (widget.height?.round() ?? widget.width.round()) ~/ 1.2,
        onTopWidgets: [
          ...?widget.onTopWidgets?.call(imageColors),
          if (widget.smallBoxText != null || widget.smallBoxIcon != null)
            Positioned(
              bottom: 0.0,
              right: 0.0,
              child: YtThumbnailOverlayBox(
                text: widget.smallBoxText,
                icon: widget.smallBoxIcon,
              ),
            ),
        ],
        displayIcon: true,
        fit: widget.fit,
        alignment: widget.alignment,
        extractInternally: false,
      ),
    );
  }
}

class YtThumbnailOverlayBox extends StatelessWidget {
  final String? text;
  final IconData? icon;

  const YtThumbnailOverlayBox({
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: NamidaBgBlurClipped(
        blur: 2.0,
        enabled: settings.enableBlurEffect.value,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5.0.multipliedRadius),
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 15.0,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              if (text != null && icon != null) const SizedBox(width: 2.0),
              if (text != null)
                Text(
                  text!,
                  style: context.textTheme.displaySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
