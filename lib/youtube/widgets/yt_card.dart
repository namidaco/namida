import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
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
  final bool displayChannelThumbnail;
  final bool displaythirdLineText;
  final List<Widget> onTopWidgets;
  final String? smallBoxText;
  final bool? checkmarkStatus;
  final double thumbnailWidthPercentage;
  final IconData? smallBoxIcon;
  final bool extractColor;
  final List<Widget> menuChildren;
  final List<NamidaPopupItem> menuChildrenDefault;

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
    this.displayChannelThumbnail = true,
    this.displaythirdLineText = true,
    this.onTopWidgets = const <Widget>[],
    this.smallBoxText,
    this.checkmarkStatus,
    this.thumbnailWidthPercentage = 1.0,
    this.smallBoxIcon = Broken.play_cricle,
    this.extractColor = false,
    this.menuChildren = const [],
    this.menuChildrenDefault = const [],
  });

  @override
  Widget build(BuildContext context) {
    const verticalPadding = 8.0;
    final thumbnailWidth = thumbnailWidthPercentage * context.width * 0.36;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          NamidaInkWell(
            bgColor: context.theme.cardColor,
            borderRadius: 12.0,
            onTap: onTap,
            height: thumbnailHeight + verticalPadding,
            child: Row(
              children: [
                const SizedBox(width: 4.0),
                NamidaBasicShimmer(
                  width: thumbnailWidth,
                  height: thumbnailHeight,
                  shimmerEnabled: shimmerEnabled,
                  child: YoutubeThumbnail(
                    videoId: videoId,
                    channelUrl: thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    borderRadius: 10.0,
                    onTopWidgets: onTopWidgets,
                    smallBoxText: smallBoxText,
                    smallBoxIcon: smallBoxIcon,
                    extractColor: extractColor,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12.0),
                      NamidaBasicShimmer(
                        width: context.width,
                        height: 10.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled || title == '',
                        child: Text(
                          title,
                          style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0.multipliedFontScale),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      NamidaBasicShimmer(
                        width: context.width,
                        height: 8.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled || subtitle == '',
                        child: Text(
                          subtitle,
                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      const Spacer(),
                      if (displayChannelThumbnail || displaythirdLineText)
                        Row(
                          children: [
                            if (displayChannelThumbnail) ...[
                              NamidaBasicShimmer(
                                width: 20.0,
                                height: 20.0,
                                shimmerEnabled: channelThumbnailUrl == null || !displayChannelThumbnail,
                                child: YoutubeThumbnail(
                                  channelUrl: channelThumbnailUrl ?? '',
                                  width: 20.0,
                                  isCircle: true,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            NamidaBasicShimmer(
                              width: context.width * 0.2,
                              height: 8.0,
                              shimmerEnabled: thirdLineText == '' || !displaythirdLineText,
                              child: Text(
                                thirdLineText,
                                style: context.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11.0.multipliedFontScale,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (checkmarkStatus != null) ...[
                              const Spacer(),
                              NamidaCheckMark(size: 12.0, active: checkmarkStatus!),
                            ],
                          ],
                        ),
                      const SizedBox(height: 12.0),
                    ],
                  ),
                ),
                const SizedBox(width: 24.0),
              ],
            ),
          ),
          if (menuChildren.isNotEmpty || menuChildrenDefault.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: NamidaPopupWrapper(
                children: menuChildren,
                childrenDefault: menuChildrenDefault,
                child: const MoreIcon(iconSize: 16.0),
              ),
            ),
        ],
      ),
    );
  }
}
