import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/controller/indexer_controller.dart';

class IndexingPercentage extends StatelessWidget {
  final double size;
  const IndexingPercentage({super.key, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Indexer.inst.isIndexing.value
          ? Hero(
              tag: 'indexingper',
              child: NamidaCircularPercentage(
                percentage: Indexer.inst.tracksInfoList.length / Indexer.inst.allTracksPaths.value,
                size: size,
              ),
            )
          : const SizedBox(),
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
          ? GestureDetector(
              onTap: () => JsonToHistoryParser.inst.showParsingProgressDialog(),
              child: Hero(
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
