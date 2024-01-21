import 'models.dart';
import 'parser_lrc.dart';
import 'parser_qrc.dart';

///smart parser
///Parser is automatically selected
class LRCParserSmart extends LyricsParse {
  LRCParserSmart(String lyric) : super(lyric);

  @override
  List<LyricsLineModel> parseLines({bool isMain = true}) {
    var qrc = LRCParserQrc(lyric);
    if (qrc.isOK()) {
      return qrc.parseLines(isMain: isMain);
    }
    return LRCParserLrc(lyric).parseLines(isMain: isMain);
  }
}
