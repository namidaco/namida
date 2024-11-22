import 'dart:math' as math;

class ReplayGainData {
  final double? trackGain, albumGain;
  final double? trackPeak, albumPeak;
  const ReplayGainData({
    required this.trackGain,
    required this.trackPeak,
    required this.albumGain,
    required this.albumPeak,
  });

  double? calculateGainAsVolume({double withRespectiveVolume = 0.75}) {
    final gainFinal = trackGain ?? albumGain;
    if (gainFinal == null) return null;
    return convertGainToVolume(gain: gainFinal, withRespectiveVolume: withRespectiveVolume);
  }

  static double? convertGainToVolume({required double gain, double withRespectiveVolume = 0.75}) {
    final gainLinear = math.pow(10, gain / 20).clamp(0.1, 1.0);
    return gainLinear * withRespectiveVolume;
  }

  static ReplayGainData? fromAndroidMap(Map map) {
    double? trackGainDB = ((map['replaygain_track_gain'] ?? map['REPLAYGAIN_TRACK_GAIN']) as String?)?._parseGainValue(); // "-0.515000 dB"
    double? albumGainDB = ((map['replaygain_album_gain'] ?? map['REPLAYGAIN_ALBUM_GAIN']) as String?)?._parseGainValue(); // "+0.040000 dB"

    trackGainDB ??= ((map['r128_track_gain'] ?? map['R128_TRACK_GAIN']) as String?)?._parseGainValueR128();
    albumGainDB ??= ((map['r128_album_gain'] ?? map['R128_ALBUM_GAIN']) as String?)?._parseGainValueR128();

    final trackPeak = ((map['replaygain_track_peak'] ?? map['REPLAYGAIN_TRACK_PEAK']) as String?)?._parsePeakValue();
    final albumPeak = ((map['replaygain_album_peak'] ?? map['REPLAYGAIN_ALBUM_PEAK']) as String?)?._parsePeakValue();

    final data = ReplayGainData(
      trackGain: trackGainDB,
      trackPeak: trackPeak,
      albumGain: albumGainDB,
      albumPeak: albumPeak,
    );
    if (data.trackGain == null && data.trackPeak == null && data.albumGain == null && data.albumPeak == null) return null;
    return data;
  }

  factory ReplayGainData.fromMap(Map<String, dynamic> map) {
    return ReplayGainData(
      trackGain: map['tg'],
      trackPeak: map['tp'],
      albumGain: map['ag'],
      albumPeak: map['ap'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      "tg": trackGain,
      "tp": trackPeak,
      "ag": albumGain,
      "ap": albumPeak,
    };
  }
}

extension _GainParser on String? {
  double? _parseGainValueR128() {
    final parsed = _parseGainValue();
    return parsed == null ? null : (parsed / 256) + 5;
  }

  double? _parseGainValue() {
    var text = this;
    return text == null ? null : double.tryParse(text.replaceFirst(RegExp(r'[^\d.-]'), '')) ?? double.tryParse(text.split(' ').first);
  }

  double? _parsePeakValue() {
    var text = this;
    return text == null ? null : double.tryParse(text);
  }
}
