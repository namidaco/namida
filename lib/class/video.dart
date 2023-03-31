import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// used for stats.
class YoutubeVideoHistory {
  late final String id;
  late final String title;
  late final String channel;
  late final String channelUrl;
  late final List<YTWatch> watches;

  YoutubeVideoHistory(
    this.id,
    this.title,
    this.channel,
    this.channelUrl,
    this.watches,
  );

  YoutubeVideoHistory.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? '';
    title = json['title'] ?? '';
    channel = json['channel'] ?? '';
    channelUrl = json['channelUrl'] ?? '';
    watches = List<YTWatch>.from((json['watches'] as List? ?? []).map((e) => YTWatch.fromJson(e)).toList());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['channel'] = channel;
    data['channelUrl'] = channelUrl;
    data['watches'] = watches;
    return data;
  }
}

class YTWatch {
  late final int date;
  late final bool isYTMusic;

  YTWatch(
    this.date,
    this.isYTMusic,
  );

  YTWatch.fromJson(Map<String, dynamic> json) {
    date = json['date'] ?? 0;
    isYTMusic = json['isYTMusic'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['date'] = date;
    data['isYTMusic'] = isYTMusic;
    return data;
  }
}

/// Video retrieved from Youtube Client.
class YTLVideo {
  late final Video video;
  late final Channel channel;

  YTLVideo(
    this.video,
    this.channel,
  );

  YTLVideo.fromJson(Map<String, dynamic> json) {
    video = (json['video'] as Map<String, dynamic>).videoFromJson();
    channel = (json['channel'] as Map<String, dynamic>).channelFromJson();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['video'] = video.toJson();
    data['channel'] = channel.toJson();

    return data;
  }
}

class NamidaCommentsList {
  List<Comment> comments = [];
  int totalLength = 0;

  NamidaCommentsList(
    this.comments,
    this.totalLength,
  );

  NamidaCommentsList.fromJson(Map<String, dynamic> json) {
    comments = List<Comment>.from((List<Map<String, dynamic>>.from((json['comments']))).map((e) => e.commentFromJson()).toList());
    totalLength = json['totalLength'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['comments'] = comments.map((c) => c.toJson()).toList();
    data['totalLength'] = totalLength;

    return data;
  }
}

/// JSON Extensions.
extension VideoUtilsToJson on Video {
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id.value;
    data['title'] = title;
    data['author'] = author;
    data['channelId'] = channelId.value;
    data['uploadDate'] = uploadDate?.millisecondsSinceEpoch ?? 0;
    data['uploadDateRaw'] = uploadDateRaw;
    data['publishDate'] = publishDate?.millisecondsSinceEpoch ?? 0;
    data['description'] = description;
    data['duration'] = duration?.inMilliseconds ?? 0;
    data['thumbnails'] = id.toString();
    data['keywords'] = keywords.map((e) => e).toList();
    data['engagement'] = engagement.toJson();
    data['isLive'] = isLive;

    return data;
  }
}

extension EngagementUtilsToJson on Engagement {
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['viewCount'] = viewCount;
    data['likeCount'] = likeCount;
    data['dislikeCount'] = dislikeCount;

    return data;
  }
}

extension ChannelUtilsToJson on Channel {
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id.value;
    data['title'] = title;
    data['logoUrl'] = logoUrl;
    data['bannerUrl'] = bannerUrl;
    data['subscribersCount'] = subscribersCount;

    return data;
  }
}

extension CommentUtilsToJson on Comment {
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['author'] = author;
    data['channelId'] = channelId.value;
    data['text'] = text;
    data['likeCount'] = likeCount;
    data['publishedTime'] = publishedTime;
    data['replyCount'] = replyCount;
    data['isHearted'] = isHearted;
    data['continuation'] = '';

    return data;
  }
}

extension VideoUtilsFromJson on Map<String, dynamic> {
  Video videoFromJson() {
    return Video(
      VideoId(this['id']),
      this['title'],
      this['author'],
      ChannelId(this['channelId']),
      DateTime.fromMillisecondsSinceEpoch(this['uploadDate']),
      this['uploadDateRaw'],
      DateTime.fromMillisecondsSinceEpoch(this['publishDate']),
      this['description'],
      Duration(milliseconds: this['duration']),
      ThumbnailSet(this['thumbnails']),
      List<String>.from(this['keywords']),
      (this['engagement'] as Map<String, dynamic>).engagementFromJson(),
      this['isLive'],
    );
  }

  Engagement engagementFromJson() {
    return Engagement(
      this['viewCount'],
      this['likeCount'],
      this['dislikeCount'],
    );
  }

  Channel channelFromJson() {
    return Channel(
      ChannelId(this['id']),
      this['title'],
      this['logoUrl'],
      this['bannerUrl'],
      this['subscribersCount'],
    );
  }

  Comment commentFromJson() {
    return Comment(
      this['author'],
      ChannelId(this['channelId']),
      this['text'],
      this['likeCount'],
      this['publishedTime'],
      this['replyCount'],
      this['isHearted'],
      this['continuation'],
    );
  }
}
