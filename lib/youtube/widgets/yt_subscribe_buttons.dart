import 'package:flutter/material.dart';

import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

class YTSubscribeButton extends StatelessWidget {
  final String? channelID;
  const YTSubscribeButton({super.key, required this.channelID});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: YoutubeSubscriptionsController.inst.availableChannels,
      builder: (availableChannels) {
        final disabled = channelID == null;
        final subscribed = availableChannels[channelID ?? '']?.subscribed ?? false;
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
                NamidaButtonText(
                  subscribed ? lang.SUBSCRIBED : lang.SUBSCRIBE,
                ),
              ],
            ),
            onPressed: () async {
              final chid = channelID;
              if (chid != null) {
                await YoutubeSubscriptionsController.inst.toggleChannelSubscription(chid);
              }
            },
          ),
        );
      },
    );
  }
}
