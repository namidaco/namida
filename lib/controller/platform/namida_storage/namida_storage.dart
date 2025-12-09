import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:path_provider/path_provider.dart' as pp;

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

part 'namida_storage_android.dart';
part 'namida_storage_base.dart';
part 'namida_storage_windows.dart';
