import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import 'package:namida/controller/indexer_controller.dart';

class IndexingPercentage extends StatelessWidget {
  final double size;
  const IndexingPercentage({super.key, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final per = Indexer.inst.tracksInfoList.length / Indexer.inst.allTracksPaths.value;
        return Indexer.inst.isIndexing.value
            ? Hero(
                tag: 'indexingper',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SleekCircularSlider(
                      appearance: CircularSliderAppearance(
                        customWidths: CustomSliderWidths(
                          trackWidth: size / 24,
                          progressBarWidth: size / 12,
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
                        size: size,
                        spinnerMode: true,
                      ),
                    ),
                    if (per.isFinite)
                      Text(
                        "${(per * 100).toStringAsFixed(0)}%",
                        style: Get.textTheme.displaySmall?.copyWith(fontSize: size / 3.2),
                      )
                  ],
                ),
              )
            : const SizedBox();
      },
    );
  }
}
