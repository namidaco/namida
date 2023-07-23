import 'package:namida/core/extensions.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// used for stats.
class YoutubeVideoHistory {
  final String id;
  final String title;
  final String channel;
  final String channelUrl;
  final List<YTWatch> watches;

  const YoutubeVideoHistory({
    required this.id,
    required this.title,
    required this.channel,
    required this.channelUrl,
    required this.watches,
  });

  factory YoutubeVideoHistory.fromJson(Map<String, dynamic> json) {
    return YoutubeVideoHistory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      channel: json['channel'] ?? '',
      channelUrl: json['channelUrl'] ?? '',
      watches: List<YTWatch>.from((json['watches'] as List? ?? []).map((e) => YTWatch.fromJson(e))),
    );
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
  final int date;
  final bool isYTMusic;

  const YTWatch({
    required this.date,
    required this.isYTMusic,
  });

  factory YTWatch.fromJson(Map<String, dynamic> json) {
    return YTWatch(
      date: json['date'] ?? 0,
      isYTMusic: json['isYTMusic'] ?? false,
    );
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
  final Video video;
  final Channel channel;

  const YTLVideo({
    required this.video,
    required this.channel,
  });

  factory YTLVideo.fromJson(Map<String, dynamic> json) {
    return YTLVideo(
      video: (json['video'] as Map<String, dynamic>).videoFromJson(),
      channel: (json['channel'] as Map<String, dynamic>).channelFromJson(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['video'] = video.toJson();
    data['channel'] = channel.toJson();

    return data;
  }
}

class NamidaCommentsList {
  final List<Comment> comments;
  final int totalLength;

  const NamidaCommentsList({
    this.comments = const <Comment>[],
    this.totalLength = 0,
  });

  factory NamidaCommentsList.fromJson(Map<String, dynamic> json) {
    return NamidaCommentsList(
      comments: List<Comment>.from((List<Map<String, dynamic>>.from((json['comments']))).map((e) => e.commentFromJson())),
      totalLength: json['totalLength'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['comments'] = comments.mapped((c) => c.toJson());
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
    data['keywords'] = keywords.mapped((e) => e);
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
