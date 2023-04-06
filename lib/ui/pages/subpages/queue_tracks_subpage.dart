import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class QueueTracksPage extends StatelessWidget {
  final Queue queue;
  const QueueTracksPage({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return MainPageWrapper(
      actionsToAdd: [
        NamidaIconButton(
          icon: Broken.more_2,
          padding: const EdgeInsets.only(right: 14, left: 4.0),
          onPressed: () => NamidaDialogs.inst.showQueueDialog(queue),
        )
      ],
      child: NamidaTracksList(
        queueLength: queue.tracks.length,
        queue: queue.tracks,
        header: SubpagesTopContainer(
          title: queue.date.dateFormattedOriginal,
          subtitle: queue.date.clockFormatted,
          thirdLineText: [
            queue.tracks.displayTrackKeyword,
            queue.tracks.totalDurationFormatted,
          ].join(' - '),
          imageWidget: MultiArtworkContainer(
            size: Get.width * 0.35,
            heroTag: 'queue_artwork_${queue.date}',
            tracks: queue.tracks,
          ),
          tracks: queue.tracks,
        ),
      ),
    );
  }
}
