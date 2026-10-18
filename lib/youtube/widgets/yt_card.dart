import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/class/color_m.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YoutubeCard extends StatelessWidget {
  final String? videoId;
  final String? thumbnailUrl;
  final void Function()? onTap;
  final double borderRadius;
  final bool shimmerEnabled;
  final String title;
  final String subtitle;
  final String thirdLineText;
  final String? channelThumbnailUrl;
  final String? channelID;
  final bool displayChannelThumbnail;
  final bool displaythirdLineText;
  final List<Widget> Function(double width, double height, NamidaColor? imageColors)? onTopWidgets;
  final String? smallBoxText;
  final bool? checkmarkStatus;
  final double thumbnailWidthPercentage;
  final IconData? smallBoxIcon;
  final bool extractColor;
  final void Function(NamidaColor? color)? onColorReady;
  final FutureOr<List<NamidaPopupItem>> Function()? menuChildrenDefault;
  final bool isCircle;
  final List<Widget> bottomRightWidgets;
  final bool isImageImportantInCache;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final double fontMultiplier;
  final ThumbnailType thumbnailType;

  const YoutubeCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    this.onTap,
    this.borderRadius = 12.0,
    required this.shimmerEnabled,
    this.title = '',
    this.subtitle = '',
    required this.thirdLineText,
    this.channelThumbnailUrl,
    this.channelID,
    this.displayChannelThumbnail = true,
    this.displaythirdLineText = true,
    this.onTopWidgets,
    this.smallBoxText,
    this.checkmarkStatus,
    this.thumbnailWidthPercentage = 1.0,
    this.smallBoxIcon,
    this.extractColor = false,
    this.onColorReady,
    this.menuChildrenDefault,
    this.isCircle = false,
    this.bottomRightWidgets = const [],
    required this.isImageImportantInCache,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.fontMultiplier = 1.0,
    required this.thumbnailType,
  });

  @override
  Widget build(BuildContext context) {
    const verticalPadding = 8.0;

    final thumbnailHeight = this.thumbnailHeight ?? (thumbnailWidthPercentage * Dimensions.youtubeThumbnailHeight);
    final thumbnailWidth = this.thumbnailWidth ?? (isCircle ? thumbnailHeight : thumbnailHeight * 16 / 9);

    final channelThumbSize = 0.25 * thumbnailHeight * thumbnailWidthPercentage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _YoutubeCardInkWell(
            checkmarkStatus: checkmarkStatus,
            borderRadius: borderRadius,
            onTap: onTap,
            height: thumbnailHeight + verticalPadding,
            child: Row(
              children: [
                const SizedBox(width: 4.0),
                NamidaDummyContainer(
                  width: thumbnailWidth,
                  height: thumbnailHeight,
                  shimmerEnabled: shimmerEnabled,
                  child: YoutubeThumbnail(
                    key: Key("${videoId}_$thumbnailUrl"),
                    isImportantInCache: isImageImportantInCache,
                    videoId: videoId,
                    customUrl: thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    borderRadius: 10.0,
                    onTopWidgets: onTopWidgets == null ? null : (imageColors) => onTopWidgets!(thumbnailWidth, thumbnailHeight, imageColors),
                    smallBoxText: smallBoxText,
                    smallBoxIcon: smallBoxIcon,
                    extractColor: extractColor,
                    onColorReady: onColorReady,
                    isCircle: isCircle,
                    type: thumbnailType,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6.0),
                      NamidaDummyContainer(
                        width: context.width,
                        height: 10.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled && title == '',
                        child: Text(
                          title,
                          style: NText.medium.of(context).copyWith(fontSize: 13.0 * fontMultiplier),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      NamidaDummyContainer(
                        width: context.width,
                        height: 8.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled && subtitle == '',
                        child: Text(
                          subtitle,
                          style: NText.small
                              .of(context)
                              .copyWith(
                                fontWeight: FontWeight.w400,
                                fontSize: 13.0 * fontMultiplier,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      const Spacer(),
                      if (displayChannelThumbnail || displaythirdLineText || checkmarkStatus != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (displayChannelThumbnail) ...[
                              Flexible(
                                child: NamidaDummyContainer(
                                  width: channelThumbSize,
                                  height: channelThumbSize,
                                  shimmerEnabled: shimmerEnabled && (channelThumbnailUrl == null || !displayChannelThumbnail),
                                  child: YoutubeThumbnail(
                                    type: ThumbnailType.channel,
                                    key: Key("${channelThumbnailUrl}_$channelID"),
                                    isImportantInCache: false,
                                    customUrl: channelThumbnailUrl,
                                    width: channelThumbSize,
                                    isCircle: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            if (displaythirdLineText)
                              NamidaDummyContainer(
                                width: context.width * 0.2,
                                height: 8.0,
                                shimmerEnabled: shimmerEnabled && (thirdLineText == '' || !displaythirdLineText),
                                child: Expanded(
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    width: double.infinity,
                                    child: Text(
                                      thirdLineText,
                                      style: NText.small
                                          .of(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 11.0 * fontMultiplier,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            if (checkmarkStatus != null) ...[
                              const Spacer(),
                              NamidaCheckMark(size: 14.0, active: checkmarkStatus!),
                            ],
                          ],
                        ),
                      const SizedBox(height: 6.0),
                    ],
                  ),
                ),
                checkmarkStatus != null ? const SizedBox(width: 2.0) : const SizedBox(width: 6.0 + 12.0), // right + iconWidth
                const SizedBox(width: 8.0),
              ],
            ),
          ),
          if (bottomRightWidgets.isNotEmpty)
            Positioned(
              bottom: 6.0,
              right: 6.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: bottomRightWidgets,
              ),
            ),
          if (!shimmerEnabled && menuChildrenDefault != null)
            Positioned(
              top: 0.0,
              right: 0.0,
              child: NamidaPopupWrapper(
                childrenDefault: menuChildrenDefault,
                child: const MoreIcon(
                  iconSize: 16.0,
                  padding: 8.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class YoutubeCardMinimal extends StatelessWidget {
  final String? videoId;
  final String? thumbnailUrl;
  final void Function()? onTap;
  final double borderRadius;
  final bool shimmerEnabled;
  final String title;
  final String subtitle;
  final String thirdLineText;
  final String? channelThumbnailUrl;
  final String? channelID;
  final bool displayChannelThumbnail;
  final bool displaythirdLineText;
  final List<Widget> Function(double width, double height, NamidaColor? imageColors)? onTopWidgets;
  final String? smallBoxText;
  final double thumbnailWidthPercentage;
  final IconData? smallBoxIcon;
  final bool extractColor;
  final void Function(NamidaColor? color)? onColorReady;
  final FutureOr<List<NamidaPopupItem>> Function()? menuChildrenDefault;
  final bool isCircle;
  final List<Widget> bottomRightWidgets;
  final bool isImageImportantInCache;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final double fontMultiplier;
  final ThumbnailType thumbnailType;

  const YoutubeCardMinimal({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    this.onTap,
    this.borderRadius = 12.0,
    required this.shimmerEnabled,
    this.title = '',
    this.subtitle = '',
    required this.thirdLineText,
    this.channelThumbnailUrl,
    this.channelID,
    this.displayChannelThumbnail = true,
    this.displaythirdLineText = true,
    this.onTopWidgets,
    this.smallBoxText,
    this.thumbnailWidthPercentage = 1.0,
    this.smallBoxIcon,
    this.extractColor = false,
    this.onColorReady,
    this.menuChildrenDefault,
    this.isCircle = false,
    this.bottomRightWidgets = const [],
    required this.isImageImportantInCache,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.fontMultiplier = 1.0,
    required this.thumbnailType,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailHeight = this.thumbnailHeight ?? (thumbnailWidthPercentage * Dimensions.youtubeThumbnailHeight);
    final thumbnailWidth = this.thumbnailWidth ?? (isCircle ? thumbnailHeight : thumbnailHeight * 16 / 9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          NamidaInkWell(
            bgColor: NColors.card,
            borderRadius: borderRadius,
            onTap: onTap,
            width: thumbnailWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NamidaDummyContainer(
                  width: thumbnailWidth,
                  height: thumbnailHeight,
                  shimmerEnabled: shimmerEnabled,
                  child: YoutubeThumbnail(
                    key: Key("${videoId}_$thumbnailUrl"),
                    isImportantInCache: isImageImportantInCache,
                    videoId: videoId,
                    customUrl: thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    borderRadius: 10.0,
                    onTopWidgets: onTopWidgets == null ? null : (imageColors) => onTopWidgets!(thumbnailWidth, thumbnailHeight, imageColors),
                    smallBoxText: smallBoxText,
                    smallBoxIcon: smallBoxIcon,
                    extractColor: extractColor,
                    onColorReady: onColorReady,
                    isCircle: isCircle,
                    type: thumbnailType,
                  ),
                ),
                const SizedBox(height: 4.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NamidaDummyContainer(
                        width: context.width,
                        height: 10.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled && title == '',
                        child: Text(
                          title,
                          style: NText.medium.of(context).copyWith(fontSize: 13.0 * fontMultiplier),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      NamidaDummyContainer(
                        width: context.width,
                        height: 8.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled && subtitle == '',
                        child: Text(
                          subtitle,
                          style: NText.small
                              .of(context)
                              .copyWith(
                                fontWeight: FontWeight.w400,
                                fontSize: 13.0 * fontMultiplier,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
              ],
            ),
          ),
          if (bottomRightWidgets.isNotEmpty)
            Positioned(
              bottom: 6.0,
              right: 6.0 + 6 * 2 + 4.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: bottomRightWidgets,
              ),
            ),
          if (!shimmerEnabled && menuChildrenDefault != null)
            Positioned(
              bottom: 0.0,
              right: 0.0,
              child: NamidaPopupWrapper(
                childrenDefault: menuChildrenDefault,
                child: const MoreIcon(
                  iconSize: 14.0,
                  padding: 6.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YoutubeCardInkWell extends StatelessWidget {
  final bool? checkmarkStatus;
  final double borderRadius;
  final void Function()? onTap;
  final double height;
  final Widget child;

  const _YoutubeCardInkWell({
    required this.checkmarkStatus,
    required this.borderRadius,
    required this.onTap,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.targetOf(context);
    late final borderSide = BorderSide(
      width: 2.0,
      color: colors.secondary.withOpacityExt(0.5),
    );
    final decoration = checkmarkStatus == true
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            border: Border(
              left: borderSide,
              bottom: borderSide,
            ),
          )
        : null;
    return NamidaInkWell(
      animationDurationMS: checkmarkStatus != null ? 200 : 0,
      bgColor: NColors.card,
      borderRadius: borderRadius,
      onTap: onTap,
      height: height,
      decoration: decoration ?? const BoxDecoration(),
      child: child,
    );
  }
}
