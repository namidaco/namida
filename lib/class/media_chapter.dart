import 'package:namida/core/extensions.dart';

class MediaChapter {
  final int startMS;

  /// empty when the chapter has no title.
  final String title;

  const MediaChapter({
    required this.startMS,
    required this.title,
  });

  factory MediaChapter.fromJson(Map json) {
    return MediaChapter(
      startMS: json['s'] as int? ?? 0,
      title: json['t'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      's': startMS,
      if (title.isNotEmpty) 't': title,
    };
  }

  static List<MediaChapter>? listFromJson(dynamic json) {
    if (json is! List || json.isEmpty) return null;
    return json.map((e) => MediaChapter.fromJson(e as Map)).toFixedList();
  }
}
