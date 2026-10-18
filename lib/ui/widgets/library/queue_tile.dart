import 'package:flutter/material.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class QueueTile extends StatelessWidget {
  final Queue queue;
  const QueueTile({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    final hero = 'queue_${queue.date}';
    const absorberHeight = Dimensions.queueTileItemExtent * 0.2;
    final absorberWidget = ColoredBox(
      color: Colors.transparent,
      child: SizedBox(
        height: absorberHeight,
        width: context.width,
      ),
    );
    final sourceText = queue.toSourceText();
    return NContainer(
      margin: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: Dimensions.tileBottomMargin6)),
      decoration: (colors) => BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacityExt(0.08),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          FadeDismissible(
            direction: DismissDirection.endToStart,
            key: Key("${queue.date}"),
            onDismissed: (direction) {
              final oldQueue = queue;
              QueueController.inst.removeQueue(oldQueue);
              snackyy(
                title: lang.undoChanges,
                message: lang.undoChangesDeletedQueue,
                displayDuration: SnackDisplayDuration.long,
                button: SnackbarButton(
                  text: lang.undo,
                  function: () async => await QueueController.inst.reAddQueue(oldQueue),
                ),
              );
            },
            child: NamidaInkWell(
              bgColor: NColors.card,
              onTap: () => NamidaOnTaps.inst.onQueueTap(queue),
              onLongPress: () => NamidaDialogs.inst.showQueueDialog(queue.date),
              enableSecondaryTap: true,
              borderRadius: 16.0,
              height: Dimensions.queueTileItemExtent,
              padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
              child: Row(
                children: [
                  SizedBox(
                    height: Dimensions.queueThumbnailSize,
                    child: MultiArtworkContainer(
                      heroTag: hero,
                      size: Dimensions.queueThumbnailSize,
                      tracks: queue.tracks.toImageTracks(),
                      reduceQuality: true,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NamidaHero(
                          tag: 'line1_$hero',
                          child: NamidaText(
                            [
                              queue.source.toText(),
                              ?sourceText,
                            ].joinText(separator: ' - '),
                            style: const NText(.medium, size: .s14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 1.0),
                        NamidaHero(
                          tag: 'line2_$hero',
                          child: NamidaText(
                            [
                              queue.tracks.displayTrackKeyword,
                              queue.tracks.totalDurationFormatted,
                            ].joinText(separator: ' - '),
                            style: const NText(.small, weight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        NamidaHero(
                          tag: 'line3_$hero',
                          child: NamidaText(
                            queue.date.dateAndClockFormattedOriginal,
                            style: const NText(.small, weight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  NamidaText(
                    TimeAgoController.dateMSSEFromNow(queue.date),
                    style: const NText(.small, size: .s11p5, weight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4.0),
                  queue.tracks.isEmpty
                      ? NamidaIconButton(
                          icon: Broken.trash,
                          iconSize: 18.0,
                          onPressed: () => NamidaOnTaps.inst.onQueueDelete(queue),
                        )
                      : MoreIcon(
                          padding: 6.0,
                          iconSize: 18.0,
                          onPressed: () => NamidaDialogs.inst.showQueueDialog(queue.date),
                        ),
                  const SizedBox(width: 8.0),
                ],
              ),
            ),
          ),
          Positioned(top: 0, child: absorberWidget),
          Positioned(bottom: 0, child: absorberWidget),
        ],
      ),
    );
  }
}
