class YoutubeSubscription {
  final String title;
  final String channelID;
  final bool? subscribed;
  DateTime? lastFetched;

  YoutubeSubscription({
    String? title,
    required this.channelID,
    required this.subscribed,
    this.lastFetched,
  }) : title = title ?? '';

  factory YoutubeSubscription.fromJson(Map<String, dynamic> json) {
    return YoutubeSubscription(
      title: json['title'] ?? '',
      channelID: json['channelID'] ?? '',
      subscribed: json['subscribed'],
      lastFetched: DateTime.fromMillisecondsSinceEpoch(json['lastFetched'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "channelID": channelID,
      "subscribed": subscribed,
      "lastFetched": lastFetched?.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(other) {
    if (other is YoutubeSubscription) {
      return title == other.title && channelID == other.channelID && subscribed == other.subscribed && lastFetched == other.lastFetched;
    }
    return false;
  }

  @override
  int get hashCode => "${title}_${channelID}_${subscribed}_$lastFetched".hashCode;

  @override
  String toString() => "YoutubeSubscription(title: $title, channelID: $channelID, subscribed: $subscribed, lastFetched: $lastFetched)";
}
