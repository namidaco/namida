import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class QueueInsertion {
  final int numberOfTracks;
  final bool insertNext;
  final InsertionSortingType sortBy;

  const QueueInsertion({
    required this.numberOfTracks,
    required this.insertNext,
    required this.sortBy,
  });

  factory QueueInsertion.fromJson(Map<String, dynamic> map) {
    return QueueInsertion(
      numberOfTracks: map["numberOfTracks"],
      insertNext: map["insertNext"],
      sortBy: InsertionSortingType.values.getEnum(map['sortBy']) ?? InsertionSortingType.random,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "numberOfTracks": numberOfTracks,
      "insertNext": insertNext,
      "sortBy": sortBy.convertToString,
    };
  }
}
