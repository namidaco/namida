part of 'smtc_manager.dart';

class _SMTCManagerLinux extends NamidaSMTCManager {
  MPRIS? mpris;

  @override
  Future<void> init() async {
    try {
      final instance = await MPRIS.create(
        busName: 'org.mpris.MediaPlayer2.namida',
        identity: 'Namida',
        desktopEntry: '/usr/share/applications/namida',
        supportedUriSchemes: {
          'ftp',
          'file',
          'rtmp',
          // 'rtsp',
          // 'http',
          // 'https',
        },
      );
      mpris = instance;
      instance.setEventHandler(
        MPRISEventHandler(
          playPause: () async {
            if (instance.playbackStatus == MPRISPlaybackStatus.playing) {
              instance.playbackStatus = MPRISPlaybackStatus.paused;
              await Player.inst.pause();
            } else {
              instance.playbackStatus = MPRISPlaybackStatus.playing;
              await Player.inst.play();
            }
          },
          play: () async {
            instance.playbackStatus = MPRISPlaybackStatus.playing;
            await Player.inst.play();
          },
          pause: () async {
            instance.playbackStatus = MPRISPlaybackStatus.paused;
            await Player.inst.pause();
          },
          next: () async {
            await Player.inst.next();
          },
          previous: () async {
            await Player.inst.previous();
          },
          stop: () async {
            await Player.inst.pause().whenComplete(Player.inst.dispose);
          },
          seek: (offset) async {
            await Player.inst.seek(offset);
          },

          setPosition: (_, value) => Player.inst.seek(Duration(microseconds: value)),
          // openUri: (value) => Intent.instance.play(value.toString()),
          // loopStatus: (value) => setLoop(
          //   switch (value) {
          //     MPRISLoopStatus.none => Loop.off,
          //     MPRISLoopStatus.track => Loop.one,
          //     MPRISLoopStatus.playlist => Loop.all,
          //   },
          // ),
          rate: (value) => Player.inst.setPlayerSpeed(value),
          // shuffle: (value) => Player.inst.setShuffle(value),
          volume: (value) => Player.inst.setVolume(value * 100.0),
        ),
      );
    } catch (e, st) {
      logger.error('Failed to initialize MPRIS', e: e, st: st);
    }
  }

  @override
  void onPlay() {
    mpris?.playbackStatus = MPRISPlaybackStatus.playing;
  }

  @override
  void onPause() {
    mpris?.playbackStatus = MPRISPlaybackStatus.paused;
  }

  @override
  void onStop() {
    mpris?.playbackStatus = MPRISPlaybackStatus.stopped;
    // -- alternative is to call _ensureEnabled before each operation, but risking the mpris being stuck after dispose?
    // mpris?.dispose();
    // mpris = null;
  }

  @override
  Future<void> dispose() async {
    mpris?.playbackStatus = MPRISPlaybackStatus.stopped;
    mpris?.dispose();
    mpris = null;
  }

  @override
  void updateMetadata(MediaItem mediaItem) async {
    // await _ensureEnabled();
    final metadata = MPRISMetadata(
      Uri.file(mediaItem.id), // only local files
      title: mediaItem.title,
      artist: [if (mediaItem.artist != null) mediaItem.artist!],
      album: mediaItem.album,
      albumArtist: null,
      length: mediaItem.duration,
      artUrl: mediaItem.artUri,
    );
    mpris?.metadata = metadata;
  }

  @override
  void updateTimeline(int positionMS, int? durationMS) {
    mpris?.position = Duration(milliseconds: positionMS);
  }

  // Future<void> _ensureEnabled() async {
  //   if (mpris != null) return;
  //   await init();
  // }
}

// extension _LinuxUriUtils on Uri {
//   String toFilePathLinux_() {
//     return toFilePath(windows: false);
//   }
// }
