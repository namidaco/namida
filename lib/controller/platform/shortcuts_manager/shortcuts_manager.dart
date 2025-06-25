import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nampack/extensions/double_ext.dart';
import 'package:window_manager/window_manager.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/settings_search_bar.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

part 'shortcuts_manager_base.dart';
part 'shortcuts_manager_desktop.dart';
