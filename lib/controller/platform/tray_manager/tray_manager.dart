import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:dart_xdg_status_notifier_item/dart_xdg_status_notifier_item.dart';
import 'package:dbus/dbus.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/tray_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';

part 'tray_manager_base.dart';
part 'tray_manager_desktop.dart';
part 'tray_manager_linux_dbus.dart';
