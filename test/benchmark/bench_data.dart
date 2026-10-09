// by claude
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dart_extensions/dart_extensions.dart';

const kBenchTracksCount = 50000;
const kBenchArtistSeparators = ['&', ',', ';', '//', ' ft. ', ' x '];
const kBenchGenreSeparators = ['&', ',', ';', '//', ' x '];

class BenchRunner {
  final String suite;
  final _results = <BenchResult>[];

  BenchRunner(this.suite);

  Future<BenchResult> run(String name, FutureOr<Object?> Function() body, {FutureOr<void> Function()? setUp, int warmups = 3, int iterations = 10}) async {
    for (int i = 0; i < warmups; i++) {
      await setUp?.call();
      final res = await body();
      _sink ^= res.hashCode;
    }
    final samplesMicros = <int>[];
    final stopwatch = Stopwatch();
    for (int i = 0; i < iterations; i++) {
      await setUp?.call();
      stopwatch.reset();
      stopwatch.start();
      final res = await body();
      stopwatch.stop();
      _sink ^= res.hashCode;
      samplesMicros.add(stopwatch.elapsedMicroseconds);
    }
    final result = BenchResult(name, samplesMicros);
    _results.add(result);
    print('BENCH|$suite|${result.toLine()}');
    return result;
  }

  void digest(String name, Iterable<String> lines) {
    final digest = BenchDigest();
    final dumpDirPath = Platform.environment['NAMIDA_BENCH_DUMP'];
    final dumpBuffer = dumpDirPath == null ? null : StringBuffer();
    for (final line in lines) {
      digest.add(line);
      dumpBuffer?.writeln(line);
    }
    print('DIGEST|$suite|$name|${digest.count}|${digest.toHex()}');
    if (dumpDirPath != null && dumpBuffer != null) {
      final file = File('$dumpDirPath${Platform.pathSeparator}$suite.$name.txt');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(dumpBuffer.toString());
    }
  }

  void finish() {
    print('SUMMARY|$suite|${_results.length} cases|sink=${_sink & 0xFF}');
  }

  static int _sink = 0;
}

class SyntheticLibrary {
  static const _kWords = [
    'love', 'night', 'fire', 'heart', 'dream', 'rain', 'summer', 'light', 'home', 'road', //
    'city', 'blue', 'gold', 'river', 'storm', 'shadow', 'dance', 'wild', 'ocean', 'star', //
    'moon', 'sun', 'time', 'world', 'soul', 'paradise', 'echo', 'silence', 'memory', 'angel', //
    'ghost', 'winter', 'autumn', 'spring', 'desert', 'garden', 'mirror', 'glass', 'smoke', 'thunder', //
  ];
  static const _kSyllables = ['ka', 'ri', 'to', 'mi', 'ne', 'sa', 'lo', 've', 'da', 'ry', 'an', 'el', 'or', 'us', 'ix', 'be', 'zo', 'qu', 'fa', 'te'];
  static const _kAccented = ['é', 'ö', 'ñ', 'ü', 'å'];
  static const _kCJK = ['米', '津', '玄', '師', '宇', '多', '田', '光', 'あ', 'い', 'う', 'カ', 'ル', 'ヒ', 'ン', '雨', '夜'];
  static const _kGenres = [
    'Rock', 'Pop', 'Hip Hop', 'Electronic', 'Jazz', 'Classical', 'Metal', 'Indie', 'R&B', 'Soul', //
    'Folk', 'Country', 'Ambient', 'House', 'Techno', 'Trance', 'Dubstep', 'Punk', 'Blues', 'Reggae', //
    'Lo-Fi', 'J-Pop', 'K-Pop', 'Anime', 'Soundtrack', 'Alternative', 'Funk', 'Disco', 'Synthwave', 'Drum & Bass', //
  ];
  static const _kArtistSeparators = [' & ', ', ', '; ', ' ft. ', ' x ', ' feat. ', ' & ', ' // ', '  &  ', ' X '];
  static const _kGenreSeparators = ['; ', ', ', ' & ', '/', ' // '];
  static const _kYtIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  static const _kYtIdLastChars = 'AEIMQUYcgkosw048';

  final Random _random;
  late final _artists = List.generate(4000, (_) => _artistName(), growable: false);
  late final _albums = List.generate(5000, (_) => phrase(1, 3), growable: false);
  late final _composers = List.generate(800, (_) => _personName(), growable: false);

  SyntheticLibrary(int seed) : _random = Random(seed);

  static List<SyntheticTrack> generate(int count, {int seed = 42, String root = '/storage/emulated/0/Music'}) {
    final library = SyntheticLibrary(seed);
    return List.generate(count, (i) => library._track(i, root), growable: false);
  }

  String youtubeId() {
    final buffer = StringBuffer();
    for (int i = 0; i < 10; i++) {
      final charIndex = _random.nextInt(_kYtIdChars.length);
      buffer.write(_kYtIdChars[charIndex]);
    }
    final lastCharIndex = _random.nextInt(_kYtIdLastChars.length);
    buffer.write(_kYtIdLastChars[lastCharIndex]);
    return buffer.toString();
  }

  String word() {
    final roll = _random.nextDouble();
    if (roll < 0.55) return _pick(_kWords);
    final syllablesCount = 2 + _random.nextInt(2);
    final buffer = StringBuffer();
    for (int i = 0; i < syllablesCount; i++) {
      buffer.write(_pick(_kSyllables));
    }
    final word = buffer.toString();
    final isAccented = _random.nextDouble() < 0.04;
    if (!isAccented) return word;
    final lastChar = word[word.length - 1];
    final accented = _pick(_kAccented);
    return word.replaceFirst(lastChar, accented);
  }

  String phrase(int minWords, int maxWords) {
    final wordsCount = minWords + _random.nextInt(maxWords - minWords + 1);
    final words = List.generate(wordsCount, (_) => _capitalized(word()), growable: false);
    return words.join(' ');
  }

  String _capitalized(String word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';

  String _personName() {
    final first = _capitalized(word());
    final last = _capitalized(word());
    return '$first $last';
  }

  String _artistName() {
    final roll = _random.nextDouble();
    if (roll < 0.02) {
      final charsCount = 2 + _random.nextInt(3);
      final chars = List.generate(charsCount, (_) => _pick(_kCJK), growable: false);
      return chars.join();
    }
    if (roll < 0.15) {
      final name = phrase(1, 2);
      return 'The $name';
    }
    if (roll < 0.55) return _personName();
    return _capitalized(word());
  }

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  String _artistsText(String firstArtist) {
    final roll = _random.nextDouble();
    final count = roll < 0.7 ? 1 : (roll < 0.9 ? 2 : 3);
    final buffer = StringBuffer(firstArtist);
    for (int i = 1; i < count; i++) {
      buffer.write(_pick(_kArtistSeparators));
      final isCaseDuplicate = _random.nextDouble() < 0.01;
      final artist = isCaseDuplicate ? firstArtist.toLowerCase() : _pick(_artists);
      buffer.write(artist);
    }
    return buffer.toString();
  }

  String _title() {
    final base = phrase(1, 4);
    final roll = _random.nextDouble();
    final hasThe = _random.nextDouble() < 0.08;
    final titleWithThe = hasThe ? 'The $base' : base;
    if (roll < 0.12) {
      final featArtist = _pick(_artists);
      return '$titleWithThe (feat. $featArtist)';
    }
    if (roll < 0.15) {
      final featArtist = _pick(_artists);
      final secondFeatArtist = _pick(_artists);
      return '$titleWithThe [ft. $featArtist & $secondFeatArtist]';
    }
    if (roll < 0.20) return '$titleWithThe (Remix)';
    if (roll < 0.22) {
      final featArtist = _pick(_artists);
      return '$titleWithThe feat. $featArtist';
    }
    return titleWithThe;
  }

  String? _genre() {
    final roll = _random.nextDouble();
    if (roll < 0.15) return null;
    if (roll < 0.75) return _pick(_kGenres);
    final first = _pick(_kGenres);
    final separator = _pick(_kGenreSeparators);
    final second = _pick(_kGenres);
    return '$first$separator$second';
  }

  String? _year() {
    final year = 1965 + _random.nextInt(60);
    final month = (1 + _random.nextInt(12)).toString().padLeft(2, '0');
    final day = (1 + _random.nextInt(28)).toString().padLeft(2, '0');
    final roll = _random.nextDouble();
    if (roll < 0.40) return '$year';
    if (roll < 0.65) return '$year-$month-$day';
    if (roll < 0.73) return '$year$month$day';
    if (roll < 0.78) return '$year/$month/$day';
    if (roll < 0.80) return '$day.$month.$year';
    if (roll < 0.85) return '';
    return null;
  }

  String? _comment(String? ytId) {
    final roll = _random.nextDouble();
    if (ytId != null && roll < 0.6) return 'https://www.youtube.com/watch?v=$ytId';
    if (ytId != null && roll < 0.9) return 'youtu.be/$ytId';
    if (roll < 0.05) {
      final person = _personName();
      final note = phrase(2, 6);
      return 'Ripped by $person $note';
    }
    return null;
  }

  String _filenameWOExt(String artist, String title) {
    final roll = _random.nextDouble();
    if (roll < 0.03) {
      final id = youtubeId();
      return '$title [$id]';
    }
    if (roll < 0.05) return youtubeId();
    if (roll < 0.06) {
      final id = youtubeId();
      return '$title v=$id';
    }
    if (roll < 0.20) {
      final number = (1 + _random.nextInt(20)).toString().padLeft(2, '0');
      return '$number. $title';
    }
    return '$artist - $title';
  }

  SyntheticTrack _track(int index, String root) {
    final firstArtist = _pick(_artists);
    final artist = _artistsText(firstArtist);
    final title = _title();
    final hasYtId = _random.nextDouble() < 0.05;
    final ytId = hasYtId ? youtubeId() : null;
    final extensionRoll = _random.nextDouble();
    final extension = extensionRoll < 0.7 ? 'mp3' : (extensionRoll < 0.85 ? 'm4a' : 'flac');
    final folder = 'Folder ${index % 600}';
    final filenameWOExt = _filenameWOExt(firstArtist, title);
    final path = '$root/$folder/$filenameWOExt.$extension';
    final isUntagged = _random.nextDouble() < 0.05;
    final album = _album();
    final albumArtistRoll = _random.nextDouble();
    final albumArtist = albumArtistRoll < 0.6 ? firstArtist : (albumArtistRoll < 0.7 ? 'Various Artists' : null);
    final composer = _composer();
    final trackRoll = _random.nextDouble();
    final trackNo = 1 + _random.nextInt(20);
    final trackNumber = trackRoll < 0.3 ? '$trackNo/20' : (trackRoll < 0.8 ? '$trackNo' : null);
    final discNumber = _random.nextDouble() < 0.2 ? '1/2' : null;
    final dateAddedMS = 1500000000000 + _random.nextInt(250000000) * 1000;
    final hasRating = _random.nextDouble() < 0.2;
    final rating = hasRating ? _random.nextInt(11) / 10 : 0.0;
    final genre = isUntagged ? null : _genre();
    final year = isUntagged ? null : _year();
    final comment = isUntagged ? null : _comment(ytId);
    final durationMS = 60000 + _random.nextInt(360000);
    final sizeBytes = 2000000 + _random.nextInt(12000000);
    final dateModifiedMS = dateAddedMS + _random.nextInt(100000000);
    return SyntheticTrack(
      path: path,
      title: isUntagged ? null : title,
      artist: isUntagged ? null : artist,
      album: isUntagged ? null : album,
      albumArtist: isUntagged ? null : albumArtist,
      genre: genre,
      year: year,
      composer: isUntagged ? null : composer,
      comment: comment,
      trackNumber: isUntagged ? null : trackNumber,
      discNumber: isUntagged ? null : discNumber,
      durationMS: durationMS,
      sizeBytes: sizeBytes,
      dateAddedMS: dateAddedMS,
      dateModifiedMS: dateModifiedMS,
      rating: rating,
      isUntagged: isUntagged,
    );
  }

  String? _album() {
    final roll = _random.nextDouble();
    if (roll < 0.08) return null;
    if (roll >= 0.11) return _pick(_albums);
    final first = _pick(_albums);
    final second = _pick(_albums);
    return '$first; $second';
  }

  String? _composer() {
    final roll = _random.nextDouble();
    if (roll < 0.18) return _pick(_composers);
    if (roll >= 0.25) return null;
    final first = _pick(_composers);
    final second = _pick(_composers);
    return '$first, $second';
  }
}

class BenchResult {
  final String name;
  final int samplesCount;
  final double medianMS;
  final double minMS;
  final double maxMS;
  final double iqrMS;

  factory BenchResult(String name, List<int> samplesMicros) {
    samplesMicros.sort();
    final p25 = _percentile(samplesMicros, 0.25);
    final p75 = _percentile(samplesMicros, 0.75);
    return BenchResult._(
      name: name,
      samplesCount: samplesMicros.length,
      medianMS: _percentile(samplesMicros, 0.5) / 1000,
      minMS: samplesMicros.first / 1000,
      maxMS: samplesMicros.last / 1000,
      iqrMS: (p75 - p25) / 1000,
    );
  }

  const BenchResult._({
    required this.name,
    required this.samplesCount,
    required this.medianMS,
    required this.minMS,
    required this.maxMS,
    required this.iqrMS,
  });

  static double _percentile(List<int> sortedMicros, double fraction) {
    final position = (sortedMicros.length - 1) * fraction;
    final lowIndex = position.floor();
    final highIndex = position.ceil();
    final low = sortedMicros[lowIndex];
    final high = sortedMicros[highIndex];
    return low + (high - low) * (position - lowIndex);
  }

  String toLine() {
    return '$name|median=${medianMS.toStringAsFixed(3)}|min=${minMS.toStringAsFixed(3)}|max=${maxMS.toStringAsFixed(3)}|iqr=${iqrMS.toStringAsFixed(3)}|n=$samplesCount';
  }
}

class BenchDigest {
  int _hash = 0x811c9dc5;
  int count = 0;

  void add(String text) {
    var hash = _hash;
    for (int i = 0; i < text.length; i++) {
      hash ^= text.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    hash ^= 0x0A;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
    _hash = hash;
    count++;
  }

  String toHex() => _hash.toRadixString(16).padLeft(8, '0');
}

class SyntheticTrack {
  final String path;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final String? year;
  final String? composer;
  final String? comment;
  final String? trackNumber;
  final String? discNumber;
  final int durationMS;
  final int sizeBytes;
  final int dateAddedMS;
  final int dateModifiedMS;
  final double rating;
  final bool isUntagged;

  const SyntheticTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.genre,
    required this.year,
    required this.composer,
    required this.comment,
    required this.trackNumber,
    required this.discNumber,
    required this.durationMS,
    required this.sizeBytes,
    required this.dateAddedMS,
    required this.dateModifiedMS,
    required this.rating,
    required this.isUntagged,
  });

  int? _parseYearNumber() {
    final year = this.year;
    if (year == null || year.length < 4) return null;
    final dotIndex = year.lastIndexOf('.');
    final yearDigits = dotIndex >= 0 ? year.substring(dotIndex + 1) : year.substring(0, 4);
    return int.tryParse(yearDigits);
  }

  Map<String, dynamic> toStoredRow() {
    final title = this.title ?? '';
    final artist = this.artist ?? 'Unknown Artist';
    final album = this.album ?? '';
    final albumArtist = this.albumArtist ?? '';
    final genre = this.genre ?? 'Unknown Genre';
    final yearText = this.year ?? '';
    final yearNumber = _parseYearNumber();
    final composer = this.composer ?? 'Unknown Composer';
    final comment = this.comment ?? '';
    final trackNoText = trackNumber?.split('/').first ?? '';
    final trackNo = int.tryParse(trackNoText);
    final albums = album.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final albumsWrappers = albums.map((e) => {'album': e, 'albumArtist': albumArtist, 'year': yearText}).toFixedList();
    return {
      if (title.isNotEmpty) 'title': title,
      if (artist.isNotEmpty) 'originalArtist': artist,
      'originalAlbum': album.isEmpty ? 'Unknown Album' : album,
      if (albumArtist.isNotEmpty) 'albumArtist': albumArtist,
      if (genre.isNotEmpty) 'originalGenre': genre,
      if (composer.isNotEmpty) 'composer': composer,
      'trackNo': ?trackNo,
      'durationMS': durationMS,
      'year': ?yearNumber,
      if (yearText.isNotEmpty) 'yearText': yearText,
      'size': sizeBytes,
      'dateAdded': dateAddedMS,
      'dateModified': dateModifiedMS,
      if (comment.isNotEmpty) 'comment': comment,
      'bitrate': 320,
      'sampleRate': 44100,
      'bits': 16,
      'format': 'MPEG',
      'channels': 'stereo',
      if (rating > 0) 'rating': rating,
      if (albumsWrappers.isNotEmpty) 'albumsIdentifiersWrappers': albumsWrappers,
    };
  }
}
