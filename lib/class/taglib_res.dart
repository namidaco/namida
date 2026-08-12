// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_taglib/flutter_taglib.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/controller/logs_controller.dart';

class TagLibRes {
  final String originalPath;
  final TagLibPropertiesWrapper properties;

  const TagLibRes._({
    required this.originalPath,
    required this.properties,
  });

  static Future<TagLibRes?> readIsolate(String trackPath, {required bool extractArtwork}) async {
    try {
      return await Isolate.run(() => readSync(trackPath, extractArtwork: extractArtwork));
    } catch (e, st) {
      logger.error('Error reading tags', e: e, st: st);
      return null;
    }
  }

  static Future<Uint8List?> getArtworkIsolate(String trackPath) async {
    try {
      return await Isolate.run(() => getArtworkSync(trackPath));
    } catch (e, st) {
      logger.error('Error getting artwork', e: e, st: st);
      return null;
    }
  }

  static TagLibRes? readSync(String trackPath, {required bool extractArtwork}) {
    TagLibFile? tagFile;
    try {
      tagFile = TagLibFile.open(trackPath);
      if (tagFile == null) return null;

      final artworkBytes = extractArtwork ? tagFile.coverData : null;
      return TagLibRes._(
        originalPath: trackPath,
        properties: TagLibPropertiesWrapper._(
          audioInfo: tagFile.audioInfo,
          artwork: artworkBytes == null
              ? null
              : FArtwork(
                  bytes: artworkBytes,
                  size: artworkBytes.length,
                ),
          propertiesMap: tagFile.properties,
        ),
      );
    } finally {
      tagFile?.close();
    }
  }

  static Uint8List? getArtworkSync(String trackPath) {
    TagLibFile? tagFile;
    try {
      tagFile = TagLibFile.open(trackPath);
      return tagFile?.coverData;
    } finally {
      tagFile?.close();
    }
  }

  static String? writeSync(String trackPath, {required Map<String, List<String>> newPropertiesMap, required FArtwork? artwork}) {
    TagLibFile? tagFile;
    try {
      tagFile = TagLibFile.open(trackPath);
      if (tagFile == null) return null;

      final allProperties = _mergeNewProperties(
        allProperties: tagFile.properties,
        newPropertiesMap: newPropertiesMap,
      );

      // -- all properties must be set, otherwise taglib would erase them
      tagFile.setProperties(allProperties);

      final newCoverBytes = artwork?.bytes ?? artwork?.file?.readAsBytesSync();
      if (newCoverBytes != null) {
        tagFile.setCover(data: newCoverBytes);
      }
      tagFile.save();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      tagFile?.close();
    }
  }

  static List<String>? _getProperty(Map<String, List<String>> propertiesMap, String field) {
    final val = propertiesMap[field];
    if (val == null || val.isEmpty) return null;
    return val;
  }

  static String? _firstValidKey(Map<String, List<String>> propertiesMap, List<_TagProperty> keys) {
    for (final k in keys) {
      final key = k.resolveKeyIn(propertiesMap);
      if (key != null) return key;
    }
    return null;
  }

  static Map<String, List<String>> _mergeNewProperties({
    required Map<String, List<String>> allProperties,
    required Map<String, List<String>> newPropertiesMap,
  }) {
    // use to preserve the original key source for fields extracted with fallbacks.
    // ex: lyrics extracted from `USLT` will be also saved to `USLT`, not all possible lyrics keys.
    void redirectField(String defaultKey, List<_TagProperty> fallbackKeys) {
      final newVal = _getProperty(newPropertiesMap, defaultKey); // -- `FTags.toTagLibMap` writes the default key only
      if (newVal != null) {
        final validKeyInOldMap = _firstValidKey(allProperties, fallbackKeys);
        allProperties[validKeyInOldMap ?? defaultKey] = newVal;
        newPropertiesMap.remove(defaultKey);
      }
    }

    redirectField(TagLibField.artist, _TagLibFieldsFallback.artist);
    redirectField(TagLibField.lyrics, _TagLibFieldsFallback.lyrics);
    redirectField(TagLibField.comment, _TagLibFieldsFallback.comment);
    redirectField(TagLibField.description, _TagLibFieldsFallback.description);
    redirectField(TagLibField.date, _TagLibFieldsFallback.date);
    redirectField(TagLibField.rating, _TagLibFieldsFallback.rating);
    redirectField(TagLibField.label, _TagLibFieldsFallback.label);

    allProperties.addAll(newPropertiesMap);
    return allProperties;
  }

  FAudioModel toFAudioModel({required FArtwork? artwork}) {
    final info = this.properties;
    int? parsy(String? v) => v == null ? null : int.tryParse(v);
    final audioInfo = info.audioInfo;
    final channels = audioInfo.channels;
    return FAudioModel(
      tags: FTags(
        path: this.originalPath,
        artwork: artwork ?? FArtwork(),
        title: info.title,
        album: info.album,
        albumArtist: info.albumArtist,
        artist: info.artist,
        composer: info.composer,
        genre: info.genre,
        style: info.style,
        trackNumber: info.trackNumber,
        trackTotal: info.trackTotal,
        discNumber: info.discNumber,
        discTotal: info.discTotal,
        lyrics: info.lyrics,
        comment: info.comment,
        description: info.description,
        synopsis: info.synopsis,
        year: info.date,
        language: info.language,
        lyricist: info.lyricist,
        remixer: info.remixer,
        rating: info.rating,
        mood: info.mood,
        tags: info.tags,
        country: info.country,
        recordLabel: info.recordLabel,
        bpm: parsy(info.bpm),
        mbAlbumId: info.MUSICBRAINZ_ALBUMID,
        mbAlbumArtistId: info.MUSICBRAINZ_ALBUMARTISTID,
        gainData: ReplayGainData.fromTagLibMap(properties),
        sortInfo: FTagsSortInfo.fromTagLibMap(properties),
        ratingPercentage: FTags.ratingToPercentage(info.rating),
        tempo: info.tempo,
        djmixer: info.djmixer,
        mixer: info.mixer,
      ),
      durationMS: audioInfo.duration.inMilliseconds,
      sampleRate: audioInfo.sampleRate,
      bitRate: audioInfo.bitrate,
      channels: switch (channels) {
        0 => null,
        1 => 'mono',
        2 => 'stereo',
        _ => channels.toString(),
      },
      format: audioInfo.format,
      bits: audioInfo.bitsPerSample,
      isLossless: audioInfo.isLossless,
    );
  }
}

class TagLibPropertiesWrapper {
  final FArtwork? artwork;
  final AudioInfo audioInfo;
  final Map<String, List<String>> propertiesMap;

  const TagLibPropertiesWrapper._({
    required this.artwork,
    required this.audioInfo,
    required this.propertiesMap,
  });

  String? _getProperty(String field) {
    final val = propertiesMap[field];
    if (val == null || val.isEmpty) return null;
    if (val.length == 1) return val[0];
    return val.join(', ');
  }

  String? _getPropertyFirst(String field) {
    final val = propertiesMap[field];
    if (val == null || val.isEmpty) return null;
    return val[0];
  }

  String? _getPropertyFallbacks(List<_TagProperty> keys) {
    for (final k in keys) {
      final key = k.resolveKeyIn(propertiesMap);
      if (key != null) return _getProperty(key);
    }
    return null;
  }

  String? _getPropertyFirstFallbacks(List<_TagProperty> keys) {
    for (final k in keys) {
      final key = k.resolveKeyIn(propertiesMap);
      if (key != null) return _getPropertyFirst(key);
    }
    return null;
  }

  String? get title => _getProperty(TagLibField.title);
  String? get album => _getProperty(TagLibField.album);
  String? get albumArtist => _getProperty(TagLibField.albumArtist);
  String? get artist => _getPropertyFallbacks(_TagLibFieldsFallback.artist);
  String? get composer => _getProperty(TagLibField.composer);
  String? get genre => _getProperty(TagLibField.genre);
  String? get style => _getProperty(TagLibField.style);
  String? get trackNumber => _getProperty(TagLibField.trackNumber);
  String? get trackTotal => _getProperty(TagLibField.trackTotal);
  String? get discNumber => _getProperty(TagLibField.discNumber);
  String? get discTotal => _getProperty(TagLibField.discTotal);
  String? get lyrics => _getPropertyFallbacks(_TagLibFieldsFallback.lyrics);
  String? get comment => _getPropertyFallbacks(_TagLibFieldsFallback.comment);
  String? get description => _getPropertyFirstFallbacks(_TagLibFieldsFallback.description);
  String? get synopsis => _getPropertyFirst(TagLibField.synopsis);
  String? get date => _getPropertyFirstFallbacks(_TagLibFieldsFallback.date);
  String? get language => _getProperty(TagLibField.language);
  String? get lyricist => _getProperty(TagLibField.lyricist);
  String? get remixer => _getProperty(TagLibField.remixer);
  String? get rating => _getPropertyFirstFallbacks(_TagLibFieldsFallback.rating);
  String? get mood => _getProperty(TagLibField.mood);
  String? get tags => _getProperty(TagLibField.tags);
  String? get country => _getProperty(TagLibField.country);
  String? get recordLabel => _getPropertyFallbacks(_TagLibFieldsFallback.label);
  String? get bpm => _getPropertyFirst(TagLibField.bpm);
  String? get sampleRate => _getPropertyFirst(TagLibField.sampleRate);
  String? get tempo => _getPropertyFirst(TagLibField.tempo);
  String? get mixer => _getPropertyFirst(TagLibField.mixer);
  String? get djmixer => _getPropertyFirst(TagLibField.djmixer);

  String? get titleSort => _getPropertyFirst(TagLibField.titleSort);
  String? get albumSort => _getPropertyFirst(TagLibField.albumSort);
  String? get albumArtistSort => _getPropertyFirst(TagLibField.albumArtistSort);
  String? get artistSort => _getPropertyFirst(TagLibField.artistSort);
  String? get composerSort => _getPropertyFirst(TagLibField.composerSort);

  String? get MP3GAIN_ALBUM_MINMAX => _getPropertyFirst(TagLibField.MP3GAIN_ALBUM_MINMAX); // [061,205]
  String? get MP3GAIN_MINMAX => _getPropertyFirst(TagLibField.MP3GAIN_MINMAX); // [110,181]
  String? get MP3GAIN_UNDO => _getPropertyFirst(TagLibField.MP3GAIN_UNDO); // [+005,+005,N]
  String? get REPLAYGAIN_ALBUM_GAIN => _getPropertyFirst(TagLibField.REPLAYGAIN_ALBUM_GAIN); // [-0.040000 dB]
  String? get REPLAYGAIN_ALBUM_PEAK => _getPropertyFirst(TagLibField.REPLAYGAIN_ALBUM_PEAK); // [0.449919]
  String? get REPLAYGAIN_REFERENCE_LOUDNESS => _getPropertyFirst(TagLibField.REPLAYGAIN_REFERENCE_LOUDNESS); // [89.0 dB]
  String? get REPLAYGAIN_TRACK_GAIN => _getPropertyFirst(TagLibField.REPLAYGAIN_TRACK_GAIN); // [+0.655000 dB]
  String? get REPLAYGAIN_TRACK_PEAK => _getPropertyFirst(TagLibField.REPLAYGAIN_TRACK_PEAK); // [0.443497]

  String? get MD5 => _getPropertyFirst(TagLibField.MD5);
  String? get MUSICBRAINZ_ALBUMARTISTID => _getPropertyFirst(TagLibField.MUSICBRAINZ_ALBUMARTISTID);
  String? get MUSICBRAINZ_ALBUMID => _getPropertyFirst(TagLibField.MUSICBRAINZ_ALBUMID);
  String? get MUSICBRAINZ_ARTISTID => _getPropertyFirst(TagLibField.MUSICBRAINZ_ARTISTID);
  String? get MUSICBRAINZ_RELEASEGROUPID => _getPropertyFirst(TagLibField.MUSICBRAINZ_RELEASEGROUPID);
  String? get MUSICBRAINZ_RELEASETRACKID => _getPropertyFirst(TagLibField.MUSICBRAINZ_RELEASETRACKID);
  String? get MUSICBRAINZ_TRACKID => _getPropertyFirst(TagLibField.MUSICBRAINZ_TRACKID);
}

class _TagLibFieldsFallback {
  static const List<_TagProperty> artist = [
    _TagProperty.key(TagLibField.artist),
    _TagProperty.key(TagLibField.artists),
  ];
  static const List<_TagProperty> lyrics = [
    _TagProperty.key(TagLibField.sylt), // sylt cuz lyrics is usually auto mapped to uslt in taglib
    _TagProperty.key(TagLibField.lyrics),
    _TagProperty.key(TagLibField.uslt),
    _TagProperty.key(TagLibField.unsyncedLyrics),
    _TagProperty.key(TagLibField.lyricsXXX),
    _TagProperty.prefix('${TagLibField.lyrics}:'), // -- `LYRICS:XXX` description/language variants
  ];
  static const List<_TagProperty> comment = [
    _TagProperty.key(TagLibField.comment),
    _TagProperty.prefix('${TagLibField.comment}:'),
    _TagProperty.key(TagLibField.pUrl),
    _TagProperty.key(TagLibField.url),
  ];
  static const List<_TagProperty> description = [
    _TagProperty.key(TagLibField.description),
    _TagProperty.key(TagLibField.desc),
    _TagProperty.key(TagLibField.podcastdesc),
  ];
  static const List<_TagProperty> date = [
    _TagProperty.key(TagLibField.date),
    _TagProperty.key(TagLibField.year),
  ];
  static const List<_TagProperty> rating = [
    _TagProperty.key(TagLibField.rating),
    _TagProperty.key(TagLibField.fmpsRating),
    _TagProperty.prefix(TagLibField.rating), // -- `RATING WMP`, `RATING MM`, `RATING:XXX`, etc
  ];
  static const List<_TagProperty> label = [
    _TagProperty.key(TagLibField.label),
    _TagProperty.key(TagLibField.recordLabel),
  ];
}

class _TagProperty {
  final String key;
  final bool isPrefix;

  const _TagProperty.key(this.key) : isPrefix = false;
  const _TagProperty.prefix(this.key) : isPrefix = true;

  /// Returns the first valid key in [propertiesMap].
  String? resolveKeyIn(Map<String, List<String>> propertiesMap) {
    if (isPrefix) {
      for (final mapKey in propertiesMap.keys) {
        if (mapKey.startsWith(key)) {
          final val = propertiesMap[mapKey];
          if (val != null && val.isNotEmpty) return mapKey;
        }
      }
    } else {
      final val = propertiesMap[key];
      if (val != null && val.isNotEmpty) return key;
    }
    return null;
  }
}

class TagLibField {
  static const title = 'TITLE';
  static const album = 'ALBUM';
  static const albumArtist = 'ALBUMARTIST';
  static const artist = 'ARTIST';
  static const artists = 'ARTISTS';
  static const composer = 'COMPOSER';
  static const genre = 'GENRE';
  static const style = 'STYLE';
  static const trackNumber = 'TRACKNUMBER';
  static const trackTotal = 'TRACKTOTAL';
  static const discNumber = 'DISCNUMBER';
  static const discTotal = 'DISCTOTAL';
  static const subtitle = 'SUBTITLE';
  static const discSubtitle = 'DISCSUBTITLE';
  static const lyrics = 'LYRICS';
  static const uslt = 'USLT'; // -- raw TXXX frame written by ffmpeg/yt-dlp
  static const unsyncedLyrics = 'UNSYNCEDLYRICS';
  static const sylt = 'SYLT';
  static const lyricsXXX = 'LYRICS-XXX';
  static const comment = 'COMMENT';
  static const pUrl = 'PURL'; // -- source webpage url, written by yt-dlp
  static const url = 'URL';
  static const website = 'WEBSITE';
  static const description = 'DESCRIPTION';
  static const desc = 'DESC';
  static const podcastdesc = 'PODCASTDESC';
  static const synopsis = 'SYNOPSIS';
  static const year = 'YEAR';
  static const date = 'DATE';
  static const originalDate = 'ORIGINALDATE';
  static const releaseDate = 'RELEASEDATE';
  static const encodingTime = 'ENCODINGTIME';
  static const taggingDate = 'TAGGINGDATE';
  static const language = 'LANGUAGE';
  static const lyricist = 'LYRICIST';
  static const originalLyricist = 'ORIGINALLYRICIST';
  static const originalArtist = 'ORIGINALARTIST';
  static const originalAlbum = 'ORIGINALALBUM';
  static const originalFilename = 'ORIGINALFILENAME';
  static const remixer = 'REMIXER';
  static const conductor = 'CONDUCTOR';
  static const arranger = 'ARRANGER';
  static const engineer = 'ENGINEER';
  static const producer = 'PRODUCER';
  static const performer = 'PERFORMER';
  static const rating = 'RATING';
  static const fmpsRating = 'FMPS_RATING';
  static const ratingWMP = 'RATING WMP';
  static const ratingMM = 'RATING MM';
  static const fmpsPlaycount = 'FMPS_PLAYCOUNT';
  static const mood = 'MOOD';
  static const tags = 'TAGS';
  static const country = 'COUNTRY';
  static const label = 'LABEL';
  static const recordLabel = 'RECORDLABEL';
  static const publisher = 'PUBLISHER';
  static const organization = 'ORGANIZATION';
  static const tempo = 'TEMPO';
  static const mixer = 'MIXER';
  static const djmixer = 'DJMIXER';
  static const bpm = 'BPM';
  static const initialKey = 'INITIALKEY';
  static const length = 'LENGTH';
  static const channels = 'CHANNELS';
  static const sampleRate = 'SAMPLERATE';
  static const work = 'WORK';
  static const grouping = 'GROUPING';
  static const movementName = 'MOVEMENTNAME';
  static const movementNumber = 'MOVEMENTNUMBER';
  static const movementCount = 'MOVEMENTCOUNT';
  static const showWorkMovement = 'SHOWWORKMOVEMENT';
  static const compilation = 'COMPILATION';
  static const show = 'SHOW';
  static const showSort = 'SHOWSORT';
  static const version = 'VERSION';
  static const location = 'LOCATION';
  static const contact = 'CONTACT';
  static const isrc = 'ISRC';
  static const asin = 'ASIN';
  static const barcode = 'BARCODE';
  static const catalogNumber = 'CATALOGNUMBER';
  static const copyright = 'COPYRIGHT';
  static const copyrightUrl = 'COPYRIGHTURL';
  static const license = 'LICENSE';
  static const encodedBy = 'ENCODEDBY';
  static const encoding = 'ENCODING';
  static const encoder = 'ENCODER';
  static const media = 'MEDIA';
  static const fileType = 'FILETYPE';
  static const playlistDelay = 'PLAYLISTDELAY';
  static const owner = 'OWNER';
  static const producedNotice = 'PRODUCEDNOTICE';
  static const radioStation = 'RADIOSTATION';
  static const radioStationOwner = 'RADIOSTATIONOWNER';
  static const artistWebpage = 'ARTISTWEBPAGE';
  static const fileWebpage = 'FILEWEBPAGE';
  static const audioSourceWebpage = 'AUDIOSOURCEWEBPAGE';
  static const radioStationWebpage = 'RADIOSTATIONWEBPAGE';
  static const paymentWebpage = 'PAYMENTWEBPAGE';
  static const publisherWebpage = 'PUBLISHERWEBPAGE';
  static const releaseCountry = 'RELEASECOUNTRY';
  static const releaseStatus = 'RELEASESTATUS';
  static const releaseType = 'RELEASETYPE';
  static const podcast = 'PODCAST';
  static const podcastCategory = 'PODCASTCATEGORY';
  static const podcastId = 'PODCASTID';
  static const podcastUrl = 'PODCASTURL';
  static const gaplessPlayback = 'GAPLESSPLAYBACK';

  static const titleSort = 'TITLESORT';
  static const albumSort = 'ALBUMSORT';
  static const albumArtistSort = 'ALBUMARTISTSORT';
  static const artistSort = 'ARTISTSORT';
  static const composerSort = 'COMPOSERSORT';

  static const MP3GAIN_ALBUM_MINMAX = 'MP3GAIN_ALBUM_MINMAX';
  static const MP3GAIN_MINMAX = 'MP3GAIN_MINMAX';
  static const MP3GAIN_UNDO = 'MP3GAIN_UNDO';
  static const REPLAYGAIN_ALBUM_GAIN = 'REPLAYGAIN_ALBUM_GAIN';
  static const REPLAYGAIN_ALBUM_PEAK = 'REPLAYGAIN_ALBUM_PEAK';
  static const REPLAYGAIN_REFERENCE_LOUDNESS = 'REPLAYGAIN_REFERENCE_LOUDNESS';
  static const REPLAYGAIN_TRACK_GAIN = 'REPLAYGAIN_TRACK_GAIN';
  static const REPLAYGAIN_TRACK_PEAK = 'REPLAYGAIN_TRACK_PEAK';
  static const R128_TRACK_GAIN = 'R128_TRACK_GAIN';
  static const R128_ALBUM_GAIN = 'R128_ALBUM_GAIN';

  static const MD5 = 'MD5';
  static const MUSICBRAINZ_ALBUMARTISTID = 'MUSICBRAINZ_ALBUMARTISTID';
  static const MUSICBRAINZ_ALBUMID = 'MUSICBRAINZ_ALBUMID';
  static const MUSICBRAINZ_ARTISTID = 'MUSICBRAINZ_ARTISTID';
  static const MUSICBRAINZ_RELEASEGROUPID = 'MUSICBRAINZ_RELEASEGROUPID';
  static const MUSICBRAINZ_RELEASETRACKID = 'MUSICBRAINZ_RELEASETRACKID';
  static const MUSICBRAINZ_TRACKID = 'MUSICBRAINZ_TRACKID';
  static const MUSICBRAINZ_WORKID = 'MUSICBRAINZ_WORKID';
  static const MUSICBRAINZ_DISCID = 'MUSICBRAINZ_DISCID';
  static const ACOUSTID_ID = 'ACOUSTID_ID';
  static const ACOUSTID_FINGERPRINT = 'ACOUSTID_FINGERPRINT';
  static const MUSICIP_PUID = 'MUSICIP_PUID';
}
