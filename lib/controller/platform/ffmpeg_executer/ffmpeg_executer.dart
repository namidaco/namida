import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/media_info.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/extensions.dart';

part 'ffmpeg_executer_android.dart';
part 'ffmpeg_executer_base.dart';
part 'ffmpeg_executer_desktop.dart';
