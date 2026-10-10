// by claude
import 'package:flutter_test/flutter_test.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/audio_track.dart';
import 'package:youtipie/class/streams/codec_info.dart';
import 'package:youtipie/class/streams/video_stream.dart';

import 'package:namida/youtube/controller/youtube_controller.dart';

void main() {
  AudioTrack track(String id, {bool? isDefault}) {
    final dotIndex = id.indexOf('.');
    final langCode = id.substring(0, dotIndex);
    return AudioTrack(langCode: langCode, displayName: id, id: id, isDefault: isDefault);
  }

  AudioStream audio(int itag, {String container = 'webm', int bitrate = 128000, AudioTrack? audioTrack}) {
    final codec = container == 'webm' ? 'opus' : 'mp4a.40.2';
    return AudioStream(
      itag: itag,
      codecInfo: CodecInfo(isAudio: true, container: container, codec: codec, embeddedAudioInfo: null),
      bitrate: bitrate,
      lastModified: null,
      sizeInBytes: 1000,
      quality: 'tiny',
      averageBitrate: bitrate,
      duration: null,
      url: 'https://example.com/audio/$itag',
      sig: null,
      nsig: null,
      audioTrack: audioTrack,
    );
  }

  VideoStream video(int itag, {required int height, int fps = 30, String container = 'mp4', String codec = 'avc1.640028'}) {
    return VideoStream(
      itag: itag,
      codecInfo: CodecInfo(isAudio: false, container: container, codec: codec, embeddedAudioInfo: null),
      bitrate: height * 1000,
      lastModified: null,
      sizeInBytes: 1000,
      quality: 'hd$height',
      averageBitrate: height * 1000,
      duration: null,
      url: 'https://example.com/video/$itag',
      sig: null,
      nsig: null,
      width: height * 16 ~/ 9,
      height: height,
      fps: fps,
      qualityLabel: '${height}p',
    );
  }

  group('matchAudioStreamOrSimilar', () {
    final singleTrackOpus = audio(251);

    test('a single track target picks the original track once the video got dubs sharing its itag', () {
      final spanish = track('es.0', isDefault: false);
      final english = track('en.4', isDefault: true);
      final original = audio(251, audioTrack: english);
      final streams = [
        audio(251, audioTrack: spanish),
        audio(140, container: 'm4a', audioTrack: spanish),
        original,
        audio(140, container: 'm4a', audioTrack: english),
      ];
      final match = YoutubeController.matchAudioStreamOrSimilar(streams, singleTrackOpus);
      expect(match, same(original));
    });

    test('a single track target picks the same itag on a single track video', () {
      final opus = audio(251);
      final streams = [audio(140, container: 'm4a'), opus];
      final match = YoutubeController.matchAudioStreamOrSimilar(streams, singleTrackOpus);
      expect(match, same(opus));
    });

    test('a single track target whose itag is gone gives null', () {
      final streams = [audio(140, container: 'm4a')];
      final match = YoutubeController.matchAudioStreamOrSimilar(streams, singleTrackOpus);
      expect(match, null);
    });

    test('a preferred itag wins over the target itag, an invalid one falls back to it', () {
      final m4a = audio(140, container: 'm4a');
      final opus = audio(251);
      final streams = [opus, m4a];
      final preferredMatch = YoutubeController.matchAudioStreamOrSimilar(streams, singleTrackOpus, prefferedItag: '140');
      final invalidPreferredMatch = YoutubeController.matchAudioStreamOrSimilar(streams, singleTrackOpus, prefferedItag: 'x');
      expect(preferredMatch, same(m4a));
      expect(invalidPreferredMatch, same(opus));
    });

    test('a multi track target picks the same itag on the same track', () {
      final english = audio(251, audioTrack: track('en.4'));
      final streams = [audio(251, audioTrack: track('es.0')), english];
      final target = audio(251, audioTrack: track('en.4'));
      final match = YoutubeController.matchAudioStreamOrSimilar(streams, target);
      expect(match, same(english));
    });

    test('a multi track target whose itag is gone picks the closest bitrate in the same container on the same track', () {
      final english = track('en.4');
      final closest = audio(250, bitrate: 70000, audioTrack: english);
      final streams = [
        audio(251, bitrate: 160000, audioTrack: track('es.0')),
        audio(140, container: 'm4a', bitrate: 150000, audioTrack: english),
        audio(249, bitrate: 50000, audioTrack: english),
        closest,
      ];
      final target = audio(999, bitrate: 160000, audioTrack: english);
      final match = YoutubeController.matchAudioStreamOrSimilar(streams, target);
      expect(match, same(closest));
    });

    test('a multi track target whose track id is gone picks the same language', () {
      final sameLang = audio(251, audioTrack: track('en.5'));
      final streams = [audio(251, audioTrack: track('es.0')), sameLang];
      final target = audio(251, audioTrack: track('en.4'));
      final match = YoutubeController.matchAudioStreamOrSimilar(streams, target);
      expect(match, same(sameLang));
    });

    test('no streams give null', () {
      final nullStreamsMatch = YoutubeController.matchAudioStreamOrSimilar(null, singleTrackOpus);
      final emptyStreamsMatch = YoutubeController.matchAudioStreamOrSimilar([], singleTrackOpus);
      expect(nullStreamsMatch, null);
      expect(emptyStreamsMatch, null);
    });
  });

  group('matchVideoStreamOrSimilar', () {
    final target1080 = video(137, height: 1080);

    test('the same itag wins', () {
      final exact = video(137, height: 1080);
      final streams = [video(248, height: 1080, container: 'webm', codec: 'vp9'), exact];
      final match = YoutubeController.matchVideoStreamOrSimilar(streams, target1080);
      expect(match, same(exact));
    });

    test('a preferred itag wins over the target itag', () {
      final preferred = video(136, height: 720);
      final streams = [video(137, height: 1080), preferred];
      final match = YoutubeController.matchVideoStreamOrSimilar(streams, target1080, prefferedItag: '136');
      expect(match, same(preferred));
    });

    test('a gone itag picks the same height, fps and codec first', () {
      final sameCodec = video(999, height: 1080);
      final streams = [video(399, height: 1080, codec: 'av01.0.08M.08'), sameCodec];
      final match = YoutubeController.matchVideoStreamOrSimilar(streams, target1080);
      expect(match, same(sameCodec));
    });

    test('a gone itag picks the same height and fps over the same container', () {
      final sameFps = video(248, height: 1080, container: 'webm', codec: 'vp9');
      final streams = [video(299, height: 1080, fps: 60), sameFps];
      final match = YoutubeController.matchVideoStreamOrSimilar(streams, target1080);
      expect(match, same(sameFps));
    });

    test('a gone itag picks the same height in the same container when the fps differs', () {
      final sameContainer = video(299, height: 1080, fps: 60);
      final streams = [video(303, height: 1080, fps: 60, container: 'webm', codec: 'vp9'), sameContainer];
      final match = YoutubeController.matchVideoStreamOrSimilar(streams, target1080);
      expect(match, same(sameContainer));
    });

    test('a gone height picks the closest one, preferring lower over higher', () {
      final lower = video(136, height: 720);
      final streams = [video(271, height: 1440), lower];
      final match = YoutubeController.matchVideoStreamOrSimilar(streams, target1080);
      expect(match, same(lower));
    });

    test('no target and no preferred itag give null', () {
      final match = YoutubeController.matchVideoStreamOrSimilar([target1080], null);
      expect(match, null);
    });
  });

  test('getOutputContainer merges into mp4 unless both streams share the container', () {
    final webmVideo = video(248, height: 1080, container: 'webm', codec: 'vp9');
    final mp4Video = video(137, height: 1080);
    final m4aAudio = audio(140, container: 'm4a');
    final webmAudio = audio(251);
    expect(YoutubeController.getOutputContainer(webmVideo, m4aAudio), 'mp4');
    expect(YoutubeController.getOutputContainer(webmVideo, webmAudio), 'webm');
    expect(YoutubeController.getOutputContainer(null, m4aAudio), 'm4a');
    expect(YoutubeController.getOutputContainer(mp4Video, null), 'mp4');
  });

  test('isSameVideoStream matches by itag or by height, fps and codec', () {
    final base = video(137, height: 1080);
    final sameItag = video(137, height: 720);
    final sameQualityOtherProfile = video(999, height: 1080, codec: 'avc1.4d401f');
    final otherFps = video(999, height: 1080, fps: 60);
    expect(YoutubeController.isSameVideoStream(base, sameItag), true);
    expect(YoutubeController.isSameVideoStream(base, sameQualityOtherProfile), true);
    expect(YoutubeController.isSameVideoStream(base, otherFps), false);
    expect(YoutubeController.isSameVideoStream(base, null), false);
  });
}
