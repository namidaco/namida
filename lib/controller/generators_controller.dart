import 'package:namida/base/generator_base.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class NamidaGenerator extends NamidaGeneratorBase<TrackWithDate, Track> {
  static final NamidaGenerator inst = NamidaGenerator._internal();
  NamidaGenerator._internal() : super(HistoryController.inst);

  static Iterable<String> getHighMatcheFilesFromFilename(Iterable<String> files, String filePathToMatch) {
    int? latestPriority;
    bool requiresSorting = false;
    final matches = <(String, int)>[];

    void addMatch(String filePath, int priority) {
      matches.add((filePath, priority));
      if (requiresSorting == false) {
        if (priority != latestPriority) {
          if (latestPriority == null) {
            latestPriority = priority;
          } else {
            latestPriority = priority;
            requiresSorting = true;
          }
        }
      }
    }

    final filenameToMatch = filePathToMatch.getFilename;
    final filenameWOExtToMatch = filePathToMatch.getFilenameWOExt;
    final filenameToMatchCleaned = filenameToMatch.cleanUpForComparison;
    final l = Indexer.getTitleAndArtistFromFilename(filenameToMatch);
    final trackTitle = l.$1;
    final trackArtist = l.$2;

    for (final path in files) {
      final fileSystemFilename = path.getFilename;
      if (filenameToMatch == fileSystemFilename) {
        addMatch(path, 0);
        continue;
      }
      final fileSystemFilenameWOExt = path.getFilenameWOExt;
      if (filenameWOExtToMatch == fileSystemFilenameWOExt) {
        addMatch(path, 1);
        continue;
      }

      final fileSystemFilenameCleaned = fileSystemFilename.cleanUpForComparison;

      if (fileSystemFilenameCleaned.contains(filenameToMatchCleaned)) {
        addMatch(path, 2);
        continue;
      }
      if (fileSystemFilenameCleaned.contains(trackTitle.splitFirst('(')) && fileSystemFilenameCleaned.contains(trackArtist)) {
        addMatch(path, 3);
        continue;
      }
    }

    if (requiresSorting) {
      matches.sortBy((e) => e.$2); // lower priority means it should be first
    }

    return matches.map((e) => e.$1);
  }

  Iterable<Track> getRandomTracks({Track? exclude, int? min, int? max}) {
    return NamidaGeneratorBase.getRandomItems(allTracksInLibrary, exclude: exclude, min: min, max: max);
  }

  Iterable<Track> generateRecommendedSimilarDiscoverDate(Track track) {
    return super.generateRecommendedSimilarDiscoverDateFor(track, (current) => current.track);
  }

  Iterable<Track> generateRecommendedSimilarTimeRange(Track track) {
    return super.generateRecommendedSimilarTimeRangeFor(track, (current) => current.track);
  }

  Iterable<Track> generateRecommendedTrack(Track track) {
    return super.generateRecommendedItemsFor(track, (current) => current.track);
  }

  /// [daysRange] means taking n days before [yearTimeStamp] & n days after [yearTimeStamp].
  ///
  /// For best results, track should have the year tag in [yyyyMMdd] format (or any parsable format),
  /// Having a [yyyy] year tag will generate from the same year which is quite a wide range.
  List<Track> generateTracksFromSameEra(int yearTimeStamp, {int daysRange = 30, Track? currentTrack}) {
    final tracksAvailable = <Track>[];

    // -- [yyyy] year format.
    if (yearTimeStamp.toString().length == 4) {
      allTracksInLibrary.loop((e) {
        if (e.year != 0) {
          // -- if the track also has [yyyy]
          if (e.year.toString().length == 4) {
            if (e.year == yearTimeStamp) {
              tracksAvailable.add(e);
            }

            // -- if the track has parsable format
          } else {
            final dt = DateTime.tryParse(e.year.toString());
            if (dt != null && dt.year == yearTimeStamp) {
              tracksAvailable.add(e);
            }
          }
        }
      });

      // -- parsable year format.
    } else {
      final dateParsed = DateTime.tryParse(yearTimeStamp.toString());
      if (dateParsed == null) return [];

      allTracksInLibrary.loop((e) {
        if (e.year != 0) {
          final dt = DateTime.tryParse(e.year.toString());
          if (dt != null && (dt.difference(dateParsed).inDays).abs() <= daysRange) {
            tracksAvailable.add(e);
          }
        }
      });
    }
    tracksAvailable.remove(currentTrack);
    return tracksAvailable;
  }

  List<Track> generateTracksFromRatings(
    int minRating,
    int maxRating,
  ) {
    final finalTracks = <Track>[];
    Indexer.inst.trackStatsMap.value.forEach((key, value) {
      if (value.rating >= minRating && value.rating <= maxRating) {
        finalTracks.add(key);
      }
    });
    return finalTracks;
  }
}
