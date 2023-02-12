import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/reverse_order_container.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/core/extensions.dart';

class ExtrasSettings extends StatelessWidget {
  const ExtrasSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.EXTRAS,
      subtitle: Language.inst.EXTRAS_SUBTITLE,
      icon: Broken.brush_1,
      child: Column(
        children: [
          CustomListTile(
            icon: Broken.clock,
            title: Language.inst.FILTER_TRACKS_BY,
            trailing: Obx(
              () => Text("${SettingsController.inst.trackSearchFilter.length}"),
            ),
            onTap: () => Get.dialog(
              Obx(
                () {
                  final canRemove = SettingsController.inst.trackSearchFilter.length > 1;
                  return CustomBlurryDialog(
                    title: Language.inst.FILTER_TRACKS_BY,
                    actions: [
                      IconButton(
                        icon: const Icon(Broken.refresh),
                        tooltip: Language.inst.RESTORE_DEFAULTS,
                        onPressed: () {
                          SettingsController.inst.removeFromList(trackSearchFilterAll: [
                            'title',
                            'album',
                            'albumartist',
                            'artist',
                            'genre',
                            'composer',
                            'year',
                          ]);

                          SettingsController.inst.save(trackSearchFilter: ['title', 'artist', 'album']);
                        },
                      ),
                      ElevatedButton(
                        onPressed: () => Get.close(1),
                        child: Text(Language.inst.SAVE),
                      ),
                    ],
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.TITLE,
                            onTap: () {
                              _trackFilterOnTap(TrackSearchFilter.title);
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('title'),
                          ),
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.ALBUM,
                            onTap: () {
                              _trackFilterOnTap(TrackSearchFilter.album);
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('album'),
                          ),
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.ALBUM_ARTIST,
                            onTap: () {
                              _trackFilterOnTap(TrackSearchFilter.albumartist);
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('albumartist'),
                          ),
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.ARTIST,
                            onTap: () {
                              _trackFilterOnTap(TrackSearchFilter.artist);
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('artist'),
                          ),
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.GENRE,
                            onTap: () {
                              _trackFilterOnTap(TrackSearchFilter.genre);
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('genre'),
                          ),
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.COMPOSER,
                            onTap: () {
                              _trackFilterOnTap(TrackSearchFilter.composer);
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('composer'),
                          ),
                          const SizedBox(height: 12.0),
                          ListTileWithCheckMark(
                            title: Language.inst.YEAR,
                            onTap: () {
                              // if (!canRemove) {
                              //   Get.snackbar("fs", 'ffff');
                              // }
                              _trackFilterOnTap(TrackSearchFilter.year);
                              // if (canRemove && SettingsController.inst.trackSearchFilter.contains('year')) {
                              //   SettingsController.inst.removeFromList(trackSearchFilter1: 'year');
                              // } else {
                              //   SettingsController.inst.save(trackSearchFilter: ['year']);
                              // }
                            },
                            active: SettingsController.inst.trackSearchFilter.contains('year'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          CustomListTile(
            icon: Broken.sound,
            title: "Generate All Waveform data",
            // trailing: Obx(() => Text("${WaveformController.inst.wavesInStorage.length}/${Indexer.inst.tracksInfoList.length}")),
            trailing: Obx(
              () => Column(
                children: [
                  Text("${Indexer.inst.waveformsInStorage.length}/${Indexer.inst.tracksInfoList.length}"),
                  if (WaveformController.inst.generatingAllWaveforms.value) const LoadingIndicator(),
                  // LoadingAnimationWidget.prograssiveDots(
                  //   color: Get.textTheme.displayMedium!.color!,
                  //   size: 20,
                  // ),
                ],
              ),
            ),
            onTap: () async {
              if (WaveformController.inst.generatingAllWaveforms.value) {
                await Get.dialog(
                  CustomBlurryDialog(
                    title: 'Note',
                    bodyText: 'Force stop generating waveforms? you can still continue it later',
                    actions: [
                      ElevatedButton(
                        onPressed: () => Get.close(1),
                        child: Text(Language.inst.CANCEL),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          WaveformController.inst.generatingAllWaveforms.value = false;
                          Get.close(1);
                        },
                        child: Text("STOP"),
                      ),
                    ],
                  ),
                );
              } else {
                await Get.dialog(
                  CustomBlurryDialog(
                    title: 'Note',
                    bodyText: 'You currently have ${Indexer.inst.waveformsInStorage.length} waveforms generated out of ${Indexer.inst.tracksInfoList.length}.\n\nThis is a heavy process and generating for all tracks at once will takes quite a while, proceed?',
                    actions: [
                      ElevatedButton(
                        onPressed: () => Get.close(1),
                        child: Text(Language.inst.CANCEL),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          WaveformController.inst.generateAllWaveforms();
                          Get.close(1);
                        },
                        child: Text("GENERATE"),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

void _trackFilterOnTap(TrackSearchFilter filter) {
  String type = '';
  switch (filter) {
    case TrackSearchFilter.title:
      type = 'title';
      break;
    case TrackSearchFilter.album:
      type = 'album';
      break;
    case TrackSearchFilter.albumartist:
      type = 'albumartist';
      break;
    case TrackSearchFilter.artist:
      type = 'artist';
      break;

    case TrackSearchFilter.genre:
      type = 'genre';
      break;
    case TrackSearchFilter.composer:
      type = 'composer';
      break;
    case TrackSearchFilter.year:
      type = 'year';
      break;
    default:
      null;
  }

  final canRemove = SettingsController.inst.trackSearchFilter.length > 1;

  if (SettingsController.inst.trackSearchFilter.contains(type)) {
    if (canRemove) {
      SettingsController.inst.removeFromList(trackSearchFilter1: type);
    } else {
      Get.snackbar(Language.inst.AT_LEAST_ONE_FILTER, Language.inst.AT_LEAST_ONE_FILTER_SUBTITLE);
    }
  } else {
    SettingsController.inst.save(trackSearchFilter: [type]);
  }
}

class LoadingIndicator extends StatefulWidget {
  final Color? color;
  final int? durationMilliSeconds;

  const LoadingIndicator({super.key, this.color, this.durationMilliSeconds});
  @override
  _LoadingIndicatorState createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.durationMilliSeconds ?? 350),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });
    _controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color ?? Get.textTheme.displayMedium!.color,
      ),
      transform: Matrix4.translationValues(_animation.value * 16 - 8, 0, 0),
    );
  }
}
