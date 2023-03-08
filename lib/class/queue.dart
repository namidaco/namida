class Queue {
  late String name;
  late List<String> tracks;
  late int date;
  late String comment;
  late List<String> modes;

  Queue(
    this.name,
    this.tracks,
    this.date,
    this.comment,
    this.modes,
  );

  Queue.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    tracks = List<String>.from(json['tracks'] ?? []);
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    modes = List<String>.from(json['modes'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['name'] = name;
    data['tracks'] = tracks;
    data['date'] = date;
    data['comment'] = comment;
    data['modes'] = modes;

    return data;
  }
}
