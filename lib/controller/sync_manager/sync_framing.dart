/// _FrameWriter and _FrameReader are gnerated by claude.ai
part of 'sync_manager.dart';

class _FrameWriter {
  final Socket _socket;
  const _FrameWriter(this._socket);

  Future<void> sendPayload(List<int> payload) async {
    add(payload);
    await flush();
  }

  void add(List<int> payload) {
    final length = payload.length;
    final header = Uint8List(4)
      ..[0] = (length >> 24) & 0xFF
      ..[1] = (length >> 16) & 0xFF
      ..[2] = (length >> 8) & 0xFF
      ..[3] = length & 0xFF;
    _socket.add(header);
    _socket.add(payload);
  }

  Future<void> flush() => _socket.flush();
}

// can be far more simpler, but this version has max performance
class _FrameReader {
  Stream<Uint8List> get frames => _streamController.stream;
  RxBaseCore<(int, int)?> get currentProgress => _currentProgressRx;

  final _streamController = StreamController<Uint8List>();
  final _currentProgressRx = Rxn<(int, int)>();

  static const _initialCapacity = 4096;
  static const _maxHeaderPreallocation = 256 * 1024 * 1024;

  Uint8List _buf = Uint8List(_initialCapacity);
  int _writePos = 0; // how many bytes are in the buffer
  int _readPos = 0; // how far we've consumed
  int _expectedLength = -1;

  int get _available => _writePos - _readPos;

  void addBytes(Uint8List data) {
    _ensureCapacity(data.length);

    _buf.setRange(_writePos, _writePos + data.length, data);
    _writePos += data.length;
    _process();

    if (_expectedLength != -1) {
      _currentProgressRx.value = (_available, _expectedLength);
    } else {
      _currentProgressRx.value = null;
    }
  }

  void _ensureCapacity(int incoming) {
    final needed = _writePos + incoming;
    if (needed <= _buf.length) return;

    // compact first (shift unread bytes to front)
    if (_readPos > 0) {
      _buf.setRange(0, _available, _buf, _readPos);
      _writePos = _available;
      _readPos = 0;
      if (_writePos + incoming <= _buf.length) return;
    }

    // grow
    var newSize = _buf.length * 2;
    while (newSize < _writePos + incoming) {
      newSize *= 2;
    }
    final newBuf = Uint8List(newSize);
    newBuf.setRange(0, _writePos, _buf);
    _buf = newBuf;
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
          _ensureCapacity(toPreallocate);
        }
      }

      if (_available < _expectedLength) return;

      // zero-copy view into the buffer
      final payload = Uint8List.sublistView(_buf, _readPos, _readPos + _expectedLength);
      _streamController.add(payload);
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
