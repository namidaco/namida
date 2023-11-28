import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/queue_tile.dart';

class QueuesPage extends StatelessWidget {
  const QueuesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final sc = ScrollController();
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: CupertinoScrollbar(
          controller: sc,
          child: CustomScrollView(
            controller: sc,
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: Dimensions.tileBottomMargin6)),
              Obx(
                () {
                  final queuesKeys = QueueController.inst.queuesMap.value.keys.toList();
                  final queuesLength = queuesKeys.length;
                  return SliverFixedExtentList.builder(
                    itemCount: queuesLength,
                    itemExtent: Dimensions.queueTileItemExtent,
                    itemBuilder: (context, i) {
                      final reverseIndex = (queuesKeys.length - 1) - i;
                      final q = queuesKeys[reverseIndex].getQueue()!;
                      return AnimatingTile(
                        key: ValueKey(i),
                        position: i,
                        child: FadeDismissible(
                          key: Key("${i}_${q.date}"),
                          onDismissed: (onDismissed) {
                            final oldQueue = q;
                            QueueController.inst.removeQueue(oldQueue);
                            snackyy(
                              title: lang.UNDO_CHANGES,
                              message: lang.UNDO_CHANGES_DELETED_QUEUE,
                              displaySeconds: 3,
                              button: TextButton(
                                onPressed: () {
                                  QueueController.inst.reAddQueue(oldQueue);
                                  Get.closeAllSnackbars();
                                },
                                child: Text(lang.UNDO),
                              ),
                            );
                          },
                          child: QueueTile(queue: q),
                        ),
                      );
                    },
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
            ],
          ),
        ),
      ),
    );
  }
}
