import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:namida/controller/indexer_controller.dart';

class IndexingPercentage extends StatelessWidget {
  const IndexingPercentage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Indexer.inst.isIndexing.value
          ? Stack(
              alignment: Alignment.center,
              children: [
                SleekCircularSlider(
                  appearance: CircularSliderAppearance(
                    customWidths: CustomSliderWidths(
                      trackWidth: 2,
                      progressBarWidth: 4,
                    ),
                    customColors: CustomSliderColors(
                      dotColor: Colors.transparent,
                      trackColor: context.theme.cardTheme.color,
                      dynamicGradient: true,
                      progressBarColors: [
                        context.theme.colorScheme.onBackground,
                        Colors.transparent,
                        context.theme.colorScheme.secondary,
                        Colors.transparent,
                        context.theme.colorScheme.onBackground,
                      ],
                      hideShadow: true,
                    ),
                    size: 48.0,
                    spinnerMode: true,
                  ),
                ),
                Text(
                  "${(Indexer.inst.tracksInfoList.length / Indexer.inst.allTracksPaths.value * 100).toStringAsFixed(0)}%",
                  style: Get.textTheme.displaySmall,
                )
              ],
            )
          : const SizedBox(),
    );
  }
}
