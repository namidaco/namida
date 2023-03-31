import 'package:flutter/cupertino.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class QueueTracksPage extends StatelessWidget {
  final Queue queue;
  QueueTracksPage({super.key, required this.queue});

  final ScrollController _scrollController = ScrollController();
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
      child: AnimationLimiter(
        child: CupertinoScrollbar(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            children: [
              /// Top Container holding image and info and buttons
              SubpagesTopContainer(
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

              /// tracks
              ...queue.tracks
                  .asMap()
                  .entries
                  .map(
                    (track) => AnimatingTile(
                      position: track.key,
                      child: TrackTile(
                        index: track.key,
                        track: track.value,
                        queue: queue.tracks,
                        canHaveDuplicates: true,
                      ),
                    ),
                  )
                  .toList(),
              kBottomPaddingWidget,
            ],
          ),
        ),
      ),
    );
  }
}
