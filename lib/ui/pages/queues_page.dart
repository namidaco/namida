import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/queue_tile.dart';

class QueuesPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_queue;

  const QueuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NamidaScrollbarWithController(
        child: (sc) => AnimationLimiter(
          child: SmoothCustomScrollView(
            controller: sc,
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: Dimensions.tileBottomMargin6)),
              Obx(
                (context) {
                  final queuesKeys = QueueController.inst.queuesMap.valueR.keys.toFixedList();
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
                        allowTilting: true,
                        child: QueueTile(queue: q),
                      );
                    },
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Obx(
                  (context) {
                    final unloadedCount = QueueController.inst.totalQueuesCount.valueR - QueueController.inst.queuesMap.valueR.length;
                    return unloadedCount > 0 ? _LoadAllQueuesButton(unloadedCount: unloadedCount) : const SizedBox.shrink();
                  },
                ),
              ),
              kBottomPaddingWidgetSliver,
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadAllQueuesButton extends StatefulWidget {
  final int unloadedCount;

  const _LoadAllQueuesButton({required this.unloadedCount});

  @override
  State<_LoadAllQueuesButton> createState() => _LoadAllQueuesButtonState();
}

class _LoadAllQueuesButtonState extends State<_LoadAllQueuesButton> {
  bool _isLoading = false;

  void _onTap() async {
    setState(() => _isLoading = true);
    await QueueController.inst.loadAllQueues();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: NamidaButton(
        icon: Broken.arrow_down_2,
        text: "${lang.loadAll} (${widget.unloadedCount.formatDecimal()})",
        isLoading: _isLoading,
        onTap: _onTap,
      ),
    );
  }
}
