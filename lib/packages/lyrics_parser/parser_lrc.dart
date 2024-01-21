import 'models.dart';

///normal lyric parser
class LRCParserLrc extends LyricsParse {
  RegExp pattern = RegExp(r"\[\d{2}:\d{2}.\d{2,3}]");

  ///匹配普通格式内容
  ///eg:[00:03.47] -> 00:03.47
  RegExp valuePattern = RegExp(r"\[(\d{2}:\d{2}.\d{2,3})\]");

  LRCParserLrc(String lyric) : super(lyric);

  @override
  List<LyricsLineModel> parseLines({bool isMain = true}) {
    //读每一行
    var lines = lyric.split("\n");
    if (lines.isEmpty) {
      return [];
    }
    List<LyricsLineModel> lineList = [];
    for (var line in lines) {
      //匹配time
      var time = pattern.stringMatch(line);
      if (time == null) {
        //没有匹配到直接返回
        continue;
      }
      //移除time，拿到真实歌词
      var realLyrics = line.replaceFirst(pattern, "");
      //转时间戳
      var ts = timeTagToTS(time);
      var lineModel = LyricsLineModel()..startTime = ts;
      if (realLyrics == "//") {
        realLyrics = "";
      }
      if (isMain) {
        lineModel.mainText = realLyrics;
      } else {
        lineModel.extText = realLyrics;
      }
      lineList.add(lineModel);
    }
    return lineList;
  }

  int? timeTagToTS(String timeTag) {
    if (timeTag.trim().isEmpty) {
      return null;
    }
    //通过正则取出value
    var value = valuePattern.firstMatch(timeTag)?.group(1) ?? "";
    if (value.isEmpty) {
      return null;
    }
    var timeArray = value.split(".");
    var padZero = 3 - timeArray.last.length;
    var millisecond = timeArray.last.padRight(padZero, "0");
    //避免出现奇葩
    if (millisecond.length > 3) {
      millisecond = millisecond.substring(0, 3);
    }
    var minAndSecArray = timeArray.first.split(":");
    return Duration(minutes: int.parse(minAndSecArray.first), seconds: int.parse(minAndSecArray.last), milliseconds: int.parse(millisecond)).inMilliseconds;
  }
}
