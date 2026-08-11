/// _FrameWriter and _FrameReader are gnerated by claude.ai
part of 'sync_manager.dart';

class _FrameWriter {
  final Socket _socket;
  const _FrameWriter(this._socket);

  /// the frame payload is a utf8 json message.
  static const kFrameKindJson = 0;

  /// the frame payload is raw bytes belonging to the preceding
  /// [BinaryPayloadMessage] json frame.
  static const kFrameKindBinary = 1;

  /// bytes preceding each frame payload: 4 length bytes + 1 kind byte.
  static const kFrameHeaderSize = 5;

  /// sends the message json frame, followed by a raw binary frame
  /// if the message carries a binary payload.
  ///
  /// returns the total bytes written, including frame headers.
  Future<int> sendMessage(BaseMessage message) async {
    final jsonBytes = message.encodeBytes();
    add(jsonBytes, kFrameKindJson);
    int totalBytes = kFrameHeaderSize + jsonBytes.length;
    final binaryPayload = message is BinaryPayloadMessage ? message.binaryPayload : null;
    if (binaryPayload != null) {
      add(binaryPayload, kFrameKindBinary);
      totalBytes += kFrameHeaderSize + binaryPayload.length;
    }
    await flush();
    return totalBytes;
  }

  void add(List<int> payload, int kind) {
    final length = payload.length + 1; // -- +1 for the kind byte
    final header = Uint8List(kFrameHeaderSize)
      ..[0] = (length >> 24) & 0xFF
      ..[1] = (length >> 16) & 0xFF
      ..[2] = (length >> 8) & 0xFF
      ..[3] = length & 0xFF
      ..[4] = kind;
    _socket.add(header);
    _socket.add(payload);
  }

  Future<void> flush() => _socket.flush();
}

// can be far more simpler, but this version has max performance
class _FrameReader {
  /// `(kind, payload)` per frame, see [_FrameWriter.kFrameKindJson] & [_FrameWriter.kFrameKindBinary].
  ///
  /// json payloads are zero-copy views into the reusable internal buffer,
  /// they must be consumed (or copied) synchronously by the listener.
  /// binary payloads own their bytes (the buffer is detached, see [_process]),
  /// so they are safe to keep around for async work (like file writes).
  Stream<(int, Uint8List)> get frames => _streamController.stream;
  RxBaseCore<(int, int)?> get currentProgress => _currentProgressRx;

  final _streamController = StreamController<(int, Uint8List)>();
  final _currentProgressRx = Rxn<(int, int)>();

  static const _initialCapacity = 4096;
  static const _maxHeaderPreallocation = 256 * 1024 * 1024;

  Uint8List _buf = Uint8List(_initialCapacity);
  int _writePos = 0; // how many bytes are in the buffer
  int _readPos = 0; // how far we've consumed
  int _expectedLength = -1;

  int get _available => _writePos - _readPos;

  void addBytes(Uint8List data) {
    _ensureCapacity(data.length, canShiftInPlace: true);

    _buf.setRange(_writePos, _writePos + data.length, data);
    _writePos += data.length;
    _process();

    if (_expectedLength != -1) {
      _currentProgressRx.value = (_available, _expectedLength);
    } else {
      _currentProgressRx.value = null;
    }
  }

  /// [canShiftInPlace] allows compacting by shifting unread bytes to the front
  /// of the current buffer. only safe at the start of [addBytes]: json views
  /// emitted by the previous socket event are consumed by then (microtasks drain
  /// between events). inside [_process], views emitted earlier in the same run
  /// are still queued in the stream controller and point into [_buf], so the
  /// buffer must be replaced instead of mutated (the old one stays alive for them).
  void _ensureCapacity(int incoming, {required bool canShiftInPlace}) {
    final needed = _writePos + incoming;
    if (needed <= _buf.length) return;

    if (canShiftInPlace && _readPos > 0) {
      // compact first (shift unread bytes to front)
      _buf.setRange(0, _available, _buf, _readPos);
      _writePos = _available;
      _readPos = 0;
      if (_writePos + incoming <= _buf.length) return;
    }

    // move unread bytes into a fresh (possibly bigger) buffer
    final unread = _available;
    var newSize = _buf.length;
    while (newSize < unread + incoming) {
      newSize *= 2;
    }
    final newBuf = Uint8List(newSize);
    newBuf.setRange(0, unread, _buf, _readPos);
    _buf = newBuf;
    _readPos = 0;
    _writePos = unread;
  }

  void _process() {
    while (true) {
      if (_expectedLength == -1) {
        if (_available < 4) return;
        // read header directly, zero copy
        _expectedLength = (_buf[_readPos] << 24) | (_buf[_readPos + 1] << 16) | (_buf[_readPos + 2] << 8) | _buf[_readPos + 3];
        _readPos += 4;

        var toPreallocate = _expectedLength - _available;
        if (toPreallocate > 0) {
          if (toPreallocate > _maxHeaderPreallocation) toPreallocate = _maxHeaderPreallocation;
          _ensureCapacity(toPreallocate, canShiftInPlace: false);
        }
      }

      if (_available < _expectedLength) return;

      if (_expectedLength > 0) {
        final kind = _buf[_readPos];
        final payloadStart = _readPos + 1;
        final payloadEnd = _readPos + _expectedLength;
        if (kind == _FrameWriter.kFrameKindBinary) {
          // detach the buffer instead of copying: the emitted view keeps owning
          // the old buffer (nothing else will touch it), and only the trailing
          // bytes of any pipelined next frame get copied into a fresh buffer.
          // this makes binary payloads safe for async consumption at zero cost.
          final payload = Uint8List.sublistView(_buf, payloadStart, payloadEnd);
          final trailing = _writePos - payloadEnd;
          var newSize = _initialCapacity;
          while (newSize < trailing) {
            newSize *= 2;
          }
          final newBuf = Uint8List(newSize);
          if (trailing > 0) newBuf.setRange(0, trailing, _buf, payloadEnd);
          _buf = newBuf;
          _readPos = 0;
          _writePos = trailing;
          _expectedLength = -1;
          _streamController.add((kind, payload));
          continue;
        }
        // zero-copy view into the buffer
        final payload = Uint8List.sublistView(_buf, payloadStart, payloadEnd);
        _streamController.add((kind, payload));
      }
      _readPos += _expectedLength;
      _expectedLength = -1;

      // reset positions when buffer is fully consumed
      if (_readPos == _writePos) {
        _readPos = 0;
        _writePos = 0;
      }
    }
  }

  void close() {
    if (_expectedLength != -1 && _available > 0) {
      // connection lost midway
      _streamController.addError(
        const SocketException('Connection lost before whole message was received'),
      );
    }
    _readPos = 0;
    _writePos = 0;
    _expectedLength = -1;
    _streamController.close();
  }
}

// class _FrameReaderSimple {
//   final _streamController = StreamController<Uint8List>();

//   Stream<Uint8List> get frames => _streamController.stream;

//   final _buf = BytesBuilder(copy: false);
//   int _expectedLength = -1;

//   void addBytes(List<int> data) {
//     _buf.add(data);
//     _process();
//   }

//   void _process() {
//     while (true) {
//       if (_buf.length < 4 && _expectedLength == -1) return;

//       if (_expectedLength == -1) {
//         final all = _buf.takeBytes();
//         _expectedLength = (all[0] << 24) | (all[1] << 16) | (all[2] << 8) | all[3];
//         if (all.length > 4) _buf.add(all.sublist(4));
//       }

//       // -- waiting for more data
//       if (_buf.length < _expectedLength) return;

//       final all = _buf.takeBytes();
//       final payload = Uint8List.sublistView(all, 0, _expectedLength);
//       _streamController.add(payload);
//       if (all.length > _expectedLength) {
//         _buf.add(all.sublist(_expectedLength));
//       }
//       _expectedLength = -1;
//     }
//   }

//   void close() => _streamController.close();
// }
