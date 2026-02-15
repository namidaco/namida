import 'package:flutter/material.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class IndexingPercentage extends _PercentageWithHeroWidget {
  const IndexingPercentage({super.key, super.size = 48.0, super.hero}) : super(defaultHeroTag: 'indexingper');

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => Indexer.inst.isIndexing.valueR
          ? NamidaCircularPercentage(
              hero: hero,
              heroTag: defaultHeroTag,
              percentage: Indexer.inst.tracksInfoList.valueR.length / Indexer.inst.allAudioFiles.valueR.length,
              size: size,
            ).animateEntrance(showWhen: Indexer.inst.isIndexing.valueR)
          : const SizedBox(),
    );
  }
}

class ParsingJsonPercentage extends _PercentageWithHeroWidget {
  final TrackSource? source;
  final bool forceDisplay;
  const ParsingJsonPercentage({super.key, super.size = 48.0, this.source, this.forceDisplay = true, super.hero}) : super(defaultHeroTag: 'parsingjsonper');

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => JsonToHistoryParser.inst.isParsing.valueR && (forceDisplay ? true : source == JsonToHistoryParser.inst.currentParsingSource.valueR)
          ? TapDetector(
              onTap: () => JsonToHistoryParser.inst.showParsingProgressDialog(),
              child: NamidaCircularPercentage(
                hero: hero,
                heroTag: defaultHeroTag,
                percentage: JsonToHistoryParser.inst.parsedHistoryJson.valueR / JsonToHistoryParser.inst.totalJsonToParse.valueR,
                size: size,
              ),
            )
          : const SizedBox(),
    );
  }
}

class VideosExtractingPercentage extends _PercentageWithHeroWidget {
  const VideosExtractingPercentage({super.key, super.size = 48.0, super.hero}) : super(defaultHeroTag: 'extractingvideosper');

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => VideoController.inst.videosCountExtractingTotal.valueR > 0
          ? NamidaCircularPercentage(
              hero: hero,
              heroTag: defaultHeroTag,
              percentage: VideoController.inst.videosCountExtractingProgress.valueR / VideoController.inst.videosCountExtractingTotal.valueR,
              size: size,
            )
          : const SizedBox(),
    );
  }
}

abstract class _PercentageWithHeroWidget extends StatelessWidget {
  final bool hero;
  final double size;
  final String defaultHeroTag;

  const _PercentageWithHeroWidget({
    super.key,
    this.hero = true,
    required this.size,
    required this.defaultHeroTag,
  });

  @override
  Widget build(BuildContext context);
}
