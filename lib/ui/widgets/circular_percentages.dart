import 'package:flutter/material.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class IndexingPercentage extends StatelessWidget {
  final double size;
  const IndexingPercentage({super.key, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Indexer.inst.isIndexing.valueR
          ? NamidaCircularPercentage(
              heroTag: 'indexingper',
              percentage: Indexer.inst.tracksInfoList.valueR.length / Indexer.inst.allAudioFiles.valueR.length,
              size: size,
            ).animateEntrance(showWhen: Indexer.inst.isIndexing.valueR)
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
      () => JsonToHistoryParser.inst.isParsing.valueR && (forceDisplay ? true : source == JsonToHistoryParser.inst.currentParsingSource.valueR)
          ? TapDetector(
              onTap: () => JsonToHistoryParser.inst.showParsingProgressDialog(),
              child: NamidaCircularPercentage(
                heroTag: 'parsingjsonper',
                percentage: JsonToHistoryParser.inst.parsedHistoryJson.valueR / JsonToHistoryParser.inst.totalJsonToParse.valueR,
                size: size,
              ),
            )
          : const SizedBox(),
    );
  }
}
