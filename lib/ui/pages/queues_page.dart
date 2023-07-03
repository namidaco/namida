import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/queue_controller.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/queue_tile.dart';

class QueuesPage extends StatelessWidget {
  const QueuesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          final queuesKeys = QueueController.inst.queuesMap.value.keys.toList();
          final queuesLength = QueueController.inst.queuesMap.value.length;
          return NamidaListView(
            itemBuilder: (context, i) {
              final reverseIndex = (queuesKeys.length - 1) - i;
              final q = QueueController.inst.queuesMap.value[queuesKeys[reverseIndex]]!;
              return AnimatingTile(
                key: ValueKey(i),
                position: i,
                child: QueueTile(
                  queue: q,
                ),
              );
            },
            itemCount: queuesLength,
            itemExtents: List.generate(queuesLength, (index) => 68.0 + 18.0),
          );
        },
      ),
    );
  }
}
