import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/queue_tile.dart';

class QueuesPage extends StatelessWidget {
  const QueuesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: NamidaScrollbarWithController(
          child: (sc) => CustomScrollView(
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
                        child: QueueTile(queue: q),
                      );
                    },
                  );
                },
              ),
              kBottomPaddingWidgetSliver,
            ],
          ),
        ),
      ),
    );
  }
}
