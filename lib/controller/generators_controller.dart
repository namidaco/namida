import 'package:history_manager/history_manager.dart';

import 'package:namida/base/generator_base.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class NamidaGenerator extends NamidaGeneratorBase<TrackWithDate, Track> {
  static final NamidaGenerator inst = NamidaGenerator._internal();
  NamidaGenerator._internal();

  @override
  HistoryManager<TrackWithDate, Track> get historyController => HistoryController.inst;

  Set<String> getHighMatcheFilesFromFilename(Iterable<String> files, String filename) {
    return files.where(
      (element) {
        final trackFilename = filename;
        final fileSystemFilenameCleaned = element.getFilename.cleanUpForComparison;
        final l = Indexer.getTitleAndArtistFromFilename(trackFilename);
        final trackTitle = l.$1;
        final trackArtist = l.$2;
        final matching1 = fileSystemFilenameCleaned.contains(trackFilename.cleanUpForComparison);
        final matching2 = fileSystemFilenameCleaned.contains(trackTitle.split('(').first) && fileSystemFilenameCleaned.contains(trackArtist);
        return matching1 || matching2;
      },
    ).toSet();
  }

  Iterable<Track> getRandomTracks({Track? exclude, int? min, int? max}) {
    return NamidaGeneratorBase.getRandomItems(allTracksInLibrary, exclude: exclude, min: min, max: max);
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
      allTracksInLibrary.loop((e, index) {
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

      allTracksInLibrary.loop((e, index) {
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
    Indexer.inst.trackStatsMap.forEach((key, value) {
      if (value.rating >= minRating && value.rating <= maxRating) {
        finalTracks.add(key);
      }
    });
    return finalTracks;
  }
}
