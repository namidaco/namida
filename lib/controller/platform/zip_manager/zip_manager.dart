import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;

import 'package:archive/archive_io.dart' hide ZipFile;
import 'package:flutter_archive/flutter_archive.dart';

import 'package:namida/controller/platform/base.dart';

part 'zip_manager_base.dart';
part 'zip_manager_generic.dart';
part 'zip_manager_native.dart';
