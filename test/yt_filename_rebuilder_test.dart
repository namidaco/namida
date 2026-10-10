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
