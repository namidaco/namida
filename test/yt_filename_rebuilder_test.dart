// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/url_utils.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/yt_utils.dart';

void main() {
  late Directory dir;
  const videoId = 'dQw4w9WgXcQ';

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_yt_filename_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  StreamInfoItem item({String title = 'Some Video', String? description, String? channel, int? indexInPlaylist}) {
    final channelItem = channel == null ? null : ChannelInfoItem(id: 'UC123', handler: '@channel', title: channel, thumbnails: const []);
    return StreamInfoItem(
      id: videoId,
      title: title,
      shortDescription: description,
      channel: channelItem,
      thumbnailGifUrl: null,
      publishedFromText: '',
      publishedAt: const PublishTime.unknown(),
      indexInPlaylist: indexInPlaylist,
      durSeconds: null,
      durText: null,
      viewsText: null,
      viewsCount: null,
      percentageWatched: null,
      liveThumbs: const [],
      isUploaderVerified: null,
      badges: null,
      isActuallyShortContent: null,
    );
  }

  PlaylistBasicInfo playlist({String id = 'PL123', String title = 'My Playlist', int? videosCount}) {
    return PlaylistBasicInfo(id: id, title: title, videosCountText: null, videosCount: videosCount, thumbnails: const []);
  }

  String? rebuild(String template, {StreamInfoItem? videoItem, PlaylistBasicInfo? playlistInfo, int? index, int? total, String fallback = 'NA'}) {
    return YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
      template,
      videoId,
      null,
      null,
      videoItem,
      playlistInfo,
      null,
      null,
      index,
      total,
      fallback: fallback,
    );
  }

  group('rebuildFilenameWithDecodedParams', () {
    test('an unknown param is kept as is while the known ones are replaced', () {
      expect(rebuild('%(foo)s - %(id)s'), '%(foo)s - $videoId');
    });

    test('a template of unknown params only gives null', () {
      expect(rebuild('%(foo)s [%(bar)s]'), null);
    });

    test('id, url and none params', () {
      final videoUrl = YTUrlUtils.buildVideoUrl(videoId);
      expect(rebuild('%(video_id)s|%(url)s|%(none)s'), '$videoId|$videoUrl|');
    });

    test('nightcore titles with regex characters are matched literally against the description', () {
      final cases = {
        'Nightcore - Hey :)': ('Artist X - Hey :)', 'Artist X', 'Hey :)'),
        'Nightcore - F**k Off': ('Artist Y - F**k Off (Official)', 'Artist Y', 'F**k Off'),
        'Nightcore - ???': ('Someone - ???', 'Someone', '???'),
      };
      for (final MapEntry(key: title, value: (description, artist, trackTitle)) in cases.entries) {
        final videoItem = item(title: title, description: 'Subscribe!\n$description');
        expect(rebuild('%(artist)s - %(title)s', videoItem: videoItem), '$artist - $trackTitle', reason: title);
      }
    });

    test('song lines written as title by artist give the artist after by', () {
      const description = '''
• Song: Rolling Stones by Timebelle
• Anime/Game/VN: Kimetsu no Yaiba / Demon Slayers
Follow Timebelle:
• [https://open.spotify.com/artist/5HiW8...](https://open.spotify.com/artist/5HiW8Shh2vPcD16rE8MaBr)
Link to image:
• Artist: [https://mylivewallpapers.com/anime/ne...](https://mylivewallpapers.com/anime/nezuko-moon-shine-live-wallpaper/)
''';
      final videoItem = item(title: 'Nightcore - Rolling Stones - (Lyrics)', description: description);
      expect(rebuild('%(artist)s', videoItem: videoItem), 'Timebelle');
      expect(rebuild('%(title)s', videoItem: videoItem), 'Rolling Stones');
    });

    test('a video title ending in a separator before brackets still matches its song line', () {
      final cases = {
        'Nightcore - Need You - (Lyrics)': 'Song: Lost Sky - Need You',
        'Nightcore - Need You | [AMV]': 'Info: Lost Sky - Need You',
        'Nightcore - Need You – (Sped Up)': 'Lost Sky - Need You',
      };
      for (final MapEntry(key: title, value: songLine) in cases.entries) {
        final videoItem = item(title: title, description: 'Subscribe!\n$songLine\nThanks for watching');
        expect(rebuild('%(artist)s - %(title)s', videoItem: videoItem), 'Lost Sky - Need You', reason: title);
      }
    });

    test('song lines with a dash keep reading as artist - title, even with by in them', () {
      final videoItem = item(title: 'Nightcore - Stand By Me', description: 'Song: Ben E. King - Stand By Me');
      expect(rebuild('%(artist)s|%(title)s', videoItem: videoItem), 'Ben E. King|Stand By Me');
    });

    test('a song line without the video title is still read when the title is unknown', () {
      final videoItem = item(title: 'Nightcore', description: 'Some intro\nSong: Rolling Stones by Timebelle');
      expect(rebuild('%(artist)s', videoItem: videoItem), 'Timebelle');
    });

    test('description values holding links are never used as artist or title', () {
      const description = '''
• Nightcore Love Playlist: https://bit.ly/3uD2Dvv
• Artist: [https://mylivewallpapers.com/anime/ne...](https://mylivewallpapers.com/anime/nezuko-moon-shine-live-wallpaper/)
• Title: www.example.com/some-title
''';
      final videoItem = item(title: 'Nightcore - Some Song', description: description);
      expect(rebuild('%(artist)s', videoItem: videoItem), 'Nightcore');
      expect(rebuild('%(title)s', videoItem: videoItem), 'Some Song');
    });

    test('empty description values are skipped for the next matching line', () {
      final videoItem = item(title: 'Nightcore - Some Song', description: 'Artist:\nArtist: Real Artist');
      expect(rebuild('%(artist)s', videoItem: videoItem), 'Real Artist');
    });

    test('titles with a real artist never read the description', () {
      final videoItem = item(title: 'Timebelle - Rolling Stones', description: 'Song: Something Else by Someone');
      expect(rebuild('%(artist)s|%(title)s', videoItem: videoItem), 'Timebelle|Rolling Stones');
    });

    test('ext uses the given fallback extension when no streams are known', () {
      final rebuilt = YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
        '%(id)s.%(ext)s',
        videoId,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        fallbackExt: 'm4a',
      );
      expect(rebuilt, '$videoId.m4a');
      expect(rebuild('%(id)s.%(ext)s'), '$videoId.mp4');
    });

    test('playlist index and count use the original index and the total length over the playlist info', () {
      final videoItem = item(indexInPlaylist: 2);
      final playlistInfo = playlist(videosCount: 9);
      final rebuilt = rebuild('%(playlist_index)s|%(playlist_autonumber)s|%(playlist_count)s', videoItem: videoItem, playlistInfo: playlistInfo, index: 5, total: 120);
      expect(rebuilt, '005|006|120');
    });

    test('playlist index and count fall back to the playlist videos count without a total length', () {
      final playlistInfo = playlist(videosCount: 9);
      final rebuilt = rebuild('%(playlist_index)s|%(playlist_autonumber)s|%(playlist_count)s', playlistInfo: playlistInfo, index: 5);
      expect(rebuilt, '5|6|9');
    });

    test('missing playlist info gives the fallback instead of null', () {
      const template = '%(playlist_title)s - %(playlist_index)s - %(playlist_count)s';
      expect(rebuild(template), 'NA - NA - NA');
      expect(rebuild(template, fallback: ''), ' -  - ');
    });

    test('playlist param falls back to the playlist id when the title is empty', () {
      final untitled = playlist(title: '');
      final titled = playlist();
      expect(rebuild('%(playlist)s', playlistInfo: untitled), 'PL123');
      expect(rebuild('%(playlist)s', playlistInfo: titled), 'My Playlist');
    });

    test('channel strips a trailing topic keyword while channel_fulltitle keeps it', () {
      final videoItem = item(channel: 'Some Artist - Topic');
      expect(rebuild('%(channel)s|%(channel_fulltitle)s', videoItem: videoItem), 'Some Artist|Some Artist - Topic');
    });
  });

  group('getDefaultTagsFieldsBuilders', () {
    final commonBuilders = {
      FFMPEGTagField.comment: '%(video_url)s',
      FFMPEGTagField.year: '%(upload_date)s',
      FFMPEGTagField.trackNumber: '%(playlist_autonumber)s',
      FFMPEGTagField.trackTotal: '%(playlist_count)s',
      FFMPEGTagField.description: '%(description)s',
    };

    test('auto extract uses the extracting title and artist params, plus album and genre', () {
      final builders = YTUtils.getDefaultTagsFieldsBuilders(true);
      expect(builders, {
        FFMPEGTagField.title: '%(title)s',
        FFMPEGTagField.artist: '%(artist)s',
        FFMPEGTagField.album: '%(channel)s',
        FFMPEGTagField.genre: '%(genre)s',
        ...commonBuilders,
      });
    });

    test('without auto extract the full title and channel are used as is, with no album or genre', () {
      final builders = YTUtils.getDefaultTagsFieldsBuilders(false);
      expect(builders, {
        FFMPEGTagField.title: '%(fulltitle)s',
        FFMPEGTagField.artist: '%(channel)s',
        ...commonBuilders,
      });
    });
  });
}
