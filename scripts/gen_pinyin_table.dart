// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Generates `pinyin.bin` for the romanization bundle from https://github.com/mozillazg/pinyin-data (`pinyin.txt`).
///
/// layout: [u32 syllablesByteLength (even)][utf8 syllables joined by \n][u16 syllableIndex+1 for each of U+3400..U+9FFF]
///
/// usage: `dart scripts/gen_pinyin_table.dart pinyin.txt pinyin.bin`
///
/// by claude
void main(List<String> args) {
  const rangeStart = 0x3400;
  const rangeEnd = 0x9FFF;

  final syllables = <String, int>{};
  final table = Uint16List(rangeEnd - rangeStart + 1);

  for (final line in File(args[0]).readAsLinesSync()) {
    if (!line.startsWith('U+')) continue;
    final colon = line.indexOf(':');
    final code = int.parse(line.substring(2, colon), radix: 16);
    if (code < rangeStart || code > rangeEnd) continue;
    var end = line.indexOf('#', colon);
    if (end < 0) end = line.length;
    final first = line.substring(colon + 1, end).trim().split(',').first.trim();
    if (first.isEmpty) continue;
    table[code - rangeStart] = syllables[first] ??= syllables.length + 1;
  }

  final syllablesBytes = utf8.encode(syllables.keys.join('\n'));
  final paddedLength = syllablesBytes.length + (syllablesBytes.length & 1);

  final builder = BytesBuilder(copy: false)
    ..add((ByteData(4)..setUint32(0, paddedLength, Endian.little)).buffer.asUint8List())
    ..add(syllablesBytes);
  if (paddedLength != syllablesBytes.length) builder.addByte(0x0A);
  builder.add(table.buffer.asUint8List());

  File(args[1]).writeAsBytesSync(builder.takeBytes());
  print('syllables: ${syllables.length}, chars: ${table.where((e) => e != 0).length}, bytes: ${File(args[1]).lengthSync()}');
}
