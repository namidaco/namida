import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class YoutubePage extends StatelessWidget {
  const YoutubePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedTheme(
        duration: const Duration(milliseconds: 400),
        data: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, !context.isDarkMode),
        child: Scaffold(
          backgroundColor: context.theme.scaffoldBackgroundColor,
          appBar: AppBar(
            leading: NamidaIconButton(
              icon: Broken.arrow_left_2,
              onPressed: () => Get.back(),
            ),
            title: Text(Language.inst.YOUTUBE),
          ),
          body: Obx(
            () {
              final searchList = YoutubeController.inst.currentSearchList.value;
              return searchList == null
                  ? const ShimmerScreen()
                  : ListView(
                      children: searchList.asMap().entries.map((v) {
                        final searchChannel = YoutubeController.inst.searchChannels.firstWhereOrNull((element) => element.id.value == v.value.channelId.value);
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          // height: context.width * 0.32,
                          decoration: BoxDecoration(
                            color: context.theme.cardColor,
                            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(4.0).add(const EdgeInsets.symmetric(horizontal: 2.0)),
                                child: Row(
                                  children: [
                                    YoutubeThumbnail(
                                      url: v.value.thumbnails.mediumResUrl,
                                      width: context.width * 0.36,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          /// First Line

                                          const SizedBox(height: 2.0),
                                          Text(
                                            v.value.title,
                                            style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                          /// Second Line
                                          const SizedBox(height: 2.0),
                                          Text(
                                            [
                                              v.value.engagement.viewCount.formatDecimal(),
                                              if (v.value.uploadDate != null) '${timeago.format(v.value.uploadDate!, locale: 'en_short')} ${Language.inst.AGO}'
                                            ].join(' - '),
                                            style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                          /// Third Line
                                          const SizedBox(height: 4.0),
                                          Row(
                                            children: [
                                              YoutubeThumbnail(
                                                url: searchChannel?.logoUrl ?? '',
                                                width: 22.0,
                                                isCircle: true,
                                                errorWidget: (context, url, error) => ArtworkWidget(
                                                  thumnailSize: 22.0,
                                                  forceDummyArtwork: true,
                                                  borderRadius: 124.0.multipliedRadius,
                                                ),
                                              ),
                                              const SizedBox(width: 6.0),
                                              Text(
                                                searchChannel?.title ?? '',
                                                style: context.textTheme.displaySmall?.copyWith(
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 11.0,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6.0),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
            },
          ),
        ),
      ),
    );
  }
}
