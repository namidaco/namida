import 'package:flutter/cupertino.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/queue_tile.dart';

class QueuesPage extends StatelessWidget {
  QueuesPage({super.key});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return MainPageWrapper(
      title: Text(Language.inst.QUEUES),
      child: AnimationLimiter(
        child: CupertinoScrollbar(
          controller: _scrollController,
          child: Obx(
            () => ListView(
              children: [
                const SizedBox(height: 12.0),
                ...QueueController.inst.queueList
                    .asMap()
                    .entries
                    .map((e) => AnimatingTile(
                          position: e.key,
                          child: QueueTile(
                            queue: e.value,
                          ),
                        ))
                    .toList(),
                kBottomPaddingWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
