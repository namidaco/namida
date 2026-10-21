// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/rhythm_controller.dart';

void main() {
  group('folds into the genre convention', () {
    test('half tempo is doubled', () {
      expect(debugFoldGenreTempo(86.0, ['Drum & Bass']), 172.0);
      expect(debugFoldGenreTempo(87.0, ["Drum'n'Bass"]), 174.0);
      expect(debugFoldGenreTempo(70.0, ['Dubstep']), 140.0);
      expect(debugFoldGenreTempo(75.0, ['Euphoric Hardstyle']), 150.0);
      expect(debugFoldGenreTempo(95.0, ['Hardcore']), 190.0);
      expect(debugFoldGenreTempo(110.0, ['Frenchcore']), 220.0);
      expect(debugFoldGenreTempo(86.0, ['Liquid DnB']), 172.0);
      expect(debugFoldGenreTempo(86.0, ['D&B']), 172.0);
    });
    test('double tempo is halved', () {
      expect(debugFoldGenreTempo(280.0, ['Dubstep']), 140.0);
      expect(debugFoldGenreTempo(344.0, ['Drum and Bass']), 172.0);
    });
    test('first genre with a fitting octave wins', () {
      expect(debugFoldGenreTempo(70.0, ['Drum & Bass', 'Dubstep']), 140.0);
      expect(debugFoldGenreTempo(86.0, ['Dubstep', 'Drum & Bass']), 172.0);
    });
  });

  group('stays as analyzed', () {
    test('already in range', () {
      expect(debugFoldGenreTempo(174.0, ['Drum & Bass']), 174.0);
      expect(debugFoldGenreTempo(140.0, ['Dubstep']), 140.0);
    });
    test('in range of any of the genres', () {
      expect(debugFoldGenreTempo(140.0, ['Drum & Bass', 'Dubstep']), 140.0);
    });
    test('no octave fits', () {
      expect(debugFoldGenreTempo(128.0, ['Drum & Bass']), 128.0);
      expect(debugFoldGenreTempo(120.0, ['Hardstyle']), 120.0);
    });
    test('genres without a convention', () {
      expect(debugFoldGenreTempo(86.0, ['Hip Hop']), 86.0);
      expect(debugFoldGenreTempo(70.0, ['Trap']), 70.0);
      expect(debugFoldGenreTempo(90.0, ['Deep House']), 90.0);
      expect(debugFoldGenreTempo(86.0, []), 86.0);
    });
    test('rock forms of hardcore', () {
      expect(debugFoldGenreTempo(90.0, ['Post-Hardcore']), 90.0);
      expect(debugFoldGenreTempo(90.0, ['Melodic Hardcore']), 90.0);
    });
  });
}
