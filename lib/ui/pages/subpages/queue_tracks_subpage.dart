import 'package:flutter/material.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/route.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class QueueTracksPage extends StatelessWidget with NamidaRouteWidget {
  @override
  String? get name => queue.date.toString();

  @override
  RouteType get route => RouteType.SUBPAGE_queueTracks;

  final Queue queue;
  const QueueTracksPage({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NamidaTracksList(
        queueSource: QueueSource.queuePage,
        queueLength: queue.tracks.length,
        queue: queue.tracks,
        infoBox: (maxWidth) => SubpageInfoContainer(
          maxWidth: maxWidth,
          source: QueueSource.queuePage,
          title: queue.date.dateFormattedOriginal,
          subtitle: queue.date.clockFormatted,
          thirdLineText: [
            queue.tracks.displayTrackKeyword,
            queue.tracks.totalDurationFormatted,
          ].join(' - '),
          heroTag: 'queue_${queue.date}',
          imageBuilder: (size) => MultiArtworkContainer(
            size: size,
            heroTag: 'queue_${queue.date}',
            tracks: queue.tracks.toImageTracks(),
          ),
          tracksFn: () => queue.tracks,
        ),
      ),
    );
  }
}
