import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/ui/pages/settings_page.dart';

class CustomTabController extends GetxController with GetSingleTickerProviderStateMixin {
  final List<Tab> myTabs = <Tab>[
    Tab(text: 'SETTINGS'.tr),
    Tab(text: 'albums'.tr),
    Tab(text: 'TRACKS'.tr),
  ];

  late TabController controller;

  @override
  void onInit() {
    super.onInit();
    controller = TabController(vsync: this, length: myTabs.length);
  }

  @override
  void onClose() {
    controller.dispose();
    Get.delete();
    super.onClose();
  }
}
