part of 'romanizer_engine.dart';

const _hangulInitials = ['g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '', 'j', 'jj', 'ch', 'k', 't', 'p', 'h'];
const _hangulMedials = ['a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', 'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i'];
const _hangulFinals = ['', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'l', 'l', 'l', 'p', 'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't'];

/// finals when followed by a vowel-initial syllable.
const _hangulFinalsLinked = ['', 'g', 'kk', 'ks', 'n', 'nj', 'n', 'd', 'r', 'lg', 'lm', 'lb', 'ls', 'lt', 'lp', 'r', 'm', 'b', 'ps', 's', 'ss', 'ng', 'j', 'ch', 'k', 't', 'p', ''];

const _hangulStart = 0xAC00;
const _hangulEnd = 0xD7A3;
const _hangulInitialSilent = 11;
const _hangulInitialR = 5;
const _hangulFinalL = 8;

String _romanizeHangul(String text) {
  final buffer = StringBuffer();
  final length = text.length;
  var previousFinal = -1;
  for (var i = 0; i < length; i++) {
    final c = text.codeUnitAt(i);
    if (c < _hangulStart || c > _hangulEnd) {
      buffer.writeCharCode(c);
      previousFinal = -1;
      continue;
    }
    final index = c - _hangulStart;
    final initial = index ~/ 588;
    final medial = (index % 588) ~/ 28;
    final finalIndex = index % 28;

    var nextInitial = -1;
    if (i + 1 < length) {
      final next = text.codeUnitAt(i + 1);
      if (next >= _hangulStart && next <= _hangulEnd) nextInitial = (next - _hangulStart) ~/ 588;
    }

    buffer.write(initial == _hangulInitialR && previousFinal == _hangulFinalL ? 'l' : _hangulInitials[initial]);
    buffer.write(_hangulMedials[medial]);
    buffer.write(nextInitial == _hangulInitialSilent ? _hangulFinalsLinked[finalIndex] : _hangulFinals[finalIndex]);
    previousFinal = finalIndex;
  }
  return buffer.toString();
}
