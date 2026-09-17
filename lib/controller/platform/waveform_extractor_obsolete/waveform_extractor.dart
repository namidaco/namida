// Superseded by `lib/controller/waveform_extractor.dart`, which is one shared
// implementation on every platform, backed by the `namida_waveform` package
// (libav* through Dart FFI).
//
// Kept commented out rather than deleted.
// Previously: Amplituda over JNI on android, the `audiowaveform` CLI on desktop.
//
// Why it went away, beyond having two implementations to keep in sync:
//   - Amplituda read s32/s32p samples through a `uint32_t*`, so 24-bit sources
//     (hi-res flac, alac) came out as noise -- namidaco/namida#616. Its output
//     correlated -0.04 with the real waveform, against 0.998 for 16-bit.
//   - `samplePerSecond` was silently ignored whenever it exceeded the codec's
//     frame rate, so the requested resolution only ever held for some codecs.
//   - the desktop fallback transcoded to a full WAV on disk (~40MB for 4
//     minutes) for every format `audiowaveform` could not read, flac included.
//   - amplituda bundled its own ffmpeg, ~6-7MB per ABI on top of the copy
//     ffmpeg-kit already ships in the APK.

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:isolate';

// import 'package:waveform_extractor/waveform_extractor.dart' as pkgwaveform;

// import 'package:namida/base/ports_provider.dart';
// import 'package:namida/class/file_parts.dart';
// import 'package:namida/controller/ffmpeg_controller.dart';
// import 'package:namida/controller/logs_controller.dart';
// import 'package:namida/controller/platform/base.dart';
// import 'package:namida/core/constants.dart';
// import 'package:namida/core/extensions.dart';

// part 'waveform_extractor_android.dart';
// part 'waveform_extractor_base.dart';
// part 'waveform_extractor_desktop.dart';
