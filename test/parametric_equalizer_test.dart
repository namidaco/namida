// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart';

void main() {
  group('response', () {
    test('a peak reaches its gain at its frequency', () {
      const eq = ParametricEqualizer(bands: [EqualizerBand(id: 0, frequency: 1000, gain: 6, q: 1.41)]);
      expect(eq.responseDb(1000), closeTo(6.0, 1e-9));
      expect(eq.responseDb(20), closeTo(0.0, 0.01));
    });

    test('shelves reach their gain away from the corner', () {
      const eq = ParametricEqualizer(
        bands: [
          EqualizerBand(id: 0, type: EqualizerBandType.lowShelf, frequency: 100, gain: 6),
          EqualizerBand(id: 1, type: EqualizerBandType.highShelf, frequency: 8000, gain: -4),
        ],
      );
      expect(eq.responseDb(20), closeTo(6.0, 0.1));
      expect(eq.responseDb(1000), closeTo(0.0, 0.1));
      expect(eq.responseDb(20000), closeTo(-4.0, 0.3));
    });

    test('a 24 dB/oct high pass is butterworth, -3 dB at the cutoff', () {
      const eq = ParametricEqualizer(bands: [EqualizerBand(id: 0, type: EqualizerBandType.highPass, frequency: 100, order: 4)]);
      expect(eq.responseDb(100), closeTo(-3.01, 0.01));
      expect(eq.responseDb(50), closeTo(-24.1, 0.3));
    });

    test('channel specific bands only shape their channel', () {
      const eq = ParametricEqualizer(bands: [EqualizerBand(id: 0, frequency: 1000, gain: 3, channel: EqualizerChannel.right)]);
      expect(eq.responseDb(1000, channel: EqualizerChannel.left), 0.0);
      expect(eq.responseDb(1000, channel: EqualizerChannel.right), closeTo(3.0, 1e-9));
    });

    test('auto preamp cancels the highest boost', () {
      const eq = ParametricEqualizer(bands: [EqualizerBand(id: 0, frequency: 1000, gain: 6, q: 1.41)]);
      expect(eq.computeEffectivePreamp(), closeTo(-6.0, 0.05));
      expect(eq.copyWith(autoPreamp: false, preamp: -2.0).computeEffectivePreamp(), -2.0);
    });

    test('neutral bands are skipped', () {
      const eq = ParametricEqualizer(
        bands: [
          EqualizerBand(id: 0, frequency: 1000),
          EqualizerBand(id: 1, frequency: 2000, gain: 3, enabled: false),
        ],
      );
      expect(eq.getActiveBands(), isEmpty);
      expect(eq.computeEffectivePreamp(), 0.0);
    });
  });

  group('equalizer apo', () {
    const autoEq = '''
Preamp: -6.2 dB
Filter 1: ON LSC Fc 105 Hz Gain 6.5 dB Q 0.70
Filter 2: ON PK Fc 1500 Hz Gain -2.3 dB Q 1.20
Filter 3: OFF PK Fc 3000 Hz Gain 1 dB Q 2
Filter 4: ON HSC Fc 10000 Hz Gain -3.0 dB Q 0.70
Channel: R
Filter 5: ON PK Fc 250 Hz Gain 1.5 dB BW Oct 1.0
Filter 6: ON LP Fc 18000 Hz
''';

    test('reads autoeq files', () {
      final eq = ParametricEqualizer.fromEqualizerApo(autoEq)!;
      expect(eq.autoPreamp, false);
      expect(eq.preamp, -6.2);
      expect(eq.bands.map((b) => b.type), [
        EqualizerBandType.lowShelf,
        EqualizerBandType.peak,
        EqualizerBandType.peak,
        EqualizerBandType.highShelf,
        EqualizerBandType.peak,
        EqualizerBandType.lowPass,
      ]);
      expect(eq.bands[2].enabled, false);
      expect(eq.bands[4].channel, EqualizerChannel.right);
      expect(eq.bands[4].q, closeTo(1.4142, 0.001));
      expect(eq.bands[5].q, EqualizerBand.kDefaultQ);
      expect(eq.bands[5].gain, 0.0);
    });

    test('survives an export and import', () {
      final eq = ParametricEqualizer.fromEqualizerApo(autoEq)!;
      final again = ParametricEqualizer.fromEqualizerApo(eq.toEqualizerApo())!;
      for (int i = 0; i < eq.bands.length; i++) {
        final a = eq.bands[i];
        final b = again.bands.firstWhere((x) => x.frequency == a.frequency && x.type == a.type);
        expect(b.gain, closeTo(a.gain, 0.05));
        expect(b.q, closeTo(a.q, 0.001));
        expect(b.channel, a.channel);
        expect(b.enabled, a.enabled);
      }
      expect(again.preamp, eq.preamp);
    });

    test('text without filters is rejected', () {
      expect(ParametricEqualizer.fromEqualizerApo('Preamp: -3 dB'), null);
    });
  });

  group('storage', () {
    test('a band round trips', () {
      const band = EqualizerBand(id: 3, type: EqualizerBandType.lowPass, frequency: 5000, q: 0.9, order: 6, channel: EqualizerChannel.left, enabled: false);
      expect(EqualizerBand.fromMap(band.toMap()), band);
    });

    test('old 5 gain presets become peak bands', () {
      final preset = EqualizerPreset.fromMap({
        'name': 'Rock',
        'gains': [4.0, 2.0, -1.0, 2.0, 4.0],
      })!;
      expect(preset.equalizer.bands.map((b) => (b.frequency, b.gain)), [(60.0, 4.0), (230.0, 2.0), (910.0, -1.0), (3600.0, 2.0), (14000.0, 4.0)]);
      expect(EqualizerPreset.fromMap(preset.toMap()), preset);
    });
  });
}
