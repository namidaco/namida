import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/color_m.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class YoutubeThumbnail extends StatefulWidget {
  final String? channelUrl;
  final String? videoId;
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
  final String? localImagePath;
  final bool extractColor;
  final double blur;
  final bool compressed;
  final bool isImportantInCache;

  const YoutubeThumbnail({
    super.key,
    this.channelUrl,
    this.videoId,
    this.height,
    required this.width,
    this.borderRadius = 12.0,
    this.isCircle = false,
    this.margin,
    this.onImageReady,
    this.onColorReady,
    this.onTopWidgets = const <Widget>[],
    this.smallBoxText,
    this.smallBoxIcon = Broken.play_cricle,
    this.displayFallbackIcon = true,
    this.localImagePath,
    this.extractColor = true,
    this.blur = 1.5,
    this.compressed = true,
    required this.isImportantInCache,
  });

  @override
  State<YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> {
  String? imagePath;
  Color? smallBoxDynamicColor;

  bool get canFetchYTImage => widget.videoId != null || widget.channelUrl != null;
  bool get canFetchImage => widget.localImagePath != null || canFetchYTImage;

  Key get kekekekey => Key("$smallBoxDynamicColor${widget.videoId}${widget.channelUrl}$imagePath${widget.smallBoxText}");

  Timer? _dontTouchMeImFetchingThumbnail;

  Future<void> _getThumbnail() async {
    if (_dontTouchMeImFetchingThumbnail?.isActive == true) return;
    _dontTouchMeImFetchingThumbnail = null;
    _dontTouchMeImFetchingThumbnail = Timer(const Duration(seconds: 8), () {});
    imagePath = widget.localImagePath;
    if (imagePath == null) {
      final res = await VideoController.inst.getYoutubeThumbnailAndCache(
        id: widget.videoId,
        channelUrl: widget.channelUrl,
        isImportantInCache: widget.isImportantInCache,
      );
      widget.onImageReady?.call(res);
      imagePath = res?.path;
    }
    if (mounted) setState(() {});

    if (widget.extractColor && imagePath != null) {
      final c = await CurrentColor.inst.extractPaletteFromImage(imagePath!, useIsolate: true);
      smallBoxDynamicColor = c?.color;
      widget.onColorReady?.call(c);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath == null && canFetchImage) {
      _getThumbnail();
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: widget.margin,
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: context.theme.cardColor.withAlpha(60),
        shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.isCircle
            ? null
            : BorderRadius.circular(
                widget.borderRadius.multipliedRadius,
              ),
      ),
      child: ArtworkWidget(
        compressed: widget.compressed,
        key: Key("$smallBoxDynamicColor${widget.videoId}${widget.channelUrl}$imagePath${widget.smallBoxText}"),
        blur: widget.isCircle ? 0.0 : widget.blur,
        borderRadius: widget.borderRadius,
        fadeMilliSeconds: 600,
        path: imagePath,
        height: widget.height,
        width: widget.width,
        thumbnailSize: widget.width,
        icon: widget.channelUrl != null ? Broken.user : Broken.video,
        iconSize: widget.channelUrl != null ? null : widget.width * 0.3,
        forceSquared: true,
        cacheHeight: widget.height?.round() ?? widget.width.round(),
        onTopWidgets: [
          ...widget.onTopWidgets,
          if (widget.smallBoxText != null)
            Positioned(
              bottom: 0.0,
              right: 0.0,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                  child: NamidaBgBlur(
                    blur: 3.0,
                    enabled: settings.enableBlurEffect.value,
                    child: NamidaInkWell(
                      animationDurationMS: 300,
                      borderRadius: 5.0,
                      bgColor: Color.alphaBlend(
                        Colors.black.withOpacity(0.35),
                        smallBoxDynamicColor ?? context.theme.cardColor.withAlpha(130),
                      ).withAlpha(140),
                      padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 3.0),
                      child: widget.smallBoxIcon != null
                          ? Row(
                              children: [
                                Icon(
                                  widget.smallBoxIcon,
                                  size: 16.0,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 2.0),
                                Text(
                                  widget.smallBoxText!,
                                  style: context.textTheme.displaySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
              ),
            )
        ],
        displayIcon: widget.displayFallbackIcon,
      ),
    );
  }
}
