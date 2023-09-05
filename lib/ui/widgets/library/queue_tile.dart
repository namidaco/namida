import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class QueueTile extends StatelessWidget {
  final Queue queue;
  const QueueTile({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    final hero = 'queue_${queue.date}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: Dimensions.tileBottomMargin6)),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(20),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        onTap: () => NamidaOnTaps.inst.onQueueTap(queue),
        onLongPress: () => NamidaDialogs.inst.showQueueDialog(queue.date),
        borderRadius: 16.0,
        child: SizedBox(
          height: Dimensions.queueTileItemExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
            child: Row(
              children: [
                SizedBox(
                  height: Dimensions.queueThumbnailSize,
                  child: MultiArtworkContainer(
                    heroTag: hero,
                    size: Dimensions.queueThumbnailSize,
                    paths: queue.tracks.toImagePaths(),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaHero(
                      tag: 'line1_$hero',
                      child: Text(
                        queue.date.dateAndClockFormattedOriginal,
                        style: context.textTheme.displayMedium?.copyWith(
                          fontSize: 14.0.multipliedFontScale,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 1.0),
                    NamidaHero(
                      tag: 'line2_$hero',
                      child: Text(
                        [queue.toText(), queue.tracks.displayTrackKeyword].join(' - '),
                        style: context.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  queue.tracks.totalDurationFormatted,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5.multipliedFontScale,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4.0),
                MoreIcon(
                  padding: 6.0,
                  onPressed: () => NamidaDialogs.inst.showQueueDialog(queue.date),
                ),
                const SizedBox(width: 8.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
