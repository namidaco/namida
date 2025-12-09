import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:waveform_extractor/waveform_extractor.dart' as pkgwaveform;

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

part 'waveform_extractor_android.dart';
part 'waveform_extractor_base.dart';
part 'waveform_extractor_windows.dart';
