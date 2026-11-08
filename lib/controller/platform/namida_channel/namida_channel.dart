import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:win32_registry/win32_registry.dart' as win32_registry;

import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/network_proxy_controller.dart';
import 'package:namida/controller/platform/namida_channel/windows_registry_watcher.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/jellyfish.dart';

part 'namida_channel_android.dart';
part 'namida_channel_base.dart';
part 'namida_channel_darwin.dart';
part 'namida_channel_linux.dart';
part 'namida_channel_windows.dart';
