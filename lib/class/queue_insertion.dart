import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class QueueInsertion {
  final int numberOfTracks;
  final bool insertNext;
  final int? sample;
  final int? sampleDays;
  final InsertionSortingType sortBy;

  const QueueInsertion({
    required this.numberOfTracks,
    required this.insertNext,
    this.sample,
    this.sampleDays,
    required this.sortBy,
  });

  factory QueueInsertion.fromJson(Map<String, dynamic> map) {
    return QueueInsertion(
      numberOfTracks: map["numberOfTracks"],
      insertNext: map["insertNext"],
      sample: map["sample"],
      sampleDays: map["sampleDays"],
      sortBy: InsertionSortingType.values.getEnum(map['sortBy']) ?? InsertionSortingType.none,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "numberOfTracks": numberOfTracks,
      "insertNext": insertNext,
      if (sample != null) "sample": sample,
      if (sampleDays != null) "sampleDays": sampleDays,
      "sortBy": sortBy.name,
    };
  }
}
