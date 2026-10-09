// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/replay_gain_data.dart';

void main() {
  double? trackGainOf(String tagValue) => ReplayGainData.fromPropertiesMap({'REPLAYGAIN_TRACK_GAIN': tagValue})?.trackGain;
  double? r128TrackGainOf(String tagValue) => ReplayGainData.fromPropertiesMap({'R128_TRACK_GAIN': tagValue})?.trackGain;

  group('replaygain gain tags', () {
    test('signed values are read with or without a space before the unit', () {
      expect(trackGainOf('-6.20 dB'), -6.2);
      expect(trackGainOf('+1.50 dB'), 1.5);
      expect(trackGainOf('-0.515000 dB'), -0.515);
      expect(trackGainOf('+0.655000 dB'), 0.655);
      expect(trackGainOf('-6.20dB'), -6.2);
      expect(trackGainOf('-3.10 DB'), -3.1);
      expect(trackGainOf(' 2.5 '), 2.5);
    });

    test('a decimal comma is read as a decimal point, never as a thousands separator', () {
      expect(trackGainOf('6,5 dB'), 6.5);
      expect(trackGainOf('-6,5dB'), -6.5);
      expect(trackGainOf('1,234.5 dB'), isNull);
    });

    test('non finite values are dropped', () {
      expect(ReplayGainData.fromPropertiesMap({'REPLAYGAIN_TRACK_GAIN': 'NaN dB'}), isNull);
      expect(trackGainOf('Infinity dB'), isNull);
      expect(trackGainOf('-Infinity dB'), isNull);
      expect(trackGainOf('1e999'), isNull);
    });

    test('lowercase keys are read too', () {
      final data = ReplayGainData.fromPropertiesMap({'replaygain_track_gain': '-1.00 dB', 'replaygain_album_gain': '-2.00 dB'})!;
      expect(data.trackGain, -1.0);
      expect(data.albumGain, -2.0);
    });
  });

  group('r128 gain tags', () {
    test('Q7.8 values are converted to the replaygain reference', () {
      expect(r128TrackGainOf('-1280'), 0.0);
      expect(r128TrackGainOf('-1024'), 1.0);
      expect(ReplayGainData.fromPropertiesMap({'r128_album_gain': '512'})?.albumGain, 7.0);
    });

    test('a zero gain counts as missing instead of a +5 dB boost', () {
      expect(ReplayGainData.fromPropertiesMap({'R128_TRACK_GAIN': '0'}), isNull);
    });

    test('replaygain tags win over r128 ones', () {
      final data = ReplayGainData.fromPropertiesMap({'REPLAYGAIN_TRACK_GAIN': '-2.00 dB', 'R128_TRACK_GAIN': '-1280'})!;
      expect(data.trackGain, -2.0);
    });
  });

  test('track gain wins over album gain', () {
    final both = ReplayGainData.fromPropertiesMap({'REPLAYGAIN_TRACK_GAIN': '-3.00 dB', 'REPLAYGAIN_ALBUM_GAIN': '-5.00 dB'})!;
    expect(both.gainToUse, -3.0);
    final albumOnly = ReplayGainData.fromPropertiesMap({'REPLAYGAIN_ALBUM_GAIN': '-5.00 dB'})!;
    expect(albumOnly.gainToUse, -5.0);
  });

  test('peaks are read and non finite ones dropped', () {
    final data = ReplayGainData.fromPropertiesMap({'REPLAYGAIN_TRACK_PEAK': '0.988547', 'REPLAYGAIN_ALBUM_PEAK': 'Infinity'})!;
    expect(data.trackPeak, 0.988547);
    expect(data.albumPeak, isNull);
  });

  test('no gain or peak tag gives no data', () {
    expect(ReplayGainData.fromPropertiesMap({'TITLE': 'song'}), isNull);
    expect(ReplayGainData.fromPropertiesMap({}), isNull);
  });

  test('a map round trip keeps every value', () {
    final data = ReplayGainData.fromPropertiesMap({
      'REPLAYGAIN_TRACK_GAIN': '-6.20 dB',
      'REPLAYGAIN_TRACK_PEAK': '0.9',
      'REPLAYGAIN_ALBUM_GAIN': '-4.10 dB',
      'REPLAYGAIN_ALBUM_PEAK': '0.95',
    })!;
    final restored = ReplayGainData.fromMap(data.toMap());
    expect(restored.trackGain, -6.2);
    expect(restored.trackPeak, 0.9);
    expect(restored.albumGain, -4.1);
    expect(restored.albumPeak, 0.95);
  });

  group('convertGainToVolume', () {
    test('0 dB keeps the volume', () {
      expect(ReplayGainData.convertGainToVolume(gain: 0), 1.0);
    });

    test('-6.02 dB halves the volume', () {
      expect(ReplayGainData.convertGainToVolume(gain: -6.02), closeTo(0.5, 0.001));
    });

    test('very negative gains stop at 10%', () {
      expect(ReplayGainData.convertGainToVolume(gain: -40), 0.1);
    });

    test('positive gains stop at the platform maximum', () {
      expect(ReplayGainData.convertGainToVolume(gain: 10), ReplayGainData.kMaxPlatformVolume);
    });

    test('the result scales the given volume', () {
      expect(ReplayGainData.convertGainToVolume(gain: -6.02, withRespectiveVolume: 0.5), closeTo(0.25, 0.001));
    });
  });
}
