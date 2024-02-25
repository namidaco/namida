import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/controller/indexer_controller.dart';

class IndexingPercentage extends StatelessWidget {
  final double size;
  const IndexingPercentage({super.key, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => NamidaHero(
        tag: 'indexingper',
        child: NamidaCircularPercentage(
          percentage: Indexer.inst.tracksInfoList.length / Indexer.inst.allAudioFiles.length,
          size: size,
        ).animateEntrance(showWhen: Indexer.inst.isIndexing.value),
      ),
    );
  }
}

class ParsingJsonPercentage extends StatelessWidget {
  final double size;
  final TrackSource source;
  final bool forceDisplay;
  const ParsingJsonPercentage({super.key, this.size = 48.0, this.source = TrackSource.local, this.forceDisplay = true});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => JsonToHistoryParser.inst.isParsing.value && (forceDisplay ? true : source == JsonToHistoryParser.inst.currentParsingSource.value)
          ? TapDetector(
              onTap: () => JsonToHistoryParser.inst.showParsingProgressDialog(),
              child: NamidaHero(
                tag: 'parsingjsonper',
                child: NamidaCircularPercentage(
                  percentage: JsonToHistoryParser.inst.parsedHistoryJson.value / JsonToHistoryParser.inst.totalJsonToParse.value,
                  size: size,
                ),
              ),
            )
          : const SizedBox(),
    );
  }
}
