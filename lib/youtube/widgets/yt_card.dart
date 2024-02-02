import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/extensions.dart';
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
  final List<Widget> onTopWidgets;
  final String? smallBoxText;
  final bool? checkmarkStatus;
  final double thumbnailWidthPercentage;
  final IconData? smallBoxIcon;
  final bool extractColor;
  final List<Widget> Function()? menuChildren;
  final List<NamidaPopupItem> Function()? menuChildrenDefault;
  final bool isCircle;
  final List<Widget> bottomRightWidgets;
  final bool isImageImportantInCache;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final double fontMultiplier;
  final bool isPlaylist;

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
    this.onTopWidgets = const <Widget>[],
    this.smallBoxText,
    this.checkmarkStatus,
    this.thumbnailWidthPercentage = 1.0,
    this.smallBoxIcon,
    this.extractColor = false,
    this.menuChildren,
    this.menuChildrenDefault,
    this.isCircle = false,
    this.bottomRightWidgets = const [],
    required this.isImageImportantInCache,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.fontMultiplier = 1.0,
    this.isPlaylist = false,
  });

  @override
  Widget build(BuildContext context) {
    const verticalPadding = 8.0;
    final thumbnailWidth = this.thumbnailWidth ?? (thumbnailWidthPercentage * context.width * 0.36);
    final thumbnailHeight = this.thumbnailHeight ?? (isCircle ? thumbnailWidth : thumbnailWidth * 9 / 16);

    final channelThumbSize = 20.0 * thumbnailWidthPercentage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          NamidaInkWell(
            bgColor: context.theme.cardColor,
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
                    channelUrl: thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    borderRadius: 10.0,
                    onTopWidgets: onTopWidgets,
                    smallBoxText: smallBoxText,
                    smallBoxIcon: smallBoxIcon,
                    extractColor: extractColor,
                    isCircle: isCircle,
                    isPlaylist: isPlaylist,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
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
                          style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0.multipliedFontScale * fontMultiplier),
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
                          style: context.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w400,
                            fontSize: 13.0.multipliedFontScale * fontMultiplier,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      const Spacer(),
                      if (displayChannelThumbnail || displaythirdLineText || checkmarkStatus != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (displayChannelThumbnail) ...[
                              NamidaDummyContainer(
                                width: channelThumbSize,
                                height: channelThumbSize,
                                shimmerEnabled: shimmerEnabled && (channelThumbnailUrl == null || !displayChannelThumbnail),
                                child: YoutubeThumbnail(
                                  key: Key("${channelThumbnailUrl}_$channelID"),
                                  isImportantInCache: false,
                                  channelUrl: channelThumbnailUrl ?? '',
                                  channelIDForHQImage: channelThumbnailUrl == null ? (channelID ?? '') : '',
                                  width: channelThumbSize,
                                  isCircle: true,
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
                                      style: context.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 11.0.multipliedFontScale * fontMultiplier,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            if (checkmarkStatus != null) ...[
                              const Spacer(),
                              NamidaCheckMark(size: 12.0, active: checkmarkStatus!),
                            ],
                          ],
                        ),
                      const SizedBox(height: 6.0),
                    ],
                  ),
                ),
                const SizedBox(width: 6.0 + 12.0), // right + iconWidth
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
          if (!shimmerEnabled && ((menuChildren?.call().isNotEmpty ?? false) || (menuChildrenDefault?.call().isNotEmpty ?? false)))
            Positioned(
              top: 0.0,
              right: 0.0,
              child: NamidaPopupWrapper(
                children: menuChildren,
                childrenDefault: menuChildrenDefault,
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: MoreIcon(iconSize: 16.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
