import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/platform/ffmpeg_executer/ffmpeg_executer.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/download_task_base.dart';

part 'tags_extractor_android.dart';
part 'tags_extractor_base.dart';
part 'tags_extractor_desktop.dart';
