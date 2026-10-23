import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:mdns_dart/mdns_dart.dart';

import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/extensions.dart';

part 'lan_service_discovery_base.dart';
part 'lan_service_discovery_bonjour.dart';
part 'lan_service_discovery_mdns.dart';
