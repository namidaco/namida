import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

class YTSubscribeButton extends StatelessWidget {
  final String? channelIDOrURL;
  const YTSubscribeButton({super.key, required this.channelIDOrURL});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final channelID = YoutubeSubscriptionsController.inst.idOrUrlToChannelID(channelIDOrURL);
        final disabled = channelID == null;
        final subscribed = YoutubeSubscriptionsController.inst.getChannel(channelID ?? '')?.subscribed ?? false;
        return AnimatedOpacity(
          opacity: disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Color.alphaBlend(Colors.grey.withOpacity(subscribed ? 0.6 : 0.0), context.theme.colorScheme.primary),
            ),
            child: Row(
              children: [
                Icon(subscribed ? Broken.tick_square : Broken.video, size: 20.0),
                const SizedBox(width: 8.0),
                Text(
                  subscribed ? lang.SUBSCRIBED : lang.SUBSCRIBE,
                ),
              ],
            ),
            onPressed: () async {
              if (channelIDOrURL != null) {
                await YoutubeSubscriptionsController.inst.changeChannelStatus(channelIDOrURL!);
              }
            },
          ),
        );
      },
    );
  }
}
