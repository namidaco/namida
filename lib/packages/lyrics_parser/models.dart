/// all parsers extend this class
abstract class LyricsParse {
  String lyric;

  LyricsParse(this.lyric);

  /// call this method to parse
  List<LyricsLineModel> parseLines({bool isMain = true});

  /// verify [lyric] is matching
  bool isOK() => true;
}

class LyricsLineModel {
  String? mainText;
  String? extText;
  int? startTime;
  int? endTime;
  List<LyricSpanInfo>? spanList;

  Duration? get timeStamp => startTime == null ? null : Duration(milliseconds: startTime!);

  bool get hasExt => extText?.isNotEmpty == true;

  bool get hasMain => mainText?.isNotEmpty == true;

  List<LyricSpanInfo>? _defaultSpanList;

  get defaultSpanList => _defaultSpanList ??= [
        LyricSpanInfo()
          ..duration = (endTime ?? 0) - (startTime ?? 0)
          ..start = startTime ?? 0
          ..length = mainText?.length ?? 0
          ..raw = mainText ?? ""
      ];
}

class LyricSpanInfo {
  int index = 0;
  int length = 0;
  int duration = 0;
  int start = 0;
  String raw = "";

  double drawWidth = 0;
  double drawHeight = 0;

  int get end => start + duration;

  int get endIndex => index + length;
}
