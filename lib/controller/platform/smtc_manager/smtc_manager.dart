import 'dart:async';

import 'package:flutter/material.dart';

import 'package:anni_mpris_service/anni_mpris_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:smtc_windows/smtc_windows.dart' as swin;

import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/platform/tray_manager/tray_manager.dart';
import 'package:namida/controller/platform/window_manager/window_manager.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';

part 'smtc_manager_base.dart';
part 'smtc_manager_linux.dart';
part 'smtc_manager_windows.dart';
