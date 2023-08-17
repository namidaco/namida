class DateRange {
  final DateTime oldest;
  final DateTime newest;

  const DateRange({
    required this.oldest,
    required this.newest,
  });

  factory DateRange.fromJson(Map<String, dynamic> map) {
    return DateRange(
      oldest: DateTime.fromMicrosecondsSinceEpoch(map["oldest"] as int),
      newest: DateTime.fromMicrosecondsSinceEpoch(map["newest"] as int),
    );
  }
  factory DateRange.dummy() {
    return DateRange(
      oldest: DateTime(0),
      newest: DateTime(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "oldest": oldest.microsecondsSinceEpoch,
      "newest": newest.microsecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(other) {
    if (other is DateRange) {
      return oldest == other.oldest && newest == other.newest;
    }
    return false;
  }

  @override
  int get hashCode => "$oldest$newest".hashCode;
}
