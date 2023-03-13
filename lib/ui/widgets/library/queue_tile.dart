import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class QueueTile extends StatelessWidget {
  final Queue queue;
  const QueueTile({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(20),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: context.theme.cardColor,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          onLongPress: () => NamidaDialogs.inst.showQueueDialog(queue),
          onTap: () => NamidaOnTaps.inst.onQueueTap(queue),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 3.0, bottom: 3.0, right: 8.0),
            height: 68.0 + 14.0,
            child: Row(
              children: [
                SizedBox(
                  height: 64.0,
                  child: MultiArtworkContainer(
                    heroTag: 'queue_artwork_${queue.date}',
                    size: 64.0,
                    tracks: queue.tracks,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        queue.date.dateFormatted,
                        queue.date.clockFormatted,
                      ].join(' - '),
                      style: Get.textTheme.displayMedium?.copyWith(
                        fontSize: 14.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1.0),
                    Text(
                      queue.tracks.displayTrackKeyword,
                      style: Get.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  queue.tracks.totalDurationFormatted,
                  style: Get.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4.0),
                MoreIcon(
                  padding: 6.0,
                  onPressed: () => NamidaDialogs.inst.showQueueDialog(queue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
