part of 'romanizer_engine.dart';

/// greek, cyrillic, armenian & georgian. upper case is resolved through the lower case entry.
const _alphabeticTable = <int, String>{
  // -- greek
  0x03B1: 'a', 0x03B2: 'v', 0x03B3: 'g', 0x03B4: 'd', 0x03B5: 'e', 0x03B6: 'z', 0x03B7: 'i', 0x03B8: 'th', 0x03B9: 'i', 0x03BA: 'k', 0x03BB: 'l', 0x03BC: 'm', //
  0x03BD: 'n', 0x03BE: 'x', 0x03BF: 'o', 0x03C0: 'p', 0x03C1: 'r', 0x03C2: 's', 0x03C3: 's', 0x03C4: 't', 0x03C5: 'y', 0x03C6: 'f', 0x03C7: 'ch', 0x03C8: 'ps', 0x03C9: 'o', //
  0x03AC: 'a', 0x03AD: 'e', 0x03AE: 'i', 0x03AF: 'i', 0x03CC: 'o', 0x03CD: 'y', 0x03CE: 'o', 0x03CA: 'i', 0x03CB: 'y', 0x0390: 'i', 0x03B0: 'y', //
  // -- cyrillic
  0x0430: 'a', 0x0431: 'b', 0x0432: 'v', 0x0433: 'g', 0x0434: 'd', 0x0435: 'e', 0x0451: 'yo', 0x0436: 'zh', 0x0437: 'z', 0x0438: 'i', 0x0439: 'y', 0x043A: 'k', //
  0x043B: 'l', 0x043C: 'm', 0x043D: 'n', 0x043E: 'o', 0x043F: 'p', 0x0440: 'r', 0x0441: 's', 0x0442: 't', 0x0443: 'u', 0x0444: 'f', 0x0445: 'kh', 0x0446: 'ts', //
  0x0447: 'ch', 0x0448: 'sh', 0x0449: 'shch', 0x044A: '', 0x044B: 'y', 0x044C: '', 0x044D: 'e', 0x044E: 'yu', 0x044F: 'ya', //
  0x0456: 'i', 0x0457: 'yi', 0x0454: 'ye', 0x0491: 'g', 0x045E: 'u', 0x0458: 'j', 0x0459: 'lj', 0x045A: 'nj', 0x045B: 'c', 0x0452: 'dj', 0x045F: 'dz', 0x0455: 'dz', //
  0x0453: 'g', 0x045C: 'k', 0x04D9: 'a', 0x0493: 'g', 0x049B: 'q', 0x04A3: 'n', 0x04E9: 'o', 0x04B1: 'u', 0x04AF: 'u', 0x04BB: 'h', //
  // -- armenian
  0x0561: 'a', 0x0562: 'b', 0x0563: 'g', 0x0564: 'd', 0x0565: 'e', 0x0566: 'z', 0x0567: 'e', 0x0568: 'y', 0x0569: 't', 0x056A: 'zh', 0x056B: 'i', 0x056C: 'l', //
  0x056D: 'kh', 0x056E: 'ts', 0x056F: 'k', 0x0570: 'h', 0x0571: 'dz', 0x0572: 'gh', 0x0573: 'ch', 0x0574: 'm', 0x0575: 'y', 0x0576: 'n', 0x0577: 'sh', 0x0578: 'o', //
  0x0579: 'ch', 0x057A: 'p', 0x057B: 'j', 0x057C: 'r', 0x057D: 's', 0x057E: 'v', 0x057F: 't', 0x0580: 'r', 0x0581: 'ts', 0x0582: 'w', 0x0583: 'p', 0x0584: 'k', //
  0x0585: 'o', 0x0586: 'f', 0x0587: 'ev', //
  // -- georgian
  0x10D0: 'a', 0x10D1: 'b', 0x10D2: 'g', 0x10D3: 'd', 0x10D4: 'e', 0x10D5: 'v', 0x10D6: 'z', 0x10D7: 't', 0x10D8: 'i', 0x10D9: 'k', 0x10DA: 'l', 0x10DB: 'm', //
  0x10DC: 'n', 0x10DD: 'o', 0x10DE: 'p', 0x10DF: 'zh', 0x10E0: 'r', 0x10E1: 's', 0x10E2: 't', 0x10E3: 'u', 0x10E4: 'p', 0x10E5: 'k', 0x10E6: 'gh', 0x10E7: 'q', //
  0x10E8: 'sh', 0x10E9: 'ch', 0x10EA: 'ts', 0x10EB: 'dz', 0x10EC: 'ts', 0x10ED: 'ch', 0x10EE: 'kh', 0x10EF: 'j', 0x10F0: 'h',
};

const _greekOmicron = 0x03BF;
const _greekUpsilon = 0x03C5;

bool _isAlphabeticScript(int c) => (c >= 0x0370 && c <= 0x058F) || (c >= 0x10D0 && c <= 0x10FF);

String _romanizeAlphabetic(String text) {
  final buffer = StringBuffer();
  final length = text.length;
  var previousLower = 0;
  for (var i = 0; i < length; i++) {
    final c = text.codeUnitAt(i);
    if (!_isAlphabeticScript(c)) {
      buffer.writeCharCode(c);
      previousLower = 0;
      continue;
    }

    var lower = c;
    var romanized = _alphabeticTable[c];
    if (romanized == null) {
      lower = String.fromCharCode(c).toLowerCase().codeUnitAt(0);
      romanized = _alphabeticTable[lower];
      if (romanized == null) {
        buffer.writeCharCode(c);
        previousLower = 0;
        continue;
      }
    }
    if (lower == _greekUpsilon && previousLower == _greekOmicron) romanized = 'u';

    if (lower == c || romanized.isEmpty) {
      buffer.write(romanized);
    } else {
      final next = i + 1 < length ? text.codeUnitAt(i + 1) : 0;
      final isAllCaps = romanized.length > 1 && _isAlphabeticScript(next) && _alphabeticTable[next] == null;
      buffer.write(isAllCaps ? romanized.toUpperCase() : romanized[0].toUpperCase() + romanized.substring(1));
    }
    previousLower = lower;
  }
  return buffer.toString();
}
