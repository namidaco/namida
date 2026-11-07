// by claude
part of 'json_to_history_parser.dart';

/// one listen is spread over several `PLAY_END` rows (pauses, scrubs), they are merged back and counted like a local listen.
class _AppleMusicPlayActivityParser {
  static final _kPlayEnd = ascii.encode('PLAY_END');
  static final _kScrubEnd = ascii.encode('SCRUB_END');
  static final _kLeavingEndReasons = [
    'NATURAL_END_OF_TRACK', 'TRACK_SKIPPED_FORWARDS', 'TRACK_SKIPPED_BACKWARDS', 'MANUALLY_SELECTED_PLAYBACK_OF_A_DIFF_ITEM', //
  ].map(ascii.encode).toFixedList();

  static List<_AppleMusicListen> parse(File file, _ListenCountRule rule) {
    final segments = _readSegments(file);
    segments.sort(_compareSegments);
    return _mergeSegments(segments, rule);
  }

  static List<_AppleMusicPlaySegment> _readSegments(File file) {
    final segments = <_AppleMusicPlaySegment>[];
    final headers = _PlayActivityColumn.values.map((e) => e.header).toFixedList();
    _CsvColumnsReader.read(file, headers, (row) {
      if (!row.equals(_PlayActivityColumn.eventType.index, _kPlayEnd)) return;
      // -- the scrub jump itself, its duration is the skipped span
      if (row.equals(_PlayActivityColumn.endReason.index, _kScrubEnd)) return;

      final playedMS = row.integer(_PlayActivityColumn.playDuration.index) ?? 0;
      if (playedMS <= 0) return;
      final title = row.string(_PlayActivityColumn.songName.index);
      if (title.isEmpty) return;

      int? startMS = row.utcDateMS(_PlayActivityColumn.eventStart.index);
      if (startMS == null) {
        final endMS = row.utcDateMS(_PlayActivityColumn.eventEnd.index);
        if (endMS == null) return;
        startMS = endMS - playedMS;
      }

      final album = row.string(_PlayActivityColumn.albumName.index);
      final durationMS = row.integer(_PlayActivityColumn.mediaDuration.index) ?? 0;
      final startPositionMS = row.integer(_PlayActivityColumn.startPosition.index) ?? 0;
      final endPositionMS = row.integer(_PlayActivityColumn.endPosition.index) ?? 0;
      final isLeavingTrack = row.equalsAny(_PlayActivityColumn.endReason.index, _kLeavingEndReasons);
      segments.add(
        _AppleMusicPlaySegment(
          title: title,
          album: album,
          durationMS: durationMS,
          startMS: startMS,
          playedMS: playedMS,
          startPositionMS: startPositionMS,
          endPositionMS: endPositionMS,
          isLeavingTrack: isLeavingTrack,
        ),
      );
    });
    return segments;
  }

  /// same start: shorter first, a scrub ends one segment and starts the next at the same ms.
  static int _compareSegments(_AppleMusicPlaySegment a, _AppleMusicPlaySegment b) {
    final byStart = a.startMS.compareTo(b.startMS);
    if (byStart != 0) return byStart;
    return a.playedMS.compareTo(b.playedMS);
  }

  /// dated when the required time is reached, like local listens.
  static List<_AppleMusicListen> _mergeSegments(List<_AppleMusicPlaySegment> segments, _ListenCountRule rule) {
    final listens = <_AppleMusicListen>[];
    _AppleMusicPlaySegment? previous;
    int listenedMS = 0;
    bool isCounted = false;

    for (final segment in segments) {
      final isNewListen =
          previous == null ||
          previous.isLeavingTrack ||
          !segment.isSameTrack(previous) ||
          (isCounted && rule.isRestart(previousEndMS: previous.endPositionMS, startMS: segment.startPositionMS, durationMS: segment.durationMS));
      if (isNewListen) {
        listenedMS = 0;
        isCounted = false;
      }

      final requiredMS = rule.requiredListenMS(segment.durationMS);
      final listenedBeforeMS = listenedMS;
      listenedMS += segment.playedMS;
      if (!isCounted && listenedMS >= requiredMS) {
        isCounted = true;
        final remainingMS = (requiredMS - listenedBeforeMS).withMinimum(0);
        final countedAtMS = segment.startMS + remainingMS;
        listens.add(
          _AppleMusicListen(
            title: segment.title,
            album: segment.album,
            durationMS: segment.durationMS,
            dateMS: countedAtMS,
          ),
        );
      }
      previous = segment;
    }
    return listens;
  }
}

/// play activity has no artist, it comes from the library json, then from the daily tracks csv (`Artist - Title` per day).
class _AppleMusicLookup {
  static const _kSameRecordingMaxDiffMS = 2000;
  static const _kDescriptionSeparator = ' - ';

  final _libraryTracksByTitle = <String, List<_AppleMusicLibraryTrack>>{};
  final _playedArtistsDaysByTitle = <String, Map<String, Set<int>>>{};
  final _favouritesByPath = <String, List<_GeneralSourceItemInfo>>{};

  _AppleMusicLookup.fromFiles(List<File> files, {required int importTimeMS}) {
    for (final file in files) {
      if (NamidaFileExtensionsWrapper.json.isPathValid(file.path)) {
        _addLibrary(file, importTimeMS);
      } else {
        _addDailyTracks(file);
      }
    }
  }

  List<_GeneralSourceItemInfo> favouritesOf(File file) => _favouritesByPath[file.path] ?? const [];

  String artistOf(_AppleMusicListen listen) => _libraryArtistOf(listen) ?? _playedArtistOf(listen) ?? '';

  void _addLibrary(File file, int importTimeMS) {
    final favourites = <_GeneralSourceItemInfo>[];
    final library = file.readAsJsonSync() as List? ?? const [];
    for (final map in library) {
      try {
        final title = map['Title'] as String?;
        final artist = map['Artist'] as String?;
        if (title == null || artist == null) continue;
        final album = map['Album'] as String? ?? '';
        final durationMS = map['Track Duration'] as int? ?? 0;
        final track = _AppleMusicLibraryTrack(
          album: album,
          artist: artist,
          durationMS: durationMS,
        );
        _libraryTracksByTitle.addForce(title, track);

        // -- `Track Like Rating` is from before favourites replaced loves
        final isFavourite = map['Favorite Status - Track'] == true || map['Track Like Rating'] == 'liked';
        if (!isFavourite) continue;
        final favouriteDate = map['Favorite Date - Track'] as String?;
        final favouriteDateMS = favouriteDate == null ? importTimeMS : DateTime.parse(favouriteDate).millisecondsSinceEpoch;
        favourites.add(
          _GeneralSourceItemInfo(
            itemArtist: artist,
            itemTitle: title,
            dateMSSE: favouriteDateMS,
          ),
        );
      } catch (_) {}
    }
    _favouritesByPath[file.path] = favourites;
  }

  void _addDailyTracks(File file) {
    final headers = _DailyTracksColumn.values.map((e) => e.header).toFixedList();
    _CsvColumnsReader.read(file, headers, (row) {
      final description = row.string(_DailyTracksColumn.trackDescription.index);
      final datePlayed = row.integer(_DailyTracksColumn.datePlayed.index);
      if (datePlayed == null) return;
      final year = datePlayed ~/ 10000;
      final month = datePlayed ~/ 100 % 100;
      final dayOfMonth = datePlayed % 100;
      final dateUtc = DateTime.utc(year, month, dayOfMonth);
      final day = dateUtc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

      // -- artists and titles can hold the separator too, every split is kept
      int separatorIndex = description.indexOf(_kDescriptionSeparator);
      while (separatorIndex > 0) {
        final artist = description.substring(0, separatorIndex);
        final title = description.substring(separatorIndex + _kDescriptionSeparator.length);
        final artistsDays = _playedArtistsDaysByTitle[title] ??= {};
        final days = artistsDays[artist] ??= {};
        days.add(day);
        separatorIndex = description.indexOf(_kDescriptionSeparator, separatorIndex + 1);
      }
    });
  }

  /// same album first, then the closest duration, another album only when it's the same recording.
  String? _libraryArtistOf(_AppleMusicListen listen) {
    final tracks = _libraryTracksByTitle[listen.title];
    if (tracks == null) return null;

    var closest = tracks.first;
    var closestDiffMS = (closest.durationMS - listen.durationMS).abs();
    var isClosestSameAlbum = closest.album == listen.album;
    for (int i = 1; i < tracks.length; i++) {
      final tr = tracks[i];
      final isSameAlbum = tr.album == listen.album;
      if (isClosestSameAlbum && !isSameAlbum) continue;
      final diffMS = (tr.durationMS - listen.durationMS).abs();
      final isCloser = (isSameAlbum && !isClosestSameAlbum) || diffMS < closestDiffMS;
      if (!isCloser) continue;
      closest = tr;
      closestDiffMS = diffMS;
      isClosestSameAlbum = isSameAlbum;
    }

    if (!isClosestSameAlbum && closestDiffMS > _kSameRecordingMaxDiffMS) return null;
    return closest.artist;
  }

  String? _playedArtistOf(_AppleMusicListen listen) {
    final artistsDays = _playedArtistsDaysByTitle[listen.title];
    if (artistsDays == null) return null;
    final day = listen.dateMS ~/ Duration.millisecondsPerDay;
    for (final e in artistsDays.entries) {
      if (e.value.contains(day)) return e.key;
    }
    return artistsDays.length == 1 ? artistsDays.keys.first : null;
  }
}

/// keeps only the [columns] asked for, a column missing from the header reads as empty.
class _CsvColumnsReader {
  static const _kChunkSize = 1 << 20;
  static const _kQuote = 0x22;
  static const _kComma = 0x2C;
  static const _kLF = 0x0A;
  static const _kCR = 0x0D;
  static const _kBom = '﻿';

  final List<String> _columns;
  final void Function(_CsvRow row) _onRow;
  final _CsvRow _row;
  final _headerNames = <String>[];
  var _slotOfColumn = Int32List(0);
  bool _isHeader = true;
  bool _isQuoted = false;
  bool _wasQuoteClosed = false;
  bool _hasRowContent = false;
  int _column = 0;
  int _slot = 0;

  _CsvColumnsReader._(this._columns, this._onRow) : _row = _CsvRow(_columns.length);

  static void read(File file, List<String> columns, void Function(_CsvRow row) onRow) {
    final reader = _CsvColumnsReader._(columns, onRow);
    final raf = file.openSync();
    try {
      final chunk = Uint8List(_kChunkSize);
      while (true) {
        final readCount = raf.readIntoSync(chunk);
        if (readCount == 0) break;
        reader._addBytes(chunk, readCount);
      }
      if (reader._hasRowContent) reader._endRow();
    } finally {
      raf.closeSync();
    }
  }

  void _addBytes(Uint8List bytes, int length) {
    final row = _row;
    bool isQuoted = _isQuoted;
    bool wasQuoteClosed = _wasQuoteClosed;
    bool hasRowContent = _hasRowContent;
    int slot = _slot;
    for (int i = 0; i < length; i++) {
      final b = bytes[i];
      if (isQuoted) {
        if (b == _kQuote) {
          isQuoted = false;
          wasQuoteClosed = true;
        } else if (slot >= 0) {
          row._add(b);
        }
        continue;
      }
      if (b == _kQuote) {
        // -- a doubled quote inside a quoted field is a literal one
        if (wasQuoteClosed && slot >= 0) row._add(b);
        isQuoted = true;
        wasQuoteClosed = false;
        hasRowContent = true;
        continue;
      }
      wasQuoteClosed = false;
      if (b == _kComma) {
        hasRowContent = true;
        _endField();
        _startField(_column + 1);
        slot = _slot;
      } else if (b == _kLF) {
        if (!hasRowContent) continue;
        _endRow();
        hasRowContent = false;
        slot = _slot;
      } else if (b != _kCR) {
        hasRowContent = true;
        if (slot >= 0) row._add(b);
      }
    }
    _isQuoted = isQuoted;
    _wasQuoteClosed = wasQuoteClosed;
    _hasRowContent = hasRowContent;
  }

  void _startField(int column) {
    _column = column;
    final slot = _isHeader ? 0 : _slotOf(column);
    _slot = slot;
    if (slot >= 0) _row._starts[slot] = _row._length;
  }

  int _slotOf(int column) => column < _slotOfColumn.length ? _slotOfColumn[column] : -1;

  void _endField() {
    final slot = _slot;
    if (slot < 0) return;
    _row._ends[slot] = _row._length;
    if (_isHeader) {
      _headerNames.add(_row.string(0));
      _row._length = 0;
    }
  }

  void _endRow() {
    _endField();
    if (_isHeader) {
      _onHeader();
    } else {
      _onRow(_row);
    }
    _row._reset();
    _hasRowContent = false;
    _startField(0);
  }

  void _onHeader() {
    final names = _headerNames;
    if (names.first.startsWith(_kBom)) names[0] = names.first.substring(_kBom.length);
    final slotOfColumn = Int32List(names.length)..fillRange(0, names.length, -1);
    for (int slot = 0; slot < _columns.length; slot++) {
      final column = names.indexOf(_columns[slot]);
      if (column >= 0) slotOfColumn[column] = slot;
    }
    _slotOfColumn = slotOfColumn;
    _isHeader = false;
  }
}

class _CsvRow {
  static const _kZero = 0x30;
  static const _kMinus = 0x2D;
  static const _kDot = 0x2E;
  static const _kT = 0x54;
  static const _kZ = 0x5A;

  var _bytes = Uint8List(1024);
  int _length = 0;
  final Int32List _starts;
  final Int32List _ends;

  _CsvRow(int slotsCount) : _starts = Int32List(slotsCount), _ends = Int32List(slotsCount);

  void _add(int byte) {
    if (_length == _bytes.length) _grow();
    _bytes[_length++] = byte;
  }

  void _grow() {
    final bytes = Uint8List(_bytes.length * 2);
    bytes.setRange(0, _length, _bytes);
    _bytes = bytes;
  }

  void _reset() {
    _length = 0;
    _starts.fillRange(0, _starts.length, 0);
    _ends.fillRange(0, _ends.length, 0);
  }

  bool equals(int slot, Uint8List ascii) {
    final start = _starts[slot];
    if (_ends[slot] - start != ascii.length) return false;
    for (int i = 0; i < ascii.length; i++) {
      if (_bytes[start + i] != ascii[i]) return false;
    }
    return true;
  }

  bool equalsAny(int slot, List<Uint8List> asciis) {
    for (final ascii in asciis) {
      if (equals(slot, ascii)) return true;
    }
    return false;
  }

  String string(int slot) {
    final bytes = Uint8List.sublistView(_bytes, _starts[slot], _ends[slot]);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// the integer part, decimals are dropped.
  int? integer(int slot) {
    final end = _ends[slot];
    int i = _starts[slot];
    if (i == end) return null;
    final isNegative = _bytes[i] == _kMinus;
    if (isNegative) i++;
    int value = 0;
    for (; i < end; i++) {
      final digit = _bytes[i] - _kZero;
      if (digit < 0 || digit > 9) break;
      value = value * 10 + digit;
    }
    return isNegative ? -value : value;
  }

  /// `yyyy-MM-ddTHH:mm:ss(.SSS)Z` is read in place, anything else goes through [DateTime.tryParse].
  int? utcDateMS(int slot) {
    final start = _starts[slot];
    final end = _ends[slot];
    if (start == end) return null;
    final bytes = _bytes;
    final length = end - start;
    final isUtcIso = length >= 20 && bytes[start + 10] == _kT && bytes[end - 1] == _kZ && (length == 20 || bytes[start + 19] == _kDot);
    if (!isUtcIso) {
      final text = string(slot);
      return DateTime.tryParse(text)?.millisecondsSinceEpoch;
    }

    final year = _digitsAt(start, 4);
    final month = _digitsAt(start + 5, 2);
    final day = _digitsAt(start + 8, 2);
    final hour = _digitsAt(start + 11, 2);
    final minute = _digitsAt(start + 14, 2);
    final second = _digitsAt(start + 17, 2);
    int millisecond = 0;
    int scale = 100;
    for (int i = start + 20; i < end - 1; i++) {
      millisecond += (bytes[i] - _kZero) * scale;
      scale ~/= 10;
    }
    final date = DateTime.utc(year, month, day, hour, minute, second, millisecond);
    return date.millisecondsSinceEpoch;
  }

  int _digitsAt(int index, int count) {
    int value = 0;
    for (int i = index; i < index + count; i++) {
      value = value * 10 + _bytes[i] - _kZero;
    }
    return value;
  }
}

extension _ListenCountRuleUtils on _ListenCountRule {
  /// enough seconds or enough of the track, like a local listen.
  int requiredListenMS(int durationMS) {
    final secondsMS = minListenSeconds * 1000;
    if (durationMS <= 0) return secondsMS;
    final percentageMS = durationMS * minListenPercentage ~/ 100;
    return secondsMS.withMaximum(percentageMS);
  }

  /// like seeking locally after a listen was marked: back to the start, or back by a quarter of the track.
  bool isRestart({required int previousEndMS, required int startMS, required int durationMS}) {
    if (startMS >= previousEndMS) return false;
    final restartThresholdMS = isSeekPercentage ? durationMS * seekPercentage ~/ 100 : seekSeconds * 1000;
    if (startMS <= restartThresholdMS) return true;
    return durationMS > 0 && (previousEndMS - startMS) * 4 >= durationMS;
  }
}

class _AppleMusicPlaySegment {
  final String title;
  final String album;
  final int durationMS;
  final int startMS;
  final int playedMS;
  final int startPositionMS;
  final int endPositionMS;
  final bool isLeavingTrack;

  const _AppleMusicPlaySegment({
    required this.title,
    required this.album,
    required this.durationMS,
    required this.startMS,
    required this.playedMS,
    required this.startPositionMS,
    required this.endPositionMS,
    required this.isLeavingTrack,
  });

  bool isSameTrack(_AppleMusicPlaySegment other) => title == other.title && album == other.album && durationMS == other.durationMS;
}

class _AppleMusicListen {
  final String title;
  final String album;
  final int durationMS;
  final int dateMS;

  const _AppleMusicListen({
    required this.title,
    required this.album,
    required this.durationMS,
    required this.dateMS,
  });
}

class _AppleMusicLibraryTrack {
  final String album;
  final String artist;
  final int durationMS;

  const _AppleMusicLibraryTrack({
    required this.album,
    required this.artist,
    required this.durationMS,
  });
}

enum _PlayActivityColumn {
  songName('Song Name'),
  albumName('Album Name'),
  eventType('Event Type'),
  endReason('End Reason Type'),
  eventStart('Event Start Timestamp'),
  eventEnd('Event End Timestamp'),
  playDuration('Play Duration Milliseconds'),
  mediaDuration('Media Duration In Milliseconds'),
  startPosition('Start Position In Milliseconds'),
  endPosition('End Position In Milliseconds'),
  ;

  final String header;
  const _PlayActivityColumn(this.header);
}

enum _DailyTracksColumn {
  trackDescription('Track Description'),
  datePlayed('Date Played'),
  ;

  final String header;
  const _DailyTracksColumn(this.header);
}

typedef _ListenCountRule = ({int minListenSeconds, int minListenPercentage, int seekSeconds, int seekPercentage, bool isSeekPercentage});
