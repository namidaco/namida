// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/search_matcher.dart';
import 'package:namida/core/enums.dart';

void main() {
  final sep = Platform.pathSeparator;
  final musicDir = '${sep}storage${sep}Music';
  final videosDir = '${sep}storage${sep}Videos';
  String videoPath(String filename, {String? dirPath}) => '${dirPath ?? videosDir}$sep$filename';

  Set<String> match(
    List<String> videos, {
    String filenameWOExt = '',
    String title = '',
    String? artist,
    String? genre,
    String ytID = '',
    LocalVideoMatchingType matchingType = LocalVideoMatchingType.auto,
    String? onlyInDirectory,
  }) {
    return FilePathMatcher.init(videos).matchTrackVideos(
      filenameWOExt: filenameWOExt,
      title: title,
      artist: artist,
      genre: genre,
      ytID: ytID,
      matchingType: matchingType,
      onlyInDirectory: onlyInDirectory,
    );
  }

  group('youtube id', () {
    test('yt-dlp names are matched by the id in brackets', () {
      final video = videoPath('Never Gonna Give You Up [dQw4w9WgXcQ].mp4');
      expect(match([video], ytID: 'dQw4w9WgXcQ', matchingType: LocalVideoMatchingType.youtubeID), {video});
    });

    test('v= names, old youtube-dl title-id names and bare ids are matched too', () {
      final legacy = videoPath('Never Gonna v=dQw4w9WgXcQ.mp4');
      final youtubeDL = videoPath('Never_Gonna_Give_You_Up-dQw4w9WgXcQ.mkv');
      final bare = videoPath('dQw4w9WgXcQ.webm');
      final other = videoPath('Never Gonna [lYBUbBu4W08].mp4');
      expect(match([legacy, youtubeDL, bare, other], ytID: 'dQw4w9WgXcQ', matchingType: LocalVideoMatchingType.youtubeID), {legacy, youtubeDL, bare});
    });

    test('ids with dashes and underscores are matched', () {
      final video = videoPath('Song [-_aB3-dE_9k].mp4');
      expect(match([video], ytID: '-_aB3-dE_9k', matchingType: LocalVideoMatchingType.youtubeID), {video});
    });

    test('an id is found even when an earlier candidate overlaps it', () {
      final video = videoPath('Cruel Summer-dQw4_9WgXcQ.mp4');
      expect(match([video], ytID: 'dQw4_9WgXcQ', matchingType: LocalVideoMatchingType.youtubeID), {video});
    });

    test('an id glued to other letters is not one', () {
      final video = videoPath('XdQw4w9WgXcQ.mp4');
      expect(match([video], ytID: 'dQw4w9WgXcQ', matchingType: LocalVideoMatchingType.youtubeID), isEmpty);
    });

    test('a track without an 11 character id never matches by id', () {
      final videos = [videoPath('Masterpiece.mp4'), videoPath('Song [dQw4w9WgXcQ].mp4')];
      expect(match(videos, matchingType: LocalVideoMatchingType.youtubeID), isEmpty);
      expect(match(videos, ytID: 'dQw4w9WgXc', matchingType: LocalVideoMatchingType.youtubeID), isEmpty);
    });
  });

  group('title and artist', () {
    test('underscores, dots and dashes separate words', () {
      final underscored = videoPath('Artist_-_Title_(Official).mp4');
      final dotted = videoPath('Artist.Title.1080p.mkv');
      expect(match([underscored, dotted], title: 'Title', artist: 'Artist', matchingType: LocalVideoMatchingType.titleAndArtist), {underscored, dotted});
    });

    test('tags glued to the title still match', () {
      final video = videoPath('Artist - Title[MV].mp4');
      expect(match([video], title: 'Title', artist: 'Artist', matchingType: LocalVideoMatchingType.titleAndArtist), {video});
    });

    test('both the title and the artist have to be in the name', () {
      final videos = [videoPath('Title.mp4'), videoPath('Artist - Other.mp4')];
      expect(match(videos, title: 'Title', artist: 'Artist', matchingType: LocalVideoMatchingType.titleAndArtist), isEmpty);
    });

    test('whole words only, a title inside a longer word is not a match', () {
      final video = videoPath('Artist - Homeless.mp4');
      expect(match([video], title: 'Home', artist: 'Artist', matchingType: LocalVideoMatchingType.titleAndArtist), isEmpty);
    });

    test('empty artist and genre match nothing', () {
      final video = videoPath('Artist - Title.mp4');
      expect(match([video], title: 'Title', artist: '', genre: '', matchingType: LocalVideoMatchingType.titleAndArtist), isEmpty);
      expect(match([video], title: 'Title', matchingType: LocalVideoMatchingType.titleAndArtist), isEmpty);
    });

    test('the first genre can stand in for the artist, like nightcore', () {
      final video = videoPath('Nightcore - Title.mp4');
      expect(match([video], title: 'Title', artist: 'Someone', genre: 'Nightcore', matchingType: LocalVideoMatchingType.titleAndArtist), {video});
    });

    test('cjk titles without spaces match', () {
      final video = videoPath('YOASOBI「夜に駆ける」Official Music Video.mp4');
      final other = videoPath('YOASOBI「群像」.mp4');
      expect(match([video, other], title: '夜に駆ける', artist: 'YOASOBI', matchingType: LocalVideoMatchingType.titleAndArtist), {video});
      expect(match([video, other], title: '群青', artist: 'YOASOBI', matchingType: LocalVideoMatchingType.titleAndArtist), isEmpty);
    });
  });

  group('filename', () {
    test('every word of the audio filename has to be in the video name', () {
      final full = videoPath('Artist - Title (Official Video).mp4');
      final partial = videoPath('Artist - Other.mp4');
      expect(match([full, partial], filenameWOExt: 'Artist - Title', matchingType: LocalVideoMatchingType.filename), {full});
    });

    test('parts split by symbols can come in any order', () {
      final reordered = videoPath('Title (Official Video) - Artist.mp4');
      final underscored = videoPath('Title_Artist_480p.mkv');
      expect(match([reordered, underscored], filenameWOExt: 'Artist - Title', matchingType: LocalVideoMatchingType.filename), {reordered, underscored});
    });

    test('words inside a part have to stay next to each other', () {
      final swapped = videoPath('Walker Alan - Faded.mp4');
      final split = videoPath('Alan Someone Walker - Faded.mp4');
      final kept = videoPath('Faded - Alan Walker (480p).mp4');
      expect(match([swapped, split, kept], filenameWOExt: 'Alan Walker - Faded', matchingType: LocalVideoMatchingType.filename), {kept});
    });

    test('a part can not reuse the words of another part (#1375)', () {
      final concert = videoPath('Black Tabby In Concert - Slay the Princess Three Year Anniversary Performance - 006 A World Without You There to Guide It [Axua30Da].m4a');
      final same = videoPath('The Princess - Slay the Princess.mp4');
      final reordered = videoPath('Slay the Princess - The Princess (480p).mp4');
      final videos = [concert, same, reordered];
      expect(match(videos, filenameWOExt: 'The Princess - Slay the Princess', matchingType: LocalVideoMatchingType.filename), {same, reordered});
      expect(match(videos, filenameWOExt: 'The Princess - Slay the Princess', title: 'The Princess', artist: 'Slay the Princess'), {same, reordered});
    });

    test('a repeated part needs its own place in the name', () {
      final once = videoPath('Princess.mp4');
      final twice = videoPath('Princess - Princess (Live).mp4');
      expect(match([once, twice], filenameWOExt: 'Princess - Princess', matchingType: LocalVideoMatchingType.filename), {twice});
    });

    test('cjk parts match inside longer cjk runs', () {
      final video = videoPath('YOASOBI「夜に駆ける」Official Music Video.mp4');
      expect(match([video], filenameWOExt: '駆ける', matchingType: LocalVideoMatchingType.filename), {video});
      expect(match([video], filenameWOExt: 'YOASOBI - 夜に駆ける', matchingType: LocalVideoMatchingType.filename), {video});
    });
  });

  group('sure track video', () {
    bool isSure(String videoFilename, String trackFilenameWOExt, {String trackYTID = ''}) {
      final videoPaths = [videoPath(videoFilename)];
      final sureVideos = FilePathMatcher.getSureTrackVideos(videoPaths: videoPaths, trackFilenameWOExt: trackFilenameWOExt, trackYTID: trackYTID);
      return sureVideos.isNotEmpty;
    }

    test('the same name is sure, symbols and case aside', () {
      expect(isSure('Alan Walker - Faded.mp4', 'Alan Walker - Faded'), isTrue);
      expect(isSure('alan walker – faded.webm', 'Alan Walker - Faded'), isTrue);
    });

    test('trailing bracket parts are allowed', () {
      expect(isSure('Alan Walker - Faded (480p).mp4', 'Alan Walker - Faded'), isTrue);
      expect(isSure('Alan Walker - Faded (Official Video) [1080p].mp4', 'Alan Walker - Faded'), isTrue);
      expect(isSure('Song (Remix) (480p).mp4', 'Song (Remix)'), isTrue);
    });

    test('other words or other brackets are not sure', () {
      expect(isSure('Alan Walker - Faded Extended.mp4', 'Alan Walker - Faded'), isFalse);
      expect(isSure('Song (Live).mp4', 'Song (Remix)'), isFalse);
      expect(isSure('Faded - Alan Walker.mp4', 'Alan Walker - Faded'), isFalse);
    });

    test('the track youtube id in the name is sure', () {
      expect(isSure('Something Else [dQw4w9WgXcQ].mp4', 'Never Gonna Give You Up', trackYTID: 'dQw4w9WgXcQ'), isTrue);
      expect(isSure('Something Else [lYBUbBu4W08].mp4', 'Never Gonna Give You Up', trackYTID: 'dQw4w9WgXcQ'), isFalse);
    });
  });

  test('checking the same folder keeps only videos next to the track', () {
    final nearby = videoPath('Artist - Title.mp4', dirPath: musicDir);
    final elsewhere = videoPath('Artist - Title.mp4');
    final videos = [nearby, elsewhere];
    expect(match(videos, filenameWOExt: 'Artist - Title', matchingType: LocalVideoMatchingType.filename), {nearby, elsewhere});
    expect(match(videos, filenameWOExt: 'Artist - Title', matchingType: LocalVideoMatchingType.filename, onlyInDirectory: musicDir), {nearby});
  });

  test('auto mode is the union of filename, title and artist, and id matches', () {
    final byFilename = videoPath('01 Track Name.mp4');
    final byTitle = videoPath('Artist - Title (Live).mp4');
    final byID = videoPath('Something [dQw4w9WgXcQ].mp4');
    final unrelated = videoPath('Unrelated.mp4');
    final videos = [byFilename, byTitle, byID, unrelated];
    final matched = match(videos, filenameWOExt: '01 Track Name', title: 'Title', artist: 'Artist', ytID: 'dQw4w9WgXcQ');
    expect(matched, {byFilename, byTitle, byID});
  });
}
