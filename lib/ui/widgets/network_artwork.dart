// ignore_for_file: unused_element_parameter

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:queue/queue.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/youtube/class/download_task_base.dart';

class CustomArtworkManager {
  final File Function() getArtworkFile;
  final Future<void> Function(File? file, Uint8List? bytes) setArtworkFile;
  final Future<List<String>?> Function(CancelToken? cancelToken)? fetchPossibleArtworks;

  const CustomArtworkManager({
    required this.getArtworkFile,
    required this.setArtworkFile,
    required this.fetchPossibleArtworks,
  });

  static CustomArtworkManager playlist(String playlistName) {
    return CustomArtworkManager(
      getArtworkFile: () => PlaylistController.inst.getArtworkFileForPlaylist(playlistName),
      setArtworkFile: (file, bytes) => PlaylistController.inst.setArtworkForPlaylist(playlistName, artworkFile: file, artworkBytes: bytes),
      fetchPossibleArtworks: null,
    );
  }

  static CustomArtworkManager smartPlaylist(SmartPlaylistWrapper smartPlaylistWrapper) {
    return CustomArtworkManager(
      getArtworkFile: () => SmartPlaylistsController.inst.getArtworkFileForPlaylist(smartPlaylistWrapper.value),
      setArtworkFile: (file, bytes) => SmartPlaylistsController.inst.setArtworkForPlaylist(smartPlaylistWrapper.value, artworkFile: file, artworkBytes: bytes),
      fetchPossibleArtworks: null,
    );
  }

  /// passing both [artworkFile] and [artworkBytes] with `null` will delete any previously set artwork.
  static Future<void> _setCustomArtwork(
    File destinationFile, {
    required File? artworkFile,
    required Uint8List? artworkBytes,
    void Function()? onSuccess,
  }) async {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (artworkFile != null) {
      await destinationFile.create(recursive: true);
      await artworkFile.copy(destinationFile.path);
    } else if (artworkBytes != null) {
      await destinationFile.create(recursive: true);
      await destinationFile.writeAsBytes(artworkBytes);
    } else {
      await destinationFile.deleteIfExists();
    }
    onSuccess?.call();
  }
}

class NetworkArtwork extends StatefulWidget {
  final NetworkArtworkInfo info;
  final double thumbnailSize;
  final String? fallbackPath;
  final Track? fallbackTrack;
  final double? height;
  final double? width;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsetsGeometry? margin;
  final List<Widget>? onTopWidgets;
  final bool displayFallbackIcon;
  final double blur;
  final bool compressed;
  final bool staggered;
  final double? iconSize;
  final List<BoxShadow>? boxShadow;
  final bool forceSquared;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final int fadeMilliSeconds;
  final bool disableBlurBgSizeShrink;
  final bool displayIcon;

  const NetworkArtwork._({
    required super.key,
    required this.info,
    required this.thumbnailSize,
    required this.fallbackPath,
    required this.fallbackTrack,
    this.height,
    this.width,
    this.margin,
    this.boxShadow,
    this.alignment = Alignment.center,
    this.borderRadius = 12.0,
    this.isCircle = false,
    this.onTopWidgets,
    this.blur = 5.0,
    this.compressed = true,
    this.staggered = false,
    this.iconSize,
    this.forceSquared = true,
    this.fit = BoxFit.cover,
    this.fadeMilliSeconds = 200,
    this.disableBlurBgSizeShrink = false,
    this.displayIcon = true,
  }) : displayFallbackIcon = true;

  static Widget orLocal({
    required Key key,
    required double thumbnailSize,
    required NetworkArtworkInfo? info,
    int fadeMilliSeconds = 200,
    String? path,
    Track? track,
    List<Widget>? onTopWidgets,
    double borderRadius = 8.0,
    double blur = 5.0,
    double? iconSize,
    BoxFit fit = BoxFit.cover,
    bool displayIcon = true,
    bool forceSquared = true,
    bool compressed = true,
    bool staggered = false,
    bool disableBlurBgSizeShrink = false,
    bool isCircle = false,
  }) {
    if (info != null) {
      final isNetworkAllowed = info.settingsKey.value.any((element) => element.isNetwork);
      if (isNetworkAllowed) {
        return NetworkArtwork._(
          key: key,
          info: info,
          thumbnailSize: thumbnailSize,
          fallbackPath: path,
          fallbackTrack: track,
          onTopWidgets: onTopWidgets,
          fadeMilliSeconds: fadeMilliSeconds,
          borderRadius: borderRadius,
          blur: blur,
          iconSize: iconSize,
          fit: fit,
          displayIcon: displayIcon,
          forceSquared: forceSquared,
          compressed: compressed,
          staggered: staggered,
          disableBlurBgSizeShrink: disableBlurBgSizeShrink,
          isCircle: isCircle,
        );
      }
    }
    return ArtworkWidget(
      key: key,
      thumbnailSize: thumbnailSize,
      path: path,
      track: track,
      onTopWidgets: onTopWidgets ?? const <Widget>[],
      fadeMilliSeconds: fadeMilliSeconds,
      borderRadius: borderRadius,
      blur: blur,
      iconSize: iconSize,
      fit: fit,
      displayIcon: displayIcon,
      forceSquared: forceSquared,
      compressed: compressed,
      staggered: staggered,
      disableBlurBgSizeShrink: disableBlurBgSizeShrink,
      isCircle: isCircle,
    );
  }

  @override
  State<NetworkArtwork> createState() => _NetworkArtworkState();
}

class _NetworkArtworkState extends State<NetworkArtwork> with LoadingItemsDelayMixin {
  String? imagePath = ArtworkWidget.kImagePathInitialValue;

  static final _requests = <NetworkArtworkInfo, _NetworkArtworkRequest>{};

  static final _queue = Queue(parallel: 12);

  static const _pageTimeout = Duration(seconds: 12);
  static const _imageTimeout = Duration(seconds: 30);

  _NetworkArtworkRequest? _joinedRequest;
  static final _defaultHeaders = HttpHeaders.map({HttpHeaderName.userAgent: 'namida'});

  @override
  void initState() {
    super.initState();
    _getThumbnail();
  }

  @override
  void dispose() {
    _leaveRequest();
    super.dispose();
  }

  void _leaveRequest() {
    final request = _joinedRequest;
    if (request == null) return;
    _joinedRequest = null;
    request.requesters--;
    if (request.requesters <= 0 && !request.completer.isCompleted) request.cancel();
  }

  String? _getFallbackArtworkPathExisting() {
    final path = widget.fallbackPath;
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  /// returns `null` on transient failures (should retry later), and empty string when no image exists.
  static Future<String?> _fetchNetworkArtworkUrlLastFm(NetworkArtworkInfo info, CancelToken cancelToken) async {
    if (!ConnectivityController.inst.hasConnection) return null;

    final url = info.toLastfmUrl();
    if (url == null) return null;

    HttpTextResponse response;
    try {
      response = await Rhttp.get(url, headers: _defaultHeaders, cancelToken: cancelToken).timeout(_pageTimeout);
    } catch (_) {
      return null;
    }

    // -- return empty to write empty bytes
    if (response.statusCode == 404) return '';

    // -- return null to try again later. server issue, rate limit, etc..
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final body = response.body;
    RegExpMatch? match;
    for (final regexToUse in NetworkArtworkInfo._lastfmImageAllRegexesList) {
      match = regexToUse.firstMatch(body);
      if (match != null && match.groupCount >= 1) {
        final imageUrl = match.group(1);
        return imageUrl;
      }
    }

    // -- no images found, still write empty bytes
    return '';
  }

  static Future<String?> _fetchNetworkArtwork(NetworkArtworkInfo info, _NetworkArtworkRequest request) async {
    if (request.cancelled) return null;

    final url = await _fetchNetworkArtworkUrlLastFm(info, request.cancelToken);
    if (url == null) return null;

    Uint8List newBytes;

    final isDummyOrStarImage = url.isEmpty || url.endsWith('2a96cbd8b46e442fc41c2b86b821562f.jpg') || url.endsWith('c6f59c1e5e7240a4c0d427abd71f3dbb.jpg');
    if (isDummyOrStarImage) {
      newBytes = Uint8List.fromList([]); // write empty bytes
    } else {
      try {
        final body = await Rhttp.getBytes(url, headers: _defaultHeaders, cancelToken: request.cancelToken).timeout(_imageTimeout);
        newBytes = body.body;
      } catch (_) {
        return null;
      }
      if (newBytes.isEmpty) return null;
    }

    final cachedFilePath = info.toArtworkLocation();
    await cachedFilePath.writeAsBytes(newBytes); // its better to use file itself as bytes can cause issues especially with gifs
    return newBytes.isEmpty ? null : cachedFilePath.path;
  }

  Future<String?> _requestNetworkArtwork() async {
    final info = widget.info;
    var request = _requests[info];
    final joinedExisting = request != null;
    if (request == null) {
      final newRequest = request = _requests[info] = _NetworkArtworkRequest();
      _queue.add(() => _fetchNetworkArtwork(info, newRequest)).ignoreError().then((path) {
        _requests.remove(info);
        newRequest.completer.completeIfWasnt(path);
      });
    }
    request.requesters++;
    _joinedRequest = request;
    final path = await request.completer.future;
    _leaveRequest();

    // -- the request we joined got cancelled by its owner before we could keep it alive, start our own.
    if (path == null && joinedExisting && request.cancelled && mounted) return _requestNetworkArtwork();
    return path;
  }

  Future<void> _getThumbnail() async {
    final cachedFile = widget.info.toArtworkIfExists();
    imagePath = cachedFile?.path;
    imagePath ??= ArtworkWidget.kImagePathInitialValue;

    if (cachedFile != null && cachedFile.fileSizeSync() == 0) {
      // -- manually set empty file, skip network fetch.
      imagePath = ArtworkWidget.kImagePathInitialValue;
    } else {
      if (imagePath == null || imagePath == ArtworkWidget.kImagePathInitialValue) {
        await Future.delayed(Duration.zero);
        if (!await canStartLoadingItems(delayMS: 800)) return;
        if (!mounted) return;

        imagePath = await _requestNetworkArtwork();
        imagePath ??= ArtworkWidget.kImagePathInitialValue;
      }
    }

    if (imagePath == null || imagePath == ArtworkWidget.kImagePathInitialValue) {
      final isLocalAllowed = widget.info.settingsKey.value.contains(LibraryImageSource.local);
      final fallbackPath = isLocalAllowed ? _getFallbackArtworkPathExisting() : null;
      if (fallbackPath != null) {
        imagePath = fallbackPath;
      } else {
        if (widget.displayFallbackIcon) imagePath = null; // -- only set to null if fallback icon is enabled
      }
    }

    refreshState();
  }

  Key get thumbKey => Key("${widget.info.name}$imagePath");

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: ArtworkWidget(
        key: thumbKey,
        isCircle: widget.isCircle,
        bgcolor: context.theme.cardColor.withAlpha(60),
        compressed: widget.compressed,
        blur: widget.blur,
        disableBlurBgSizeShrink: widget.disableBlurBgSizeShrink,
        borderRadius: widget.isCircle ? 0.0 : widget.borderRadius,
        fadeMilliSeconds: widget.fadeMilliSeconds,
        path: imagePath,
        track: widget.fallbackTrack,
        height: widget.height,
        width: widget.width,
        thumbnailSize: widget.thumbnailSize,
        boxShadow: widget.boxShadow,
        icon: widget.info.icon ?? Broken.musicnote,
        iconSize: widget.iconSize ?? widget.thumbnailSize * 0.3,
        forceSquared: widget.forceSquared,
        staggered: widget.staggered,
        staggeredCacheKey: widget.info,
        // cacheHeight: (widget.height?.round() ?? widget.width.round()) ~/ 1.2,
        onTopWidgets: widget.onTopWidgets,

        displayIcon: widget.displayIcon,
        fit: widget.fit,
        alignment: widget.alignment,
        extractInternally: false,
      ),
    );
  }
}

final class _NetworkArtworkInfoAlbum extends NetworkArtworkInfo {
  final String? artist;
  _NetworkArtworkInfoAlbum(String name, this.artist, {super.fileIdentifier}) : super._(name, Broken.music_library_2);

  @override
  RxList<LibraryImageSource> get settingsKey => settings.imageSourceAlbum;

  @override
  File toArtworkLocation() => NetworkArtworkInfo._getCustomArtworkLocation(AppDirs.ARTWORKS_ALBUMS, fileIdentifier ?? name);

  @override
  String? toLastfmUrl() {
    final artist = this.artist;
    if (artist == null || artist.isEmpty) return null;
    final encodedArtist = Uri.encodeComponent(artist);
    final encodedAlbum = Uri.encodeComponent(name);
    final url = '${NetworkArtworkInfo._baseLastfmUrl}/$encodedArtist/$encodedAlbum/+images';
    return url;
  }

  @override
  int get hashCode => name.hashCode ^ artist.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _NetworkArtworkInfoAlbum) return false;
    return name == other.name && artist == other.artist;
  }
}

final class _NetworkArtworkInfoArtist extends NetworkArtworkInfo {
  _NetworkArtworkInfoArtist(String name) : super._(name, Broken.user);

  @override
  RxList<LibraryImageSource> get settingsKey => settings.imageSourceArtist;

  @override
  File toArtworkLocation() => NetworkArtworkInfo._getCustomArtworkLocation(AppDirs.ARTWORKS_ARTISTS, name);

  @override
  String? toLastfmUrl() {
    final encodedArtist = Uri.encodeComponent(name);
    final url = '${NetworkArtworkInfo._baseLastfmUrl}/$encodedArtist/+images';
    return url;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _NetworkArtworkInfoArtist) return false;
    return name == other.name;
  }
}

sealed class NetworkArtworkInfo {
  final String name;
  final String? fileIdentifier; // defaults to [name]
  final IconData? icon;
  const NetworkArtworkInfo._(this.name, this.icon, {this.fileIdentifier});

  factory NetworkArtworkInfo.album(String name, String? artist) = _NetworkArtworkInfoAlbum;
  factory NetworkArtworkInfo.albumAutoArtist(AlbumIdentifierWrapper identifier) {
    final tracks = identifier.getAlbumTracks();
    final album = identifier.displayAlbumName;
    final artist = tracks.firstOrNull?.artistsList.firstOrNull;
    return _NetworkArtworkInfoAlbum(album, artist, fileIdentifier: identifier.resolved());
  }
  factory NetworkArtworkInfo.artist(String name) = _NetworkArtworkInfoArtist;

  static const _baseLastfmUrl = 'https://www.last.fm/music';
  static final _lastfmImageAllRegexesList = [_lastfmAnyImageRegexWithGif, _lastfmSingleHighQualityImageRegex, _lastfmAnyImageRegex];
  static final _lastfmSingleHighQualityImageRegex = RegExp(r'<meta\s+property="og:image"\s+content="([^"]+)"'); // the best image quality, usually only 1
  static final _lastfmAnyImageRegex = RegExp(r'src\="(https:\/\/[^"]*?lastfm[^"]*?fastly[^"]*?avatar[^"]*?\/([a-f0-9]+))"'); // any avatar image
  static final _lastfmAnyImageRegexWithGif = RegExp('${_lastfmAnyImageRegex.pattern}(?=[^>]*?alt="gif")');

  String? toLastfmUrl();

  RxList<LibraryImageSource> get settingsKey;
  File toArtworkLocation();
  File? toArtworkIfExists() {
    final file = toArtworkLocation();
    return file.existsSync() ? file : null;
  }

  File? toArtworkIfExistsAndEnabled() {
    final isNetworkAllowed = settingsKey.value.any((element) => element.isNetwork);
    if (isNetworkAllowed) {
      return toArtworkIfExists();
    }
    return null;
  }

  File? toArtworkIfExistsAndValidAndEnabled() {
    final file = toArtworkIfExistsAndEnabled();
    if (file != null) {
      final size = file.fileSizeSync() ?? 0;
      if (size > 0) {
        return file;
      }
    }
    return null;
  }

  CustomArtworkManager toManager() {
    return CustomArtworkManager(
      getArtworkFile: () => toArtworkLocation(),
      setArtworkFile: (file, bytes) => CustomArtworkManager._setCustomArtwork(
        toArtworkLocation(),
        artworkFile: file,
        artworkBytes: bytes,
      ),
      fetchPossibleArtworks: (cancelToken) async {
        if (!ConnectivityController.inst.hasConnection) return null;
        final url = toLastfmUrl();
        if (url == null) return null;

        final defaultHeaders = HttpHeaders.map({HttpHeaderName.userAgent: 'namida'});
        HttpTextResponse response;
        try {
          response = await Rhttp.get(url, headers: defaultHeaders, cancelToken: cancelToken);
        } on RhttpCancelException catch (_) {
          return null;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) return []; // -- failed to load last.fm page, return empty to write empty bytes

        final body = response.body;
        final regexToUse = NetworkArtworkInfo._lastfmAnyImageRegex;
        final matches = regexToUse.allMatches(body);
        final urls = <String>[];
        for (final m in matches) {
          if (m.groupCount >= 1) {
            final imageUrl = m.group(1);
            if (imageUrl != null) urls.add(imageUrl);
          }
        }
        return urls;
      },
    );
  }

  /// returns file location, even if it doesn't exist
  static File _getCustomArtworkLocation(String dir, String name) => FileParts.join(dir, '${DownloadTaskFilename.cleanupFilename(name, parentDirPath: dir)}.png');
}

class _NetworkArtworkRequest {
  final completer = Completer<String?>();
  final cancelToken = CancelToken();
  int requesters = 0;
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    cancelToken.cancel();
  }
}
